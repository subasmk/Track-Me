// Renders the goal detail screen for visual review:
//   flutter test --run-skipped -t screenshots --update-goldens test/screenshots/settings_test.dart
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
import 'package:trackme/screens/goal_detail/goal_detail_screen.dart';
import 'package:trackme/services/goal_service.dart';
import 'package:trackme/services/hive_service.dart';
import 'package:trackme/services/progression_service.dart';
import 'package:trackme/services/quest_service.dart';
import 'package:trackme/services/settings_service.dart';
import 'package:trackme/services/supabase_service.dart';
import 'package:trackme/theme/app_theme.dart';

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

  Future<void> shoot(WidgetTester tester, String name, CloudStatus status,
      {List<double> scrolls = const [], bool done = true}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    late Widget app;
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('trackme_settings');
      Hive.init(dir.path);
      await Hive.openBox<Goal>(HiveBoxes.goals);
      final now = DateTime.now();
      await Hive.box<Goal>(HiveBoxes.goals).put('g1', Goal(id: 'g1', title: 'Aws', emoji: '🧮', dailyMinutes: 30, streak: done ? 1 : 3, longestStreak: 3, xp: 16, lastCompleted: done ? now : now.subtract(const Duration(days: 1))));
      final box = await Hive.openBox(HiveBoxes.settings);
      await box.put('user_name', 'subash');
      await box.put('full_name', 'Subash MK');
      await box.put('user_bio', 'Building consistency day by day 🔥');
      final qbox = await Hive.openBox<Quest>(HiveBoxes.quests);
      final progression = ProgressionService(await Hive.openBox('progress_shots'));
      final supabase = SupabaseService()
        ..debugSetAccount(email: 'subash@example.com', status: status);
      app = MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsService()),
          ChangeNotifierProvider<SupabaseService>.value(value: supabase),
          ChangeNotifierProvider(create: (_) => GoalService()),
          ChangeNotifierProvider(create: (_) => QuestService(box: qbox, progression: progression)),
          ChangeNotifierProvider<ProgressionService>.value(value: progression),
        ],
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            home: const GoalDetailScreen(goalId: 'g1')),
      );
    });
    await tester.pumpWidget(app);
    for (final e in find.byType(Image).evaluate()) {
      await tester.runAsync(() => precacheImage((e.widget as Image).image, e));
    }
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
    for (var i = 0; i < scrolls.length; i++) {
      await tester.drag(find.byType(ListView).first, Offset(0, -scrolls[i]));
      await tester.pump(const Duration(milliseconds: 600));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${name}_${i + 2}.png'));
    }
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future.any([Hive.close(), Future<void>.delayed(const Duration(seconds: 3))]));
    tester.view.reset();
  }

  testWidgets('goal detail done', (t) => shoot(t, 'goal_detail_done', CloudStatus.synced));
  testWidgets('goal detail open', (t) => shoot(t, 'goal_detail_open', CloudStatus.synced, done: false));
}
