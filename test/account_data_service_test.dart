import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:trackme/models/goal.dart';
import 'package:trackme/models/learning_note.dart';
import 'package:trackme/models/quest.dart';
import 'package:trackme/models/quest_item.dart';
import 'package:trackme/services/account_data_service.dart';
import 'package:trackme/services/hive_service.dart';

void main() {
  setUpAll(() {
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(GoalAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(LearningNoteAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(QuestAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(QuestItemAdapter());
  });

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('trackme_accounts');
    Hive.init(dir.path);
    await Hive.openBox<Goal>(HiveBoxes.goals);
    await Hive.openBox(HiveBoxes.settings);
    await Hive.openBox<Quest>(HiveBoxes.quests);
  });

  tearDown(() => Hive.close());

  Goal goal(String id, String title) => Goal(
      id: id,
      title: title,
      emoji: '📚',
      dailyMinutes: 30,
      notes: [LearningNote(text: 'n', date: DateTime(2026, 9, 1), id: 'n1')]);

  test('each account keeps its own goals, quests and profile', () async {
    final s = HiveService.settingsBox;
    await AccountDataService.activate('A');
    await HiveService.goalsBox.put('g1', goal('g1', 'Aws'));
    await HiveService.questsBox.put('q1', Quest(id: 'q1', title: 'Run', emoji: '🏃',
        items: [QuestItem(id: 'i1', name: 'km', target: 5)]));
    await s.put('user_name', 'subashmk');
    await s.put('photo_path', '/a.jpg');
    await s.put('progress_total_xp', 300);
    await s.put('profile_done_A', true);
    await s.put('reduce_motion', true);

    await AccountDataService.activate('B');
    expect(HiveService.goalsBox.isEmpty, isTrue);
    expect(HiveService.questsBox.isEmpty, isTrue);
    expect(s.get('user_name'), isNull);
    expect(s.get('photo_path'), isNull);
    expect(s.get('progress_total_xp'), isNull);
    expect(s.get('profile_done_A'), isTrue); // device keys stay
    expect(s.get('reduce_motion'), isTrue);
    await s.put('user_name', 'second');
    await HiveService.goalsBox.put('g2', goal('g2', 'Dsa'));

    await AccountDataService.activate('A');
    expect(HiveService.goalsBox.values.map((g) => g.title), ['Aws']);
    expect(HiveService.goalsBox.get('g1')!.notes.single.text, 'n');
    expect(HiveService.questsBox.get('q1')!.items.single.name, 'km');
    expect(s.get('user_name'), 'subashmk');
    expect(s.get('photo_path'), '/a.jpg');
    expect(s.get('progress_total_xp'), 300);

    await AccountDataService.activate('B');
    expect(HiveService.goalsBox.values.map((g) => g.title), ['Dsa']);
    expect(s.get('user_name'), 'second');
  });

  test('old-build phone with two set-up accounts asks, then parks data', () async {
    final s = HiveService.settingsBox;
    await HiveService.goalsBox.put('g1', goal('g1', 'Aws'));
    await s.put('user_name', 'second');
    await s.put('profile_done_A', true);
    await s.put('profile_done_B', true);
    expect(AccountDataService.needsOwnerChoice('B'), isTrue);

    await AccountDataService.resolveMixed('B', keepHere: false);
    expect(HiveService.goalsBox.isEmpty, isTrue);
    expect(s.get('profile_done_A'), isNull);
    expect(AccountDataService.owner, 'B');

    await AccountDataService.activate('A'); // next account claims the parked data
    expect(HiveService.goalsBox.values.map((g) => g.title), ['Aws']);
    expect(s.get('user_name'), isNull);
  });
}
