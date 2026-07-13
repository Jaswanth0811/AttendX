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

  List<TimetableSlot> expandSlots(
    int periodDuration, {
    int? collegeStartMins,
    int? lunchStartMins,
    int? lunchEndMins,
  }) {
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

      // Helper to calculate period number for a given start time
      int calculatePeriodNum(int timeMins) {
        if (collegeStartMins == null || lunchStartMins == null || lunchEndMins == null) {
          return periodNumber; // Fallback
        }
        
        int current = collegeStartMins;
        int pNum = 1;
        while (current < timeMins) {
          if (current >= lunchStartMins && current < lunchEndMins) {
            current = lunchEndMins;
            continue;
          }
          final nextEnd = current + periodDuration;
          if (nextEnd > lunchStartMins && current < lunchStartMins) {
            current = lunchEndMins;
            continue;
          }
          current += periodDuration;
          pNum++;
        }
        return pNum;
      }

      // Helper to split a range into sub-periods of periodDuration
      List<TimetableSlot> splitRange(int rangeStart, int rangeEnd, int startPeriodIdxOffset) {
        final diff = rangeEnd - rangeStart;
        if (diff <= 0) return [];
        
        final count = (diff / periodDuration).round();
        if (count <= 0) return [];

        final List<TimetableSlot> list = [];
        for (int i = 0; i < count; i++) {
          final slotStart = rangeStart + i * periodDuration;
          final slotEnd = slotStart + periodDuration;

          final slotStartHour = slotStart ~/ 60;
          final slotStartMin = slotStart % 60;
          final slotEndHour = slotEnd ~/ 60;
          final slotEndMin = slotEnd % 60;

          final slotStartStr = '${slotStartHour.toString().padLeft(2, '0')}:${slotStartMin.toString().padLeft(2, '0')}';
          final slotEndStr = '${slotEndHour.toString().padLeft(2, '0')}:${slotEndMin.toString().padLeft(2, '0')}';

          final pNum = calculatePeriodNum(slotStart);

          list.add(
            TimetableSlot(
              id: id != null ? id! * 100 + startPeriodIdxOffset + i : null,
              dayOfWeek: dayOfWeek,
              periodNumber: pNum,
              startTime: slotStartStr,
              endTime: slotEndStr,
              subjectId: subjectId,
            ),
          );
        }
        return list;
      }

      // If no lunch range or no overlap, split the whole range directly
      final hasLunch = lunchStartMins != null && lunchEndMins != null && lunchEndMins > lunchStartMins;
      final hasOverlap = hasLunch && (endTotal > lunchStartMins && startTotal < lunchEndMins);

      if (!hasOverlap) {
        final expanded = splitRange(startTotal, endTotal, 0);
        return expanded.isEmpty ? [this] : expanded;
      }

      // Overlap exists, split into Part 1 (before lunch) and Part 2 (after lunch)
      final part1Start = startTotal;
      final part1End = lunchStartMins;
      final part2Start = lunchEndMins;
      final part2End = endTotal;

      final List<TimetableSlot> expanded = [];
      if (part1End > part1Start) {
        expanded.addAll(splitRange(part1Start, part1End, 0));
      }
      if (part2End > part2Start) {
        expanded.addAll(splitRange(part2Start, part2End, expanded.length));
      }

      return expanded.isEmpty ? [this] : expanded;
    } catch (_) {
      return [this];
    }
  }
}
