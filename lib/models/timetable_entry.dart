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

  List<TimetableSlot> expandSlots(int periodDuration) {
    if (periodDuration <= 0) return [this];

    try {
      final startParts = startTime.split(':');
      final startHour = int.tryParse(startParts[0]) ?? 9;
      final startMin = int.tryParse(startParts[1]) ?? 0;
      final startTotal = startHour * 60 + startMin;

      final endParts = endTime.split(':');
      final endHour = int.tryParse(endParts[0]) ?? 10;
      final endMin = int.tryParse(endParts[1]) ?? 0;
      final endTotal = endHour * 60 + endMin;

      final diff = endTotal - startTotal;
      if (diff <= periodDuration) {
        return [this];
      }

      final count = (diff / periodDuration).round();
      if (count <= 1) {
        return [this];
      }

      final List<TimetableSlot> expanded = [];
      for (int i = 0; i < count; i++) {
        final slotStartTotal = startTotal + i * periodDuration;
        final slotEndTotal = slotStartTotal + periodDuration;

        final slotStartHour = slotStartTotal ~/ 60;
        final slotStartMin = slotStartTotal % 60;
        final slotEndHour = slotEndTotal ~/ 60;
        final slotEndMin = slotEndTotal % 60;

        final slotStartStr = '${slotStartHour.toString().padLeft(2, '0')}:${slotStartMin.toString().padLeft(2, '0')}';
        final slotEndStr = '${slotEndHour.toString().padLeft(2, '0')}:${slotEndMin.toString().padLeft(2, '0')}';

        expanded.add(
          TimetableSlot(
            id: id != null ? id! * 100 + i : null,
            dayOfWeek: dayOfWeek,
            periodNumber: periodNumber + i,
            startTime: slotStartStr,
            endTime: slotEndStr,
            subjectId: subjectId,
          ),
        );
      }
      return expanded;
    } catch (_) {
      return [this];
    }
  }
}
