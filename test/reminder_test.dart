import 'package:flutter_test/flutter_test.dart';
import 'package:trackme/services/reminder_service.dart';

void main() {
  test('parses HH:mm reminder times', () {
    expect(ReminderService.parseTime('07:30'), (hour: 7, minute: 30));
    expect(ReminderService.parseTime('24:00'), isNull);
    expect(ReminderService.parseTime('abc'), isNull);
    expect(ReminderService.parseTime(null), isNull);
  });

  test('next occurrence lands on the right weekday, in the future', () {
    final wed10 = DateTime(2026, 9, 23, 10); // Wednesday
    expect(ReminderService.nextOccurrence(wed10, 3, 18, 0), DateTime(2026, 9, 23, 18));
    expect(ReminderService.nextOccurrence(wed10, 3, 9, 0), DateTime(2026, 9, 30, 9));
    expect(ReminderService.nextOccurrence(wed10, 5, 7, 0), DateTime(2026, 9, 25, 7));
    expect(ReminderService.nextOccurrence(wed10, 1, 7, 0), DateTime(2026, 9, 28, 7));
  });

  test('ids are distinct per weekday', () {
    final ids = {for (var d = 1; d <= 7; d++) ReminderService.idFor('quest-1', d)};
    expect(ids.length, 7);
  });
}
