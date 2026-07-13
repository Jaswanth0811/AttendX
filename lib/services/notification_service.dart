import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/timetable_entry.dart';
import '../models/subject.dart';
import '../models/special_timetable.dart';
import '../models/special_schedule.dart';
import '../database/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
      // Use local time zone
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata')); // Fallback, could be dynamically set
      } catch (e) {
        // Ignored
      }

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('launcher_icon');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          // Handle notification tap
        },
      );

      // Request permissions for Android 13+
      _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestExactAlarmsPermission();

      _initialized = true;
    } catch (e) {
      // Catch all to prevent app boot hang
    }
  }

  Future<void> scheduleClassNotifications(List<TimetableSlot> slots, List<Subject> subjects) async {
    await _notificationsPlugin.cancelAll(); // Clear old notifications

    if (slots.isEmpty && subjects.isEmpty) return; // Special schedules might need to run even if weekly slots are empty

    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final periodDuration = prefs.getInt('period_duration_minutes') ?? 60;
    final collegeStart = prefs.getInt('college_start_time_minutes') ?? 9 * 60;
    final lunchStart = prefs.getInt('lunch_start_time_minutes') ?? 12 * 60 + 40;
    final lunchEnd = prefs.getInt('lunch_end_time_minutes') ?? 13 * 60 + 20;
    
    // Load overrides from DB
    final db = DatabaseHelper();
    final specialOverrides = await db.getSpecialTimetables();
    final holidays = await db.getHolidays();
    final holidayDates = holidays.map((h) => h.date).toSet();
    final specialSchedules = await db.getSpecialSchedules();
    
    // We only schedule for today and tomorrow for simplicity to avoid hitting OS limits
    for (int dayOffset = 0; dayOffset <= 1; dayOffset++) {
      final targetDate = now.add(Duration(days: dayOffset));
      final midnightDateMillis = DateTime(targetDate.year, targetDate.month, targetDate.day).millisecondsSinceEpoch;
      
      // 1. Check if we have a holiday today
      if (holidayDates.contains(midnightDateMillis)) {
        continue;
      }

      // 2. Check if a Special Schedule is active for this date
      SpecialSchedule? activeSchedule;
      try {
        activeSchedule = specialSchedules.firstWhere((ss) => ss.isActiveForDate(midnightDateMillis));
      } catch (_) {}

      final List<TimetableSlot> rawDaySlots;
      if (activeSchedule != null) {
        rawDaySlots = _generateSlotsFromSpecialSchedule(activeSchedule);
      } else {
        // Check if we have a special override (day-swap) for this date
        final special = specialOverrides.firstWhere(
          (st) => st.dateMillis == midnightDateMillis,
          orElse: () => SpecialTimetable(dateMillis: 0, targetDayOfWeek: -1),
        );
        
        final int targetDayOfWeek;
        if (special.targetDayOfWeek != -1) {
          if (special.targetDayOfWeek == 0) {
            // Holiday, no classes today!
            continue;
          }
          targetDayOfWeek = special.targetDayOfWeek;
        } else {
          // Regular day, skip Sunday by default
          if (targetDate.weekday == DateTime.sunday) {
            continue;
          }
          targetDayOfWeek = targetDate.weekday;
        }

        rawDaySlots = slots.where((s) => s.dayOfWeek == targetDayOfWeek).toList();
      }

      final List<TimetableSlot> daySlots = [];
      for (var slot in rawDaySlots) {
        daySlots.addAll(slot.expandSlots(
          periodDuration,
          collegeStartMins: collegeStart,
          lunchStartMins: lunchStart,
          lunchEndMins: lunchEnd,
        ));
      }

      for (var slot in daySlots) {
        final subject = subjects.firstWhere((s) => s.id == slot.subjectId, orElse: () => Subject(id: -1, name: 'Class', code: 'UNK', facultyName: '', colorHex: '#000000', createdAt: 0));
        
        try {
          final timeFormat = DateFormat("hh:mm a");
          final startTime = timeFormat.parse(slot.startTime);
          
          var scheduleTime = DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day,
            startTime.hour,
            startTime.minute,
          ).subtract(const Duration(minutes: 5)); // 5 mins before

          if (scheduleTime.isBefore(now)) continue;

          await _notificationsPlugin.zonedSchedule(
            id: slot.id ?? (scheduleTime.millisecondsSinceEpoch ~/ 1000),
            title: 'Upcoming Class: ${subject.name}',
            body: 'Starts at ${slot.startTime} in 5 minutes.',
            scheduledDate: tz.TZDateTime.from(scheduleTime, tz.local),
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'attendx_class_channel',
                'Class Reminders',
                channelDescription: 'Notifications for upcoming classes',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        } catch (e) {
          // Ignore parse errors
        }
      }
    }
  }

  List<TimetableSlot> _generateSlotsFromSpecialSchedule(SpecialSchedule ss) {
    try {
      int startMins = _parseTimeToMinutes(ss.dailyStartTime);
      int endMins = _parseTimeToMinutes(ss.dailyEndTime);
      if (endMins <= startMins) return [];

      final startH = startMins ~/ 60;
      final startM = startMins % 60;
      final endH = endMins ~/ 60;
      final endM = endMins % 60;

      final startStr = '${startH.toString().padLeft(2, '0')}:${startM.toString().padLeft(2, '0')}';
      final endStr = '${endH.toString().padLeft(2, '0')}:${endM.toString().padLeft(2, '0')}';

      return [
        TimetableSlot(
          id: ss.id != null ? 90000 + ss.id! : null,
          dayOfWeek: 1,
          periodNumber: 1,
          startTime: startStr,
          endTime: endStr,
          subjectId: ss.subjectId,
        ),
      ];
    } catch (_) {
      return [];
    }
  }

  int _parseTimeToMinutes(String time) {
    time = time.trim();
    final isPM = time.toUpperCase().contains('PM');
    final isAM = time.toUpperCase().contains('AM');
    final cleaned = time.replaceAll(RegExp(r'[AaPpMm\s]'), '');
    final parts = cleaned.split(':');
    int hours = int.tryParse(parts[0]) ?? 0;
    int minutes = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    if (isPM && hours < 12) hours += 12;
    if (isAM && hours == 12) hours = 0;
    return hours * 60 + minutes;
  }

  Future<void> scheduleDailyPeriodEndReminders({
    required int startTimeMins,
    required int periodDurationMins,
    required int lunchStartTimeMins,
    required int lunchEndTimeMins,
    required int totalPeriodsToday,
  }) async {
    final now = DateTime.now();
    var currentMins = startTimeMins;

    for (int i = 1; i <= totalPeriodsToday; i++) {
      // If current time is inside the lunch block, skip past lunch
      if (currentMins >= lunchStartTimeMins && currentMins < lunchEndTimeMins) {
        currentMins = lunchEndTimeMins;
      }
      
      // Check if the next period overlaps with lunch
      final nextEnd = currentMins + periodDurationMins;
      if (nextEnd > lunchStartTimeMins && currentMins < lunchStartTimeMins) {
        currentMins = lunchEndTimeMins;
      }

      final periodEndMins = currentMins + periodDurationMins;

      final scheduledTime = DateTime(
        now.year,
        now.month,
        now.day,
        periodEndMins ~/ 60,
        periodEndMins % 60,
      );

      currentMins = periodEndMins;

      if (scheduledTime.isBefore(now)) continue;

      // Cancel previous one with same ID first
      try {
        await _notificationsPlugin.cancel(id: 1000 + i);
      } catch (_) {}

      await _notificationsPlugin.zonedSchedule(
        id: 1000 + i,
        title: 'Period or Class $i Ended',
        body: 'Your period or class $i has just ended. Tap to mark attendance.',
        scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'period_end_channel',
            'Period or Class End Reminders',
            channelDescription: 'Notifications to mark attendance when class ends',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  Future<void> scheduleDailySetupReminder(bool enabled) async {
    try {
      await _notificationsPlugin.cancel(id: 9999);
    } catch (_) {}

    if (!enabled) return;

    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, 17, 0);

    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    await _notificationsPlugin.zonedSchedule(
      id: 9999,
      title: 'AttendX Reminder',
      body: 'Did you attend classes today? Tap to setup and mark your attendance.',
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder_channel',
          'Daily Reminders',
          channelDescription: 'Notifications to remind you to log daily attendance',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}
