import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:trackme/models/quest.dart';
import 'package:trackme/models/quest_item.dart';
import 'package:trackme/services/quest_service.dart';
import 'package:trackme/utils/app_clock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late Box<Quest> box;
  var now = DateTime(2026, 9, 23, 10);

  setUpAll(() {
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(QuestAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(QuestItemAdapter());
  });

  setUp(() async {
    now = DateTime(2026, 9, 23, 10);
    AppClock.set(() => now);
    dir = await Directory.systemTemp.createTemp('trackme_test');
    Hive.init(dir.path);
    box = await Hive.openBox<Quest>('quests_test');
  });

  tearDown(() async {
    AppClock.reset();
    await box.deleteFromDisk();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<Quest> addWorkout(QuestService s) => s.addQuest(
        title: 'Workout',
        emoji: '💪',
        type: 'Fitness',
        difficulty: 'Medium',
        items: [
          QuestItem(id: 'a', name: 'Pushups', target: 15),
          QuestItem(id: 'b', name: 'Squats', target: 20),
        ],
      );

  test('ticking every sub-task completes the quest and starts a streak', () async {
    final s = QuestService(box: box);
    final q = await addWorkout(s);
    await s.toggleQuestItem(q.id, 'a');
    expect(s.questById(q.id)!.isCompletedToday, isFalse);
    await s.toggleQuestItem(q.id, 'b');
    final done = s.questById(q.id)!;
    expect(done.isCompletedToday, isTrue);
    expect(done.streak, 1);
    expect(s.completedTodayCount, 1);
  });

  test('streak continues on consecutive days and ticks reset overnight', () async {
    final s = QuestService(box: box);
    final q = await addWorkout(s);
    await s.completeToday(q.id);

    now = DateTime(2026, 9, 24, 8); // next morning
    expect(s.reconcileDay(), isTrue);
    final next = s.questById(q.id)!;
    expect(next.isCompletedToday, isFalse);
    expect(next.items.every((i) => !i.isDone), isTrue);

    await s.completeToday(q.id);
    expect(s.questById(q.id)!.streak, 2);
  });

  test('reading quests has no side effects', () async {
    final s = QuestService(box: box);
    final q = await addWorkout(s);
    await s.toggleQuestItem(q.id, 'a');
    now = DateTime(2026, 9, 24, 8);
    // A pure read must not reset or save anything.
    expect(s.quests.first.items.first.isDone, isTrue);
    await s.refreshForNewDay();
    expect(s.quests.first.items.first.isDone, isFalse);
  });
}
