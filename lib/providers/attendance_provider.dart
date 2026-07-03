import 'package:flutter/foundation.dart';
import '../models/semester.dart';
import '../models/subject.dart';
import '../models/timetable_entry.dart';
import '../models/attendance_record.dart';
import '../database/database_helper.dart';
import '../services/notification_service.dart';

class AttendanceProvider with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  
  Semester? _activeSemester;
  List<Subject> _subjects = [];
  List<TimetableSlot> _timetableSlots = [];
  List<AttendanceRecord> _allAttendance = [];
  Map<int, List<AttendanceRecord>> _attendanceByDate = {};
  
  bool _isLoading = true;
  
  Semester? get activeSemester => _activeSemester;
  List<Subject> get subjects => _subjects;
  List<TimetableSlot> get timetableSlots => _timetableSlots;
  List<AttendanceRecord> get allAttendance => _allAttendance;
  Map<int, List<AttendanceRecord>> get attendanceByDate => _attendanceByDate;
  bool get isLoading => _isLoading;

  AttendanceProvider() {
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
    
    // Schedule notifications for upcoming classes
    await NotificationService().scheduleClassNotifications(_timetableSlots, _subjects);
    
    _isLoading = false;
    notifyListeners();
  }

  // --- Semesters ---
  Future<void> saveSemester(Semester semester) async {
    await _db.setActiveSemester(semester);
    await loadData();
  }

  // --- Subjects ---
  Future<void> addSubject(Subject subject) async {
    await _db.insertSubject(subject);
    await loadData();
  }

  Future<void> updateSubject(Subject subject) async {
    await _db.updateSubject(subject);
    await loadData();
  }

  Future<void> deleteSubject(int id) async {
    await _db.deleteSubject(id);
    await loadData();
  }

  // --- Timetable ---
  Future<void> saveTimetableSlot(TimetableSlot slot) async {
    await _db.insertTimetableSlot(slot);
    await loadData();
  }

  Future<void> clearTimetable() async {
    await _db.clearTimetable();
    await loadData();
  }

  // --- Attendance ---
  Future<void> addAttendance(AttendanceRecord record) async {
    await _db.insertAttendance(record);
    await loadData();
  }

  Future<void> updateAttendance(AttendanceRecord record) async {
    await _db.updateAttendance(record);
    await loadData();
  }

  Future<void> deleteAttendance(int id) async {
    await _db.deleteAttendance(id);
    await loadData();
  }

  // --- Stats Calculation ---
  double _overallPercentage = 0.0;
  double getOverallAttendancePercentage() => _overallPercentage;

  void _calculateOverallPercentage() {
    if (_allAttendance.isEmpty) {
      _overallPercentage = 0.0;
      return;
    }
    int present = 0;
    int totalClasses = 0;
    for (var record in _allAttendance) {
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
}
