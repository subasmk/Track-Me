// Renders the quest screens to PNGs for visual review:
//   flutter test --update-goldens test/screenshots
// Tagged so normal CI runs skip it (goldens depend on local fonts).
@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:trackme/models/quest.dart';
import 'package:trackme/models/quest_item.dart';
import 'package:trackme/screens/quests/focus_timer_screen.dart';
import 'package:trackme/screens/quests/quest_detail_screen.dart';
import 'package:trackme/screens/quests/quests_screen.dart';
import 'package:trackme/services/progression_service.dart';
import 'package:trackme/services/quest_service.dart';
import 'package:trackme/theme/app_theme.dart';
import 'package:trackme/utils/app_clock.dart';
import 'package:trackme/widgets/sloth_sticker.dart';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    final bytes = File(p).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/tmp/flutter';
  final fonts = '$flutterRoot/bin/cache/artifacts/material_fonts';
  final emoji = Platform.environment['EMOJI_FONT'] ??
      '/usr/lib/firefox-esr/fonts/TwemojiMozilla.ttf';

  late Directory dir;
  late QuestService quests;
  late ProgressionService progression;
  late Box<Quest> box;
  final now = DateTime(2026, 9, 23, 17, 30);

  setUpAll(() async {
    await _loadFont('Roboto', [
      '$fonts/Roboto-Regular.ttf',
      '$fonts/Roboto-Medium.ttf',
      '$fonts/Roboto-Bold.ttf',
      '$fonts/Roboto-Black.ttf',
      emoji,
    ]);
    await _loadFont('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(QuestAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(QuestItemAdapter());
  });

  setUp(() async {
    AppClock.set(() => now);
    dir = await Directory.systemTemp.createTemp('trackme_shots');
    Hive.init(dir.path);
    box = await Hive.openBox<Quest>('quests_shots');
    final settings = await Hive.openBox('settings_shots');
    progression = ProgressionService(settings);
    await progression.award(xp: 640, gold: 215);
    quests = QuestService(box: box, progression: progression);

    Future<void> put(Quest q) => box.put(q.id, q);
    await put(Quest(
      id: 'workout',
      title: 'Morning Workout',
      emoji: '💪',
      type: 'Fitness',
      difficulty: 'Hard',
      startTime: '07:00',
      endTime: '07:40',
      streak: 12,
      longestStreak: 21,
      xp: 187,
      gold: 75,
      focusStats: 'STR/AGI',
      focusMinutes: 340,
      completionHistory: List.generate(34, (i) => now.subtract(Duration(days: i + 1))),
      lastItemToggleDate: now,
      items: [
        QuestItem(id: 'a', name: 'Pushups', target: 15, sets: 3, isDone: true),
        QuestItem(id: 'b', name: 'Pull-ups', target: 8, sets: 3, isDone: true),
        QuestItem(id: 'c', name: 'Plank', target: 60, unit: 'sec'),
        QuestItem(id: 'd', name: 'Run', target: 3, unit: 'km'),
      ],
    ));
    await put(Quest(
      id: 'study',
      title: 'Deep Study: Data Structures',
      emoji: '📚',
      type: 'Study',
      difficulty: 'Medium',
      startTime: '19:00',
      endTime: '20:30',
      streak: 5,
      xp: 120,
      targetDays: [1, 2, 3, 4, 5],
      items: [
        QuestItem(id: 'e', name: 'Read chapter 4', target: 1, unit: 'chapter'),
        QuestItem(id: 'f', name: 'LeetCode problems', target: 3, unit: 'problems'),
      ],
    ));
    await put(Quest(
      id: 'meditate',
      title: 'Evening Meditation',
      emoji: '🧘',
      type: 'Mindfulness',
      difficulty: 'Easy',
      streak: 30,
      xp: 75,
      lastCompleted: now.subtract(const Duration(hours: 2)),
    ));
    await put(Quest(
      id: 'guitar',
      title: 'Guitar Practice',
      emoji: '🎸',
      type: 'Skill',
      difficulty: 'Medium',
      targetDays: [6, 7],
    ));
  });

  tearDown(() async {
    AppClock.reset();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<void> shoot(WidgetTester tester, Widget screen, String name) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: quests),
          ChangeNotifierProvider.value(value: progression),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: Builder(builder: (context) {
            for (final s in SlothSticker.values) {
              precacheImage(AssetImage(s.asset), context);
            }
            return screen;
          }),
        ),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 3));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  }

  testWidgets('quests list', (t) => shoot(t, const QuestsScreen(), 'quests_list'));
  testWidgets('quest detail', (t) => shoot(t, const QuestDetailScreen(questId: 'workout'), 'quest_detail'));
  testWidgets('quest detail done',
      (t) => shoot(t, const QuestDetailScreen(questId: 'meditate'), 'quest_detail_done'));
  testWidgets('focus timer', (t) => shoot(t, const FocusTimerScreen(questId: 'study'), 'focus_timer'));
}
