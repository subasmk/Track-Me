import 'package:flutter_test/flutter_test.dart';
import 'package:trackme/models/quest.dart';
import 'package:trackme/models/quest_item.dart';
import 'package:trackme/services/quest_share.dart';

void main() {
  test('share code round-trips a quest without personal progress', () {
    final q = Quest(
      id: 'x',
      title: 'Morning Workout',
      emoji: '💪',
      type: 'Fitness',
      difficulty: 'Hard',
      startTime: '07:00',
      targetDays: [1, 3, 5],
      streak: 40,
      items: [QuestItem(id: 'a', name: 'Pushups', target: 15, sets: 3, isDone: true)],
    );
    final text = QuestShare.shareText(q);
    final shared = QuestShare.decode('Hey! $text thanks')!;
    expect(shared.title, 'Morning Workout');
    expect(shared.emoji, '💪');
    expect(shared.days, [1, 3, 5]);
    expect(shared.startTime, '07:00');
    expect(shared.items.single.name, 'Pushups');
    expect(shared.items.single.sets, 3);
    expect(shared.items.single.isDone, isFalse);
    expect(shared.items.single.id, isNot('a'));
  });

  test('garbage is rejected', () {
    expect(QuestShare.decode('hello'), isNull);
    expect(QuestShare.decode('${QuestShare.prefix}!!!'), isNull);
    expect(QuestShare.decode('${QuestShare.prefix}abc'), isNull);
  });
}
