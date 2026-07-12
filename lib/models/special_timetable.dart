class SpecialTimetable {
  final int? id;
  final int dateMillis; // Midnight timestamp of the target date
  final int targetDayOfWeek; // 1 = Mon, 6 = Sat, 7 = Sun (or 0 = Holiday/No Classes)
  final String notes;

  SpecialTimetable({
    this.id,
    required this.dateMillis,
    required this.targetDayOfWeek,
    this.notes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'dateMillis': dateMillis,
      'targetDayOfWeek': targetDayOfWeek,
      'notes': notes,
    };
  }

  factory SpecialTimetable.fromMap(Map<String, dynamic> map) {
    return SpecialTimetable(
      id: map['id'] as int?,
      dateMillis: map['dateMillis'] as int,
      targetDayOfWeek: map['targetDayOfWeek'] as int,
      notes: map['notes'] as String? ?? '',
    );
  }
}
