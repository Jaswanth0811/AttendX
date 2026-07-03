import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  SharedPreferences? _prefs;

  int _collegeStartTimeMinutes = 9 * 60; // 9:00 AM
  int _collegeEndTimeMinutes = 16 * 60; // 4:00 PM
  int _periodDurationMinutes = 60;
  int _lunchBreakDurationMinutes = 60;
  int _lunchPeriodIndex = 3;
  String _periodsPerDayString = "1:6,2:6,3:6,4:6,5:6,6:6";
  double _targetPercentage = 75.0;

  bool _isLoaded = false;

  SettingsProvider() {
    _loadSettings();
  }

  bool get isLoaded => _isLoaded;
  int get collegeStartTimeMinutes => _collegeStartTimeMinutes;
  int get collegeEndTimeMinutes => _collegeEndTimeMinutes;
  int get periodDurationMinutes => _periodDurationMinutes;
  int get lunchBreakDurationMinutes => _lunchBreakDurationMinutes;
  int get lunchPeriodIndex => _lunchPeriodIndex;
  String get periodsPerDayString => _periodsPerDayString;
  double get targetPercentage => _targetPercentage;

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    _collegeStartTimeMinutes = _prefs?.getInt('college_start_time_minutes') ?? 9 * 60;
    _collegeEndTimeMinutes = _prefs?.getInt('college_end_time_minutes') ?? 16 * 60;
    _periodDurationMinutes = _prefs?.getInt('period_duration_minutes') ?? 60;
    _lunchBreakDurationMinutes = _prefs?.getInt('lunch_break_duration_minutes') ?? 60;
    _lunchPeriodIndex = _prefs?.getInt('lunch_period_index') ?? 3;
    _periodsPerDayString = _prefs?.getString('periods_per_day_string') ?? "1:6,2:6,3:6,4:6,5:6,6:6";
    _targetPercentage = _prefs?.getDouble('target_percentage') ?? 75.0;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> updateTimetableSettings({
    required int start,
    required int end,
    required int period,
    required int lunch,
    required int lunchIdx,
  }) async {
    _collegeStartTimeMinutes = start;
    _collegeEndTimeMinutes = end;
    _periodDurationMinutes = period;
    _lunchBreakDurationMinutes = lunch;
    _lunchPeriodIndex = lunchIdx;

    await _prefs?.setInt('college_start_time_minutes', start);
    await _prefs?.setInt('college_end_time_minutes', end);
    await _prefs?.setInt('period_duration_minutes', period);
    await _prefs?.setInt('lunch_break_duration_minutes', lunch);
    await _prefs?.setInt('lunch_period_index', lunchIdx);
    notifyListeners();
  }

  Future<void> setPeriodsPerDayString(String val) async {
    _periodsPerDayString = val;
    await _prefs?.setString('periods_per_day_string', val);
    notifyListeners();
  }
  
  Future<void> setTargetPercentage(double val) async {
    _targetPercentage = val;
    await _prefs?.setDouble('target_percentage', val);
    notifyListeners();
  }
}
