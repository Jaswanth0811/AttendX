class SpecialSchedule {
  final int? id;
  final String name; // e.g., "Skill Enhancement Course"
  final String scheduleType; // Course, Workshop, Exam, Event, Other
  final int subjectId; // Link to existing subject
  final int startDateMillis; // Midnight timestamp of start date
  final int endDateMillis; // Midnight timestamp of end date
  final String dailyStartTime; // e.g., "09:00 AM"
  final String dailyEndTime; // e.g., "04:00 PM"

  SpecialSchedule({
    this.id,
    required this.name,
    required this.scheduleType,
    required this.subjectId,
    required this.startDateMillis,
    required this.endDateMillis,
    required this.dailyStartTime,
    required this.dailyEndTime,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'scheduleType': scheduleType,
      'subjectId': subjectId,
      'startDateMillis': startDateMillis,
      'endDateMillis': endDateMillis,
      'dailyStartTime': dailyStartTime,
      'dailyEndTime': dailyEndTime,
    };
  }

  factory SpecialSchedule.fromMap(Map<String, dynamic> map) {
    return SpecialSchedule(
      id: map['id'] as int?,
      name: map['name'] as String,
      scheduleType: map['scheduleType'] as String? ?? 'Other',
      subjectId: map['subjectId'] as int,
      startDateMillis: map['startDateMillis'] as int,
      endDateMillis: map['endDateMillis'] as int,
      dailyStartTime: map['dailyStartTime'] as String,
      dailyEndTime: map['dailyEndTime'] as String,
    );
  }

  /// Check if this schedule is active for a given date (midnight millis)
  bool isActiveForDate(int dateMillis) {
    return dateMillis >= startDateMillis && dateMillis <= endDateMillis;
  }
}
