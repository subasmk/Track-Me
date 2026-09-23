import 'package:flutter_test/flutter_test.dart';
import 'package:trackme/models/quest.dart';
import 'package:trackme/models/quest_item.dart';
import 'package:trackme/utils/app_clock.dart';

Quest _quest({List<int>? days, DateTime? lastCompleted, List<QuestItem>? items}) => Quest(
      id: 'q',
      title: 'Workout',
      emoji: '💪',
      targetDays: days,
      lastCompleted: lastCompleted,
      items: items,
    );

void main() {
  // Wednesday, 23 Sep 2026, 10:00.
  final wed = DateTime(2026, 9, 23, 10);
  setUp(() => AppClock.set(() => wed));
  tearDown(AppClock.reset);

  test('progress label reflects real progress, not always complete', () {
    final item = QuestItem(id: 'i', name: 'Pushups', target: 15, sets: 3);
    expect(item.progressLabel, '0/15 × 3');
    item.isDone = true;
    expect(item.progressLabel, '15/15 × 3');
    expect(QuestItem(id: 'j', name: 'Run', target: 5, unit: 'km').targetLabel, '5 km');
  });

  test('scheduled-today uses weekday of the app clock', () {
    expect(_quest(days: [3]).isScheduledForToday, isTrue); // Wednesday
    expect(_quest(days: [1, 5]).isScheduledForToday, isFalse);
    expect(_quest().isScheduledForToday, isTrue);
  });

  test('today progress and next item', () {
    final a = QuestItem(id: 'a', name: 'A', target: 1, isDone: true);
    final b = QuestItem(id: 'b', name: 'B', target: 1);
    final q = _quest(items: [a, b]);
    expect(q.todayProgress, 0.5);
    expect(q.nextItem?.id, 'b');
    q.lastCompleted = wed;
    expect(q.isCompletedToday, isTrue);
    expect(q.todayProgress, 1);
    expect(q.nextItem, isNull);
    expect(q.doneItemCount, 2);
  });

  test('completed yesterday is not completed today', () {
    final q = _quest(lastCompleted: wed.subtract(const Duration(days: 1)));
    expect(q.isCompletedToday, isFalse);
  });
}
