import 'package:flutter_test/flutter_test.dart';
import 'package:attendx/models/special_schedule.dart';

void main() {
  group('SpecialSchedule Model Tests', () {
    test('toMap() and fromMap() serialization', () {
      final schedule = SpecialSchedule(
        id: 42,
        name: 'Skill Enhancement Course',
        scheduleType: 'Course',
        subjectId: 10,
        startDateMillis: 10000000,
        endDateMillis: 20000000,
        dailyStartTime: '09:00 AM',
        dailyEndTime: '04:00 PM',
      );

      final map = schedule.toMap();
      expect(map['id'], 42);
      expect(map['name'], 'Skill Enhancement Course');
      expect(map['scheduleType'], 'Course');
      expect(map['subjectId'], 10);
      expect(map['startDateMillis'], 10000000);
      expect(map['endDateMillis'], 20000000);
      expect(map['dailyStartTime'], '09:00 AM');
      expect(map['dailyEndTime'], '04:00 PM');

      final deserialized = SpecialSchedule.fromMap(map);
      expect(deserialized.id, 42);
      expect(deserialized.name, 'Skill Enhancement Course');
      expect(deserialized.scheduleType, 'Course');
      expect(deserialized.subjectId, 10);
      expect(deserialized.startDateMillis, 10000000);
      expect(deserialized.endDateMillis, 20000000);
      expect(deserialized.dailyStartTime, '09:00 AM');
      expect(deserialized.dailyEndTime, '04:00 PM');
    });

    test('isActiveForDate checks date ranges correctly', () {
      final schedule = SpecialSchedule(
        name: 'Workshop',
        scheduleType: 'Workshop',
        subjectId: 5,
        startDateMillis: 1000,
        endDateMillis: 2000,
        dailyStartTime: '10:00 AM',
        dailyEndTime: '12:00 PM',
      );

      expect(schedule.isActiveForDate(500), isFalse);
      expect(schedule.isActiveForDate(1000), isTrue);
      expect(schedule.isActiveForDate(1500), isTrue);
      expect(schedule.isActiveForDate(2000), isTrue);
      expect(schedule.isActiveForDate(2500), isFalse);
    });
  });
}
