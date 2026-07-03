class AttendanceRecord {
  final int? id;
  final int date; // Epoch millis, stored as day start
  final int dayOfWeek;
  final int periodNumber;
  final int? scheduledSubjectId;
  final int? actualSubjectId;
  final String status; // 'PRESENT', 'ABSENT', 'CANCELLED'
  final String? note;
  final int createdAt;

  AttendanceRecord({
    this.id,
    required this.date,
    required this.dayOfWeek,
    required this.periodNumber,
    this.scheduledSubjectId,
    this.actualSubjectId,
    required this.status,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'dayOfWeek': dayOfWeek,
      'periodNumber': periodNumber,
      'scheduledSubjectId': scheduledSubjectId,
      'actualSubjectId': actualSubjectId,
      'status': status,
      'note': note,
      'createdAt': createdAt,
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] as int?,
      date: map['date'] as int,
      dayOfWeek: map['dayOfWeek'] as int,
      periodNumber: map['periodNumber'] as int,
      scheduledSubjectId: map['scheduledSubjectId'] as int?,
      actualSubjectId: map['actualSubjectId'] as int?,
      status: map['status'] as String,
      note: map['note'] as String?,
      createdAt: map['createdAt'] as int,
    );
  }
}
