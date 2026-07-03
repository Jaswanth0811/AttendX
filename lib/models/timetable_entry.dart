class TimetableSlot {
  final int? id;
  final int dayOfWeek; // 1 = Monday, 6 = Saturday
  final int periodNumber;
  final String startTime; // "09:00"
  final String endTime; // "10:00"
  final int? subjectId;

  TimetableSlot({
    this.id,
    required this.dayOfWeek,
    required this.periodNumber,
    required this.startTime,
    required this.endTime,
    this.subjectId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dayOfWeek': dayOfWeek,
      'periodNumber': periodNumber,
      'startTime': startTime,
      'endTime': endTime,
      'subjectId': subjectId,
    };
  }

  factory TimetableSlot.fromMap(Map<String, dynamic> map) {
    return TimetableSlot(
      id: map['id'] as int?,
      dayOfWeek: map['dayOfWeek'] as int,
      periodNumber: map['periodNumber'] as int,
      startTime: map['startTime'] as String,
      endTime: map['endTime'] as String,
      subjectId: map['subjectId'] as int?,
    );
  }
}
