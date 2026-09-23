// Renders the profile screen for visual review:
//   flutter test --run-skipped -t screenshots --update-goldens test/screenshots
@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:trackme/models/goal.dart';
import 'package:trackme/models/learning_note.dart';
import 'package:trackme/models/quest.dart';
import 'package:trackme/models/quest_item.dart';
import 'package:trackme/screens/home/home_screen.dart';
import 'package:trackme/screens/profile/profile_screen.dart';
import 'package:trackme/services/goal_service.dart';
import 'package:trackme/services/hive_service.dart';
import 'package:trackme/services/progression_service.dart';
import 'package:trackme/services/quest_service.dart';
import 'package:trackme/services/settings_service.dart';
import 'package:trackme/services/supabase_service.dart';
import 'package:trackme/theme/app_theme.dart';
import 'package:trackme/utils/app_clock.dart';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(Future.value(ByteData.view(File(p).readAsBytesSync().buffer)));
  }
  await loader.load();
}

void main() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/tmp/flutter';
  final fonts = '$flutterRoot/bin/cache/artifacts/material_fonts';
  final now = DateTime(2026, 9, 23, 17, 30);

  setUpAll(() async {
    await _loadFont('Roboto', [
      '$fonts/Roboto-Regular.ttf', '$fonts/Roboto-Medium.ttf', '$fonts/Roboto-Bold.ttf',
      '$fonts/Roboto-Black.ttf', '/usr/lib/firefox-esr/fonts/TwemojiMozilla.ttf',
    ]);
    await _loadFont('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(GoalAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(LearningNoteAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(QuestAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(QuestItemAdapter());
  });

  Future<void> shoot(WidgetTester tester, Widget home, String name,
      {bool seed = true, bool scroll = false}) async {
    AppClock.set(() => now);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    late Widget app;
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('trackme_profile');
      Hive.init(dir.path);
      await Hive.openBox<Goal>(HiveBoxes.goals);
      final settingsBox = await Hive.openBox(HiveBoxes.settings);
      await settingsBox.put('user_name', 'subash');
      final qbox = await Hive.openBox<Quest>(HiveBoxes.quests);
      final progression = ProgressionService(await Hive.openBox('progress_shots'));
      await progression.award(xp: 640, gold: 215);
      List<DateTime> days(int n) =>
          [for (var i = 1; i <= n; i++) now.subtract(Duration(days: i))];
      Quest q(String id, String title, String emoji, String type, int streak, int best, int focus) => Quest(
            id: id, title: title, emoji: emoji, type: type, difficulty: 'Normal',
            streak: streak, longestStreak: best, xp: 50, gold: 20, focusStats: 'STR',
            items: [QuestItem(id: '$id-1', name: 'Do it', target: 1, unit: 'x')],
            createdAt: now.subtract(const Duration(days: 40)),
            completionHistory: days(streak), focusMinutes: focus);
      if (seed) {
      await Hive.box<Goal>(HiveBoxes.goals).put('g', Goal(id: 'g', title: 'Learn Flutter', emoji: '📐', dailyMinutes: 30, streak: 4, longestStreak: 9));
      }
      for (final quest in [if (seed) ...[
        q('w', 'Morning Workout', '💪', 'Fitness', 12, 21, 340),
        q('r', 'Read 20 pages', '📚', 'Learning', 8, 15, 210),
        q('m', 'Meditation', '🧘', 'Mindfulness', 30, 30, 150),
        q('c', 'Code practice', '💻', 'Learning', 5, 9, 480),
        q('run', 'Evening Run', '🏃', 'Fitness', 3, 11, 90),
      ]]) {
        await qbox.put(quest.id, quest);
      }
      final questService = QuestService(box: qbox, progression: progression);
      app = MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsService()),
          ChangeNotifierProvider(create: (_) => SupabaseService()),
          ChangeNotifierProvider(create: (_) => GoalService()),
          ChangeNotifierProvider<QuestService>.value(value: questService),
          ChangeNotifierProvider<ProgressionService>.value(value: progression),
        ],
        child: MaterialApp(
            debugShowCheckedModeBanner: false, theme: AppTheme.dark, home: home),
      );
    });
    await tester.pumpWidget(app);
    await tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
    if (scroll) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -1400));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${name}_scrolled.png'));
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    await tester.runAsync(() => Future.any([Hive.close(), Future<void>.delayed(const Duration(seconds: 3))]));
    tester.view.reset();
  }

  testWidgets('profile', (t) => shoot(t, const ProfileScreen(), 'profile', scroll: true));
  testWidgets('home', (t) => shoot(t, const HomeScreen(), 'home'));
  testWidgets('home new user', (t) => shoot(t, const HomeScreen(), 'home_new', seed: false));
}
