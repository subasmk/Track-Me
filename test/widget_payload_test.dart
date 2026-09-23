import 'package:flutter_test/flutter_test.dart';
import 'package:trackme/main.dart';
import 'package:trackme/models/quest.dart';
import 'package:trackme/models/quest_item.dart';
import 'package:trackme/services/home_widget_service.dart';
import 'package:trackme/utils/app_clock.dart';

void main() {
  final wed = DateTime(2026, 9, 23, 10);
  setUp(() => AppClock.set(() => wed));
  tearDown(AppClock.reset);

  test('widget counts only quests scheduled today, open ones first', () {
    final quests = [
      Quest(id: 'mon', title: 'Mon only', emoji: '1', targetDays: [1]),
      Quest(id: 'late', title: 'Evening', emoji: '2', startTime: '19:00'),
      Quest(id: 'done', title: 'Done', emoji: '3', lastCompleted: wed, streak: 4),
      Quest(
        id: 'early',
        title: 'Morning',
        emoji: '4',
        startTime: '07:00',
        items: [
          QuestItem(id: 'a', name: 'Stretch', target: 1, isDone: true),
          QuestItem(id: 'b', name: 'Run', target: 5, unit: 'km'),
        ],
      ),
    ];

    final data = HomeWidgetService.buildQuestWidgetData(quests);
    final today = (data['today'] as List).cast<Map<String, dynamic>>();

    expect(data['total'], 3);
    expect(data['completed'], 1);
    expect(data['bestStreak'], 4);
    expect(today.map((q) => q['id']), ['early', 'late', 'done']);
    expect(today.first['progress'], 50);
    expect(today.first['nextTask'], 'Run');
    expect((data['all'] as List).length, 4);
  });

  test('widget deep links route to the right screen', () {
    expect(widgetRouteFor(Uri.parse('trackme://quests'))?.kind, WidgetRouteKind.quests);
    final quest = widgetRouteFor(Uri.parse('trackme://quest?id=abc'));
    expect(quest?.kind, WidgetRouteKind.quest);
    expect(quest?.id, 'abc');
    expect(widgetRouteFor(Uri.parse('trackme://goal?id=g1'))?.kind, WidgetRouteKind.goal);
    expect(widgetRouteFor(Uri.parse('trackme://goal')), isNull);
    expect(widgetRouteFor(Uri.parse('trackme://open')), isNull);
    expect(widgetRouteFor(null), isNull);
  });
}
