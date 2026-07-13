import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/semester.dart';
import '../models/subject.dart';
import '../models/timetable_entry.dart';
import '../models/attendance_record.dart';
import '../models/holiday.dart';
import '../models/special_timetable.dart';
import '../models/special_schedule.dart';
import 'dart:io';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'attendx_database');
    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE semesters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        startDate INTEGER NOT NULL,
        endDate INTEGER NOT NULL,
        isActive INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        facultyName TEXT NOT NULL,
        colorHex TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE timetable_slots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dayOfWeek INTEGER NOT NULL,
        periodNumber INTEGER NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT NOT NULL,
        subjectId INTEGER,
        FOREIGN KEY (subjectId) REFERENCES subjects (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('CREATE INDEX index_timetable_slots_subjectId ON timetable_slots(subjectId)');
    await db.execute('CREATE INDEX index_timetable_slots_dayOfWeek_periodNumber ON timetable_slots(dayOfWeek, periodNumber)');

    await db.execute('''
      CREATE TABLE attendance_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date INTEGER NOT NULL,
        dayOfWeek INTEGER NOT NULL,
        periodNumber INTEGER NOT NULL,
        scheduledSubjectId INTEGER,
        actualSubjectId INTEGER,
        status TEXT NOT NULL,
        note TEXT,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (scheduledSubjectId) REFERENCES subjects (id) ON DELETE SET NULL,
        FOREIGN KEY (actualSubjectId) REFERENCES subjects (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('CREATE INDEX index_attendance_records_scheduledSubjectId ON attendance_records(scheduledSubjectId)');
    await db.execute('CREATE INDEX index_attendance_records_actualSubjectId ON attendance_records(actualSubjectId)');
    await db.execute('CREATE INDEX index_attendance_records_date ON attendance_records(date)');
    await db.execute('CREATE UNIQUE INDEX index_attendance_records_date_periodNumber ON attendance_records(date, periodNumber)');

    await db.execute('''
      CREATE TABLE holidays (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date INTEGER NOT NULL,
        name TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX index_holidays_date ON holidays(date)');

    await db.execute('''
      CREATE TABLE special_timetables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dateMillis INTEGER NOT NULL,
        targetDayOfWeek INTEGER NOT NULL,
        notes TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX index_special_timetables_date ON special_timetables(dateMillis)');

    await db.execute('''
      CREATE TABLE special_schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        scheduleType TEXT NOT NULL,
        subjectId INTEGER NOT NULL,
        startDateMillis INTEGER NOT NULL,
        endDateMillis INTEGER NOT NULL,
        dailyStartTime TEXT NOT NULL,
        dailyEndTime TEXT NOT NULL,
        FOREIGN KEY (subjectId) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE holidays (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date INTEGER NOT NULL,
          name TEXT NOT NULL,
          createdAt INTEGER NOT NULL
        )
      ''');
      await db.execute('CREATE UNIQUE INDEX index_holidays_date ON holidays(date)');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE special_timetables (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          dateMillis INTEGER NOT NULL,
          targetDayOfWeek INTEGER NOT NULL,
          notes TEXT NOT NULL
        )
      ''');
      await db.execute('CREATE UNIQUE INDEX index_special_timetables_date ON special_timetables(dateMillis)');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE special_schedules (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          scheduleType TEXT NOT NULL,
          subjectId INTEGER NOT NULL,
          startDateMillis INTEGER NOT NULL,
          endDateMillis INTEGER NOT NULL,
          dailyStartTime TEXT NOT NULL,
          dailyEndTime TEXT NOT NULL,
          FOREIGN KEY (subjectId) REFERENCES subjects (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
  }

  // --- Semesters ---
  Future<int> insertSemester(Semester semester) async {
    final db = await database;
    return await db.insert('semesters', semester.toMap());
  }

  Future<Semester?> getActiveSemester() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'semesters',
      where: 'isActive = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Semester.fromMap(maps.first);
    }
    return null;
  }

  Future<void> setActiveSemester(Semester semester) async {
    final db = await database;
    await db.update('semesters', {'isActive': 0});
    if (semester.id != null) {
      await db.update('semesters', {'isActive': 1}, where: 'id = ?', whereArgs: [semester.id]);
    } else {
      await insertSemester(semester);
    }
  }

  // --- Subjects ---
  Future<int> insertSubject(Subject subject) async {
    final db = await database;
    return await db.insert('subjects', subject.toMap());
  }

  Future<List<Subject>> getSubjects() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('subjects');
    return List.generate(maps.length, (i) => Subject.fromMap(maps[i]));
  }
  
  Future<void> updateSubject(Subject subject) async {
    final db = await database;
    await db.update('subjects', subject.toMap(), where: 'id = ?', whereArgs: [subject.id]);
  }
  
  Future<void> deleteSubject(int id) async {
    final db = await database;
    await db.delete('subjects', where: 'id = ?', whereArgs: [id]);
  }

  // --- Timetable ---
  Future<List<TimetableSlot>> getTimetableSlots() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('timetable_slots');
    return List.generate(maps.length, (i) => TimetableSlot.fromMap(maps[i]));
  }

  Future<List<TimetableSlot>> getTimetableForDay(int dayOfWeek) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('timetable_slots', where: 'dayOfWeek = ?', whereArgs: [dayOfWeek], orderBy: 'periodNumber ASC');
    return List.generate(maps.length, (i) => TimetableSlot.fromMap(maps[i]));
  }

  Future<void> insertTimetableSlot(TimetableSlot slot) async {
    final db = await database;
    await db.insert('timetable_slots', slot.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  Future<void> deleteTimetableSlot(int id) async {
    final db = await database;
    await db.delete('timetable_slots', where: 'id = ?', whereArgs: [id]);
  }
  
  Future<void> clearTimetable() async {
    final db = await database;
    await db.delete('timetable_slots');
  }

  // --- Attendance ---
  Future<int> insertAttendance(AttendanceRecord record) async {
    final db = await database;
    return await db.insert('attendance_records', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<AttendanceRecord>> getAllAttendance() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('attendance_records', orderBy: 'date DESC, periodNumber ASC');
    return List.generate(maps.length, (i) => AttendanceRecord.fromMap(maps[i]));
  }

  Future<List<AttendanceRecord>> getAttendanceForDate(int dateMillis) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('attendance_records', where: 'date = ?', whereArgs: [dateMillis]);
    return List.generate(maps.length, (i) => AttendanceRecord.fromMap(maps[i]));
  }
  
  Future<void> deleteAttendance(int id) async {
    final db = await database;
    await db.delete('attendance_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateAttendance(AttendanceRecord record) async {
    final db = await database;
    await db.update('attendance_records', record.toMap(), where: 'id = ?', whereArgs: [record.id]);
  }

  // --- Holidays ---
  Future<int> insertHoliday(Holiday holiday) async {
    final db = await database;
    return await db.insert('holidays', holiday.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Holiday>> getHolidays() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('holidays', orderBy: 'date ASC');
    return List.generate(maps.length, (i) => Holiday.fromMap(maps[i]));
  }

  Future<void> deleteHoliday(int id) async {
    final db = await database;
    await db.delete('holidays', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> isHoliday(int dateMillis) async {
    final db = await database;
    final result = await db.query('holidays', where: 'date = ?', whereArgs: [dateMillis], limit: 1);
    return result.isNotEmpty;
  }

  // --- Special Timetables ---
  Future<int> insertSpecialTimetable(SpecialTimetable st) async {
    final db = await database;
    return await db.insert('special_timetables', st.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SpecialTimetable>> getSpecialTimetables() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('special_timetables', orderBy: 'dateMillis ASC');
    return List.generate(maps.length, (i) => SpecialTimetable.fromMap(maps[i]));
  }

  Future<void> deleteSpecialTimetable(int id) async {
    final db = await database;
    await db.delete('special_timetables', where: 'id = ?', whereArgs: [id]);
  }

  // --- Special Schedules ---
  Future<int> insertSpecialSchedule(SpecialSchedule ss) async {
    final db = await database;
    return await db.insert('special_schedules', ss.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SpecialSchedule>> getSpecialSchedules() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('special_schedules', orderBy: 'startDateMillis ASC');
    return List.generate(maps.length, (i) => SpecialSchedule.fromMap(maps[i]));
  }

  Future<void> deleteSpecialSchedule(int id) async {
    final db = await database;
    await db.delete('special_schedules', where: 'id = ?', whereArgs: [id]);
  }

  // --- Backup support ---
  Future<void> checkpoint() async {
    if (_database != null) {
      await _database!.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    }
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // --- Settings Sync Support ---
  Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query('app_settings');
      final Map<String, String> result = {};
      for (var m in maps) {
        result[m['key'] as String] = m['value'] as String;
      }
      return result;
    } catch (_) {
      return {};
    }
  }
}
