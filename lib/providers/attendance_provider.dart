import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';
import '../models/semester.dart';
import '../models/subject.dart';
import '../models/timetable_entry.dart';
import '../models/attendance_record.dart';
import '../models/holiday.dart';
import '../models/special_timetable.dart';
import '../models/special_schedule.dart';
import '../database/database_helper.dart';
import '../services/notification_service.dart';
import '../services/drive_service.dart';

import '../providers/settings_provider.dart';

class AttendanceProvider with ChangeNotifier, WidgetsBindingObserver {
  final DatabaseHelper _db = DatabaseHelper();
  Timer? _syncTimer;
  
  Semester? _activeSemester;
  List<Subject> _subjects = [];
  List<TimetableSlot> _timetableSlots = [];
  List<AttendanceRecord> _allAttendance = [];
  Map<int, List<AttendanceRecord>> _attendanceByDate = {};
  List<int> _excludedSubjectIds = [];
  List<Holiday> _holidays = [];
  Set<int> _holidayDates = {};
  List<SpecialTimetable> _specialTimetables = [];
  List<SpecialSchedule> _specialSchedules = [];
  bool _autoSync = false;
  
  bool _isLoading = true;
  
  Semester? get activeSemester => _activeSemester;
  List<Subject> get subjects => _subjects;
  List<TimetableSlot> get timetableSlots => _timetableSlots;
  List<AttendanceRecord> get allAttendance => _allAttendance;
  Map<int, List<AttendanceRecord>> get attendanceByDate => _attendanceByDate;
  List<int> get excludedSubjectIds => _excludedSubjectIds;
  List<Holiday> get holidays => _holidays;
  Set<int> get holidayDates => _holidayDates;
  List<SpecialTimetable> get specialTimetables => _specialTimetables;
  List<SpecialSchedule> get specialSchedules => _specialSchedules;
  bool get isLoading => _isLoading;

  bool isHoliday(int dateMillis) => _holidayDates.contains(dateMillis);

  Holiday? getHolidayForDate(int dateMillis) {
    try {
      return _holidays.firstWhere((h) => h.date == dateMillis);
    } catch (_) {
      return null;
    }
  }

  void updateSettings(SettingsProvider settings) {
    _excludedSubjectIds = settings.excludedSubjectIds;
    _autoSync = settings.autoSync;
    _calculateOverallPercentage();
    notifyListeners();
  }

  AttendanceProvider() {
    WidgetsBinding.instance.addObserver(this);
    loadData();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    
    _activeSemester = await _db.getActiveSemester();
    _subjects = await _db.getSubjects();
    _timetableSlots = await _db.getTimetableSlots();
    _allAttendance = await _db.getAllAttendance();
    
    // Optimize into a map for O(1) lookups by date
    _attendanceByDate = {};
    for (var record in _allAttendance) {
      if (_attendanceByDate.containsKey(record.date)) {
        _attendanceByDate[record.date]!.add(record);
      } else {
        _attendanceByDate[record.date] = [record];
      }
    }
    
    _calculateOverallPercentage();
    
    // Load holidays and special timetables
    _holidays = await _db.getHolidays();
    _holidayDates = _holidays.map((h) => h.date).toSet();
    _specialTimetables = await _db.getSpecialTimetables();
    _specialSchedules = await _db.getSpecialSchedules();
    
    // Schedule notifications for upcoming classes
    await NotificationService().scheduleClassNotifications(_timetableSlots, _subjects);
    
    _isLoading = false;
    notifyListeners();

    _syncTimer?.cancel();
    if (_autoSync) {
      _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) => _performStartupSync());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncTimer?.cancel();
      if (_autoSync) {
        _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) => _performStartupSync());
      }
    } else if (state == AppLifecycleState.paused) {
      _syncTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _performStartupSync() async {
    try {
      final driveService = DriveService();
      final driveTime = await driveService.getBackupModifiedTime();
      if (driveTime == null) return;

      final dbFolder = await getDatabasesPath();
      final dbPath = p.join(dbFolder, 'attendx_database');
      final dbFile = File(dbPath);

      if (await dbFile.exists()) {
        final localTime = await dbFile.lastModified();
        if (driveTime.isAfter(localTime.add(const Duration(seconds: 2)))) {
          await driveService.restoreDatabase(silentOnly: true);
          
          if (SettingsProvider.instance != null) {
            await SettingsProvider.instance!.reloadSettings();
          }

          _activeSemester = await _db.getActiveSemester();
          _subjects = await _db.getSubjects();
          _timetableSlots = await _db.getTimetableSlots();
          _allAttendance = await _db.getAllAttendance();
          _attendanceByDate = {};
          for (var record in _allAttendance) {
            if (_attendanceByDate.containsKey(record.date)) {
              _attendanceByDate[record.date]!.add(record);
            } else {
              _attendanceByDate[record.date] = [record];
            }
          }
          _holidays = await _db.getHolidays();
          _holidayDates = _holidays.map((h) => h.date).toSet();
          _calculateOverallPercentage();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Startup auto-sync failed: $e");
    }
  }

  void _triggerAutoBackup() {
    if (_autoSync) {
      DriveService().backupDatabase(silentOnly: true).catchError((e) {
        debugPrint("Background auto-backup failed: $e");
      });
    }
  }

  // --- Semesters ---
  Future<void> saveSemester(Semester semester) async {
    await _db.setActiveSemester(semester);
    await loadData();
    _triggerAutoBackup();
  }

  // --- Subjects ---
  Future<int> addSubject(Subject subject) async {
    final id = await _db.insertSubject(subject);
    await loadData();
    _triggerAutoBackup();
    return id;
  }

  Future<void> updateSubject(Subject subject) async {
    await _db.updateSubject(subject);
    await loadData();
    _triggerAutoBackup();
  }

  Future<void> deleteSubject(int id) async {
    await _db.deleteSubject(id);
    await loadData();
    _triggerAutoBackup();
  }

  // --- Timetable ---
  Future<void> saveTimetableSlot(TimetableSlot slot) async {
    await _db.insertTimetableSlot(slot);
    await loadData();
    _triggerAutoBackup();
  }

  Future<void> deleteTimetableSlot(int id) async {
    await _db.deleteTimetableSlot(id);
    await loadData();
    _triggerAutoBackup();
  }

  Future<void> clearTimetable() async {
    await _db.clearTimetable();
    await loadData();
    _triggerAutoBackup();
  }

  // --- Attendance ---
  Future<void> addAttendance(AttendanceRecord record) async {
    await _db.insertAttendance(record);
    await loadData();
    _triggerAutoBackup();
  }

  Future<void> updateAttendance(AttendanceRecord record) async {
    await _db.updateAttendance(record);
    await loadData();
    _triggerAutoBackup();
  }

  Future<void> deleteAttendance(int id) async {
    await _db.deleteAttendance(id);
    await loadData();
    _triggerAutoBackup();
  }

  // --- Holidays ---
  Future<void> addHoliday(Holiday holiday) async {
    await _db.insertHoliday(holiday);
    await loadData();
    _triggerAutoBackup();
  }

  Future<void> addHolidayRange(String name, DateTime start, DateTime end) async {
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      final dateMillis = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
      final holiday = Holiday(
        date: dateMillis,
        name: name,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _db.insertHoliday(holiday);
    }
    await loadData();
    _triggerAutoBackup();
  }

  Future<void> deleteHoliday(int id) async {
    await _db.deleteHoliday(id);
    await loadData();
    _triggerAutoBackup();
  }

  // --- Stats Calculation ---
  double _overallPercentage = 0.0;
  double getOverallAttendancePercentage() => _overallPercentage;

  int get totalDays {
    return _attendanceByDate.entries
        .where((e) => e.value.any((r) {
          final subjectId = r.actualSubjectId ?? r.scheduledSubjectId;
          return !_excludedSubjectIds.contains(subjectId) && (r.status == 'PRESENT' || r.status == 'ABSENT');
        }))
        .length;
  }

  int get presentDays {
    return _attendanceByDate.entries
        .where((e) => e.value.any((r) {
          final subjectId = r.actualSubjectId ?? r.scheduledSubjectId;
          return !_excludedSubjectIds.contains(subjectId) && r.status == 'PRESENT';
        }))
        .length;
  }

  int get absentDays {
    return _attendanceByDate.entries
        .where((e) => e.value.any((r) {
          final subjectId = r.actualSubjectId ?? r.scheduledSubjectId;
          return !_excludedSubjectIds.contains(subjectId) && r.status == 'ABSENT';
        }))
        .length;
  }

  int get streak {
    // Collect all dates with at least one PRESENT record of included subjects
    final presentDates = _attendanceByDate.entries
        .where((e) => e.value.any((r) {
          final subjectId = r.actualSubjectId ?? r.scheduledSubjectId;
          return !_excludedSubjectIds.contains(subjectId) && r.status == 'PRESENT';
        }))
        .map((e) => _normalizeToStartOfDay(e.key))
        .toSet()
        .toList();

    if (presentDates.isEmpty) return 0;

    // Sort ascending
    presentDates.sort();

    final today = _getTodayStartMillis();
    int currentStreak = 0;
    int currentDate = today;

    // Iterate backwards
    for (var date in presentDates.reversed) {
      // Skip over any holiday dates between currentDate and this date
      while (currentDate > date && _holidayDates.contains(currentDate)) {
        currentDate -= 86400000;
      }
      if (date == currentDate || date == currentDate - 86400000) {
        currentStreak++;
        currentDate = date - 86400000;
      } else if (date < currentDate) {
        break;
      }
    }
    return currentStreak;
  }

  int getPresentCountForSubject(int subjectId) {
    return _allAttendance.where((r) => r.actualSubjectId == subjectId && r.status == 'PRESENT').length;
  }

  int getTotalCountForSubject(int subjectId) {
    return _allAttendance.where((r) => r.actualSubjectId == subjectId && (r.status == 'PRESENT' || r.status == 'ABSENT')).length;
  }

  int _getTodayStartMillis() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
  }

  int _normalizeToStartOfDay(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    return DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch;
  }

  int calculateSafeBunks(int attended, int total, double targetPercent) {
    if (total == 0) return 0;
    double currentPercent = (attended / total) * 100;
    if (currentPercent > targetPercent) {
      return ((attended - (targetPercent / 100) * total) / (targetPercent / 100)).toInt();
    }
    return 0;
  }

  int calculateClassesNeeded(int attended, int total, double targetPercent) {
    if (total == 0) return 0;
    double currentPercent = (attended / total) * 100;
    if (currentPercent < targetPercent) {
      double needed = ((targetPercent / 100 * total - attended) / (1.0 - targetPercent / 100));
      return needed.ceil();
    }
    return 0;
  }

  void _calculateOverallPercentage() {
    if (_allAttendance.isEmpty) {
      _overallPercentage = 0.0;
      return;
    }
    int present = 0;
    int totalClasses = 0;
    for (var record in _allAttendance) {
      final subjectId = record.actualSubjectId ?? record.scheduledSubjectId;
      if (_excludedSubjectIds.contains(subjectId)) {
        continue;
      }
      if (record.status == 'PRESENT' || record.status == 'SEMINAR') {
        present++;
        totalClasses++;
      } else if (record.status == 'ABSENT') {
        totalClasses++;
      }
    }
    if (totalClasses == 0) {
      _overallPercentage = 0.0;
    } else {
      _overallPercentage = (present / totalClasses) * 100;
    }
  }

  // --- Special Timetables ---
  Future<void> addSpecialTimetable(SpecialTimetable st) async {
    await _db.insertSpecialTimetable(st);
    _specialTimetables = await _db.getSpecialTimetables();
    notifyListeners();
  }

  Future<void> deleteSpecialTimetable(int id) async {
    await _db.deleteSpecialTimetable(id);
    _specialTimetables = await _db.getSpecialTimetables();
    notifyListeners();
  }

  SpecialTimetable? getSpecialTimetableForDate(int dateMillis) {
    try {
      return _specialTimetables.firstWhere((st) => st.dateMillis == dateMillis);
    } catch (_) {
      return null;
    }
  }

  List<TimetableSlot> getSlotsForDate(int dateMillis) {
    final date = DateTime.fromMillisecondsSinceEpoch(dateMillis);
    
    // Check if a day-swap override exists
    final special = getSpecialTimetableForDate(dateMillis);
    
    final int dayOfWeek;
    if (special != null) {
      if (special.targetDayOfWeek == 0) {
        return []; // Special holiday override, no classes scheduled
      }
      dayOfWeek = special.targetDayOfWeek;
    } else {
      dayOfWeek = date.weekday;
    }

    final List<TimetableSlot> rawSlots = [];
    
    // 1. Check if a Special Schedule (temporary course) is active for this date
    final activeSchedule = getSpecialScheduleForDate(dateMillis);
    if (activeSchedule != null) {
      // Add special schedule slots
      rawSlots.addAll(_generateSlotsFromSpecialSchedule(activeSchedule));
      
      // Add regular college slots that do not overlap with the special schedule
      if (dayOfWeek != 0 && date.weekday != DateTime.sunday) {
        final regularSlots = _timetableSlots.where((s) => s.dayOfWeek == dayOfWeek).toList();
        final specialStart = _parseTimeToMinutes(activeSchedule.dailyStartTime);
        final specialEnd = _parseTimeToMinutes(activeSchedule.dailyEndTime);
        
        for (var s in regularSlots) {
          final regStart = _parseTimeToMinutes(s.startTime);
          final regEnd = _parseTimeToMinutes(s.endTime);
          final overlaps = regEnd > specialStart && regStart < specialEnd;
          if (!overlaps) {
            rawSlots.add(s);
          }
        }
      }
    } else {
      if (dayOfWeek == 0 || date.weekday == DateTime.sunday) {
        // Holiday, no classes
      } else {
        rawSlots.addAll(_timetableSlots.where((s) => s.dayOfWeek == dayOfWeek));
      }
    }
    
    return rawSlots;
  }

  // --- Special Schedules ---
  Future<void> addSpecialSchedule(SpecialSchedule ss) async {
    await _db.insertSpecialSchedule(ss);
    _specialSchedules = await _db.getSpecialSchedules();
    notifyListeners();
  }

  Future<void> deleteSpecialSchedule(int id) async {
    await _db.deleteSpecialSchedule(id);
    _specialSchedules = await _db.getSpecialSchedules();
    notifyListeners();
  }

  SpecialSchedule? getSpecialScheduleForDate(int dateMillis) {
    try {
      return _specialSchedules.firstWhere((ss) => ss.isActiveForDate(dateMillis));
    } catch (_) {
      return null;
    }
  }

  List<TimetableSlot> _generateSlotsFromSpecialSchedule(SpecialSchedule ss) {
    try {
      // Parse start and end times
      int startMins = _parseTimeToMinutes(ss.dailyStartTime);
      int endMins = _parseTimeToMinutes(ss.dailyEndTime);
      if (endMins <= startMins) return [];

      // Create a single virtual slot spanning the entire schedule time
      // The expandSlots method will split it into individual periods
      final startH = startMins ~/ 60;
      final startM = startMins % 60;
      final endH = endMins ~/ 60;
      final endM = endMins % 60;

      final startStr = '${startH.toString().padLeft(2, '0')}:${startM.toString().padLeft(2, '0')}';
      final endStr = '${endH.toString().padLeft(2, '0')}:${endM.toString().padLeft(2, '0')}';

      return [
        TimetableSlot(
          id: ss.id != null ? 90000 + ss.id! : null,
          dayOfWeek: 1, // Doesn't matter, this is date-based
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
    // Handles both "HH:mm" and "hh:mm AM/PM" formats
    time = time.trim();
    final isPM = time.toUpperCase().contains('PM');
    final isAM = time.toUpperCase().contains('AM');
    final cleaned = time.replaceAll(RegExp(r'[AaPpMm\s]'), '');
    final parts = cleaned.split(':');
    int hours = int.tryParse(parts[0]) ?? 0;
    int mins = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    if (isPM && hours != 12) hours += 12;
    if (isAM && hours == 12) hours = 0;
    return hours * 60 + mins;
  }
}
