import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';

class SettingsProvider with ChangeNotifier {
  static SettingsProvider? _instance;
  static SettingsProvider? get instance => _instance;

  SharedPreferences? _prefs;

  int _collegeStartTimeMinutes = 9 * 60; // 9:00 AM
  int _collegeEndTimeMinutes = 16 * 60; // 4:00 PM
  int _periodDurationMinutes = 60;
  int _lunchStartTimeMinutes = 12 * 60 + 40; // 12:40 PM
  int _lunchEndTimeMinutes = 13 * 60 + 20; // 1:20 PM
  String _periodsPerDayString = "1:6,2:6,3:6,4:6,5:6,6:6";
  double _targetPercentage = 75.0;
  String _lastPromptedDate = "";
  
  List<int> _excludedSubjectIds = [];
  DateTime? _semesterStartDate;
  DateTime? _semesterEndDate;

  bool _isLoaded = false;
  bool _autoSync = false;
  bool _dailyReminders = true;

  SettingsProvider() {
    _instance = this;
    _loadSettings();
  }

  bool get isLoaded => _isLoaded;
  int get collegeStartTimeMinutes => _collegeStartTimeMinutes;
  int get collegeEndTimeMinutes => _collegeEndTimeMinutes;
  int get periodDurationMinutes => _periodDurationMinutes;
  int get lunchStartTimeMinutes => _lunchStartTimeMinutes;
  int get lunchEndTimeMinutes => _lunchEndTimeMinutes;
  int get lunchBreakDurationMinutes => _lunchEndTimeMinutes - _lunchStartTimeMinutes;
  int get lunchPeriodIndex {
    int current = _collegeStartTimeMinutes;
    int pNum = 1;
    while (current < _lunchStartTimeMinutes) {
      final nextEnd = current + _periodDurationMinutes;
      if (nextEnd > _lunchStartTimeMinutes) {
        break;
      }
      current += _periodDurationMinutes;
      pNum++;
    }
    return pNum;
  }
  String get periodsPerDayString => _periodsPerDayString;
  double get targetPercentage => _targetPercentage;
  String get lastPromptedDate => _lastPromptedDate;
  
  List<int> get excludedSubjectIds => _excludedSubjectIds;
  DateTime get semesterStartDate => _semesterStartDate ?? DateTime.now().subtract(const Duration(days: 90));
  DateTime get semesterEndDate => _semesterEndDate ?? DateTime.now().add(const Duration(days: 90));
  bool get autoSync => _autoSync;
  bool get dailyReminders => _dailyReminders;

  Future<void> reloadSettings() async {
    await _loadSettings();
  }

  Future<void> _saveToDb(String key, String value) async {
    try {
      await DatabaseHelper().saveSetting(key, value);
    } catch (_) {}
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    final db = DatabaseHelper();
    final dbSettings = await db.getAllSettings();
    if (dbSettings.isNotEmpty) {
      for (var entry in dbSettings.entries) {
        final key = entry.key;
        final val = entry.value;
        if (key == 'target_percentage') {
          final doubleVal = double.tryParse(val);
          if (doubleVal != null) {
            _targetPercentage = doubleVal;
            await _prefs?.setDouble(key, doubleVal);
          }
        } else if (key == 'college_start_time_minutes') {
          final intVal = int.tryParse(val);
          if (intVal != null) {
            _collegeStartTimeMinutes = intVal;
            await _prefs?.setInt(key, intVal);
          }
        } else if (key == 'college_end_time_minutes') {
          final intVal = int.tryParse(val);
          if (intVal != null) {
            _collegeEndTimeMinutes = intVal;
            await _prefs?.setInt(key, intVal);
          }
        } else if (key == 'period_duration_minutes') {
          final intVal = int.tryParse(val);
          if (intVal != null) {
            _periodDurationMinutes = intVal;
            await _prefs?.setInt(key, intVal);
          }
        } else if (key == 'lunch_start_time_minutes') {
          final intVal = int.tryParse(val);
          if (intVal != null) {
            _lunchStartTimeMinutes = intVal;
            await _prefs?.setInt(key, intVal);
          }
        } else if (key == 'lunch_end_time_minutes') {
          final intVal = int.tryParse(val);
          if (intVal != null) {
            _lunchEndTimeMinutes = intVal;
            await _prefs?.setInt(key, intVal);
          }
        } else if (key == 'semester_start_date') {
          final intVal = int.tryParse(val);
          if (intVal != null) {
            _semesterStartDate = DateTime.fromMillisecondsSinceEpoch(intVal);
            await _prefs?.setInt(key, intVal);
          }
        } else if (key == 'semester_end_date') {
          final intVal = int.tryParse(val);
          if (intVal != null) {
            _semesterEndDate = DateTime.fromMillisecondsSinceEpoch(intVal);
            await _prefs?.setInt(key, intVal);
          }
        } else if (key == 'auto_sync') {
          _autoSync = val == 'true';
          await _prefs?.setBool(key, _autoSync);
        } else if (key == 'daily_reminders') {
          _dailyReminders = val == 'true';
          await _prefs?.setBool(key, _dailyReminders);
        } else if (key == 'periods_per_day_string') {
          _periodsPerDayString = val;
          await _prefs?.setString(key, val);
        } else if (key == 'last_prompt_date') {
          _lastPromptedDate = val;
          await _prefs?.setString(key, val);
        } else if (key == 'excluded_subject_ids') {
          final parts = val.split(',').where((x) => x.isNotEmpty).toList();
          _excludedSubjectIds = parts.map((x) => int.tryParse(x) ?? -1).where((x) => x != -1).toList();
          await _prefs?.setStringList(key, parts);
        }
      }
    } else {
      _collegeStartTimeMinutes = _prefs?.getInt('college_start_time_minutes') ?? 9 * 60;
      _collegeEndTimeMinutes = _prefs?.getInt('college_end_time_minutes') ?? 16 * 60;
      _periodDurationMinutes = _prefs?.getInt('period_duration_minutes') ?? 60;
      _lunchStartTimeMinutes = _prefs?.getInt('lunch_start_time_minutes') ?? 12 * 60 + 40;
      _lunchEndTimeMinutes = _prefs?.getInt('lunch_end_time_minutes') ?? 13 * 60 + 20;
      _periodsPerDayString = _prefs?.getString('periods_per_day_string') ?? "1:6,2:6,3:6,4:6,5:6,6:6";
      _targetPercentage = _prefs?.getDouble('target_percentage') ?? 75.0;
      _lastPromptedDate = _prefs?.getString('last_prompt_date') ?? "";
      
      final excludedIdsStr = _prefs?.getStringList('excluded_subject_ids') ?? [];
      _excludedSubjectIds = excludedIdsStr.map((x) => int.tryParse(x) ?? -1).where((x) => x != -1).toList();

      final semStartMillis = _prefs?.getInt('semester_start_date');
      _semesterStartDate = semStartMillis != null ? DateTime.fromMillisecondsSinceEpoch(semStartMillis) : DateTime.now().subtract(const Duration(days: 90));

      final semEndMillis = _prefs?.getInt('semester_end_date');
      _semesterEndDate = semEndMillis != null ? DateTime.fromMillisecondsSinceEpoch(semEndMillis) : DateTime.now().add(const Duration(days: 90));

      _autoSync = _prefs?.getBool('auto_sync') ?? false;
      _dailyReminders = _prefs?.getBool('daily_reminders') ?? true;

      // Save initial ones to DB so they are in the database first time
      await db.saveSetting('college_start_time_minutes', _collegeStartTimeMinutes.toString());
      await db.saveSetting('college_end_time_minutes', _collegeEndTimeMinutes.toString());
      await db.saveSetting('period_duration_minutes', _periodDurationMinutes.toString());
      await db.saveSetting('lunch_start_time_minutes', _lunchStartTimeMinutes.toString());
      await db.saveSetting('lunch_end_time_minutes', _lunchEndTimeMinutes.toString());
      await db.saveSetting('periods_per_day_string', _periodsPerDayString);
      await db.saveSetting('target_percentage', _targetPercentage.toString());
      await db.saveSetting('last_prompt_date', _lastPromptedDate);
      await db.saveSetting('excluded_subject_ids', _excludedSubjectIds.map((x) => x.toString()).join(','));
      if (_semesterStartDate != null) {
        await db.saveSetting('semester_start_date', _semesterStartDate!.millisecondsSinceEpoch.toString());
      }
      if (_semesterEndDate != null) {
        await db.saveSetting('semester_end_date', _semesterEndDate!.millisecondsSinceEpoch.toString());
      }
      await db.saveSetting('auto_sync', _autoSync.toString());
      await db.saveSetting('daily_reminders', _dailyReminders.toString());
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> updateTimetableSettings({
    required int start,
    required int end,
    required int period,
    required int lunchStart,
    required int lunchEnd,
  }) async {
    _collegeStartTimeMinutes = start;
    _collegeEndTimeMinutes = end;
    _periodDurationMinutes = period;
    _lunchStartTimeMinutes = lunchStart;
    _lunchEndTimeMinutes = lunchEnd;

    await _prefs?.setInt('college_start_time_minutes', start);
    await _prefs?.setInt('college_end_time_minutes', end);
    await _prefs?.setInt('period_duration_minutes', period);
    await _prefs?.setInt('lunch_start_time_minutes', lunchStart);
    await _prefs?.setInt('lunch_end_time_minutes', lunchEnd);

    await _saveToDb('college_start_time_minutes', start.toString());
    await _saveToDb('college_end_time_minutes', end.toString());
    await _saveToDb('period_duration_minutes', period.toString());
    await _saveToDb('lunch_start_time_minutes', lunchStart.toString());
    await _saveToDb('lunch_end_time_minutes', lunchEnd.toString());

    notifyListeners();
  }

  Future<void> setPeriodsPerDayString(String val) async {
    _periodsPerDayString = val;
    await _prefs?.setString('periods_per_day_string', val);
    await _saveToDb('periods_per_day_string', val);
    notifyListeners();
  }
  
  Future<void> setTargetPercentage(double val) async {
    _targetPercentage = val;
    await _prefs?.setDouble('target_percentage', val);
    await _saveToDb('target_percentage', val.toString());
    notifyListeners();
  }

  Future<void> setLastPromptedDate(String val) async {
    _lastPromptedDate = val;
    await _prefs?.setString('last_prompt_date', val);
    await _saveToDb('last_prompt_date', val);
    notifyListeners();
  }

  Future<void> toggleSubjectCalculation(int subjectId, bool calculate) async {
    if (calculate) {
      _excludedSubjectIds.remove(subjectId);
    } else {
      if (!_excludedSubjectIds.contains(subjectId)) {
        _excludedSubjectIds.add(subjectId);
      }
    }
    await _prefs?.setStringList('excluded_subject_ids', _excludedSubjectIds.map((x) => x.toString()).toList());
    await _saveToDb('excluded_subject_ids', _excludedSubjectIds.map((x) => x.toString()).join(','));
    notifyListeners();
  }

  Future<void> updateSemesterDates(DateTime start, DateTime end) async {
    _semesterStartDate = start;
    _semesterEndDate = end;
    await _prefs?.setInt('semester_start_date', start.millisecondsSinceEpoch);
    await _prefs?.setInt('semester_end_date', end.millisecondsSinceEpoch);
    await _saveToDb('semester_start_date', start.millisecondsSinceEpoch.toString());
    await _saveToDb('semester_end_date', end.millisecondsSinceEpoch.toString());
    notifyListeners();
  }

  Future<void> setAutoSync(bool val) async {
    _autoSync = val;
    await _prefs?.setBool('auto_sync', val);
    await _saveToDb('auto_sync', val.toString());
    notifyListeners();
  }

  Future<void> setDailyReminders(bool val) async {
    _dailyReminders = val;
    await _prefs?.setBool('daily_reminders', val);
    await _saveToDb('daily_reminders', val.toString());
    notifyListeners();
  }
}
