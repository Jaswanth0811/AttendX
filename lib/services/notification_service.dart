import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/timetable_entry.dart';
import '../models/subject.dart';
import 'package:intl/intl.dart';

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

    if (slots.isEmpty) return;

    final now = DateTime.now();
    
    // We only schedule for today and tomorrow for simplicity to avoid hitting OS limits
    for (int dayOffset = 0; dayOffset <= 1; dayOffset++) {
      final targetDate = now.add(Duration(days: dayOffset));
      final targetDayOfWeek = targetDate.weekday;

      final daySlots = slots.where((s) => s.dayOfWeek == targetDayOfWeek).toList();

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

  Future<void> scheduleDailyPeriodEndReminders({
    required int startTimeMins,
    required int periodDurationMins,
    required int lunchDurationMins,
    required int lunchPeriodIdx,
    required int totalPeriodsToday,
  }) async {
    final now = DateTime.now();
    var currentMins = startTimeMins;

    for (int i = 1; i <= totalPeriodsToday; i++) {
      if (i == lunchPeriodIdx) {
        currentMins += lunchDurationMins;
      } else {
        currentMins += periodDurationMins;

        final scheduledTime = DateTime(
          now.year,
          now.month,
          now.day,
          currentMins ~/ 60,
          currentMins % 60,
        );

        if (scheduledTime.isBefore(now)) continue;

        // Cancel previous one with same ID first
        try {
          await _notificationsPlugin.cancel(id: 1000 + i);
        } catch (_) {}

        await _notificationsPlugin.zonedSchedule(
          id: 1000 + i,
          title: 'Period $i Ended',
          body: 'Your period $i has just ended. Tap to mark attendance.',
          scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'period_end_channel',
              'Period End Reminders',
              channelDescription: 'Notifications to mark attendance when class ends',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
    }
  }
}
