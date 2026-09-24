// Renders the Friends screen for visual review:
//   flutter test --run-skipped -t screenshots --update-goldens test/screenshots/friends_test.dart
@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:trackme/models/public_profile.dart';
import 'package:trackme/screens/social/search_friends_screen.dart';
import 'package:trackme/services/hive_service.dart';
import 'package:trackme/services/supabase_service.dart';
import 'package:trackme/theme/app_theme.dart';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(Future.value(ByteData.view(File(p).readAsBytesSync().buffer)));
  }
  await loader.load();
}

PublicProfile _p(String id, String user, String name, int streak, int level) =>
    PublicProfile(id: id, username: user, fullName: name, currentStreak: streak, level: level);

void main() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/tmp/flutter';
  final fonts = '$flutterRoot/bin/cache/artifacts/material_fonts';

  setUpAll(() async {
    await _loadFont('Roboto', [
      '$fonts/Roboto-Regular.ttf', '$fonts/Roboto-Medium.ttf', '$fonts/Roboto-Bold.ttf',
      '/usr/lib/firefox-esr/fonts/TwemojiMozilla.ttf',
    ]);
    await _loadFont('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
  });

  Future<void> shoot(WidgetTester tester, String name, int tab, {bool empty = false}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    late Widget app;
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('trackme_friends');
      Hive.init(dir.path);
      final box = await Hive.openBox(HiveBoxes.settings);
      await box.put('user_name', 'subash');
      final s = SupabaseService();
      if (!empty) {
        s.debugSetFriendships([
          Friendship(id: 1, other: _p('a', 'arjun.codes', 'Arjun R', 21, 9), accepted: true, incoming: false),
          Friendship(id: 2, other: _p('b', 'priya_reads', 'Priya S', 8, 5), accepted: true, incoming: true),
          Friendship(id: 3, other: _p('c', 'karthik', 'Karthik', 0, 2), accepted: true, incoming: false),
          Friendship(id: 4, other: _p('d', 'meera.fit', 'Meera', 14, 7), accepted: false, incoming: true),
          Friendship(id: 5, other: _p('e', 'vikram_dev', 'Vikram', 3, 3), accepted: false, incoming: true),
          Friendship(id: 6, other: _p('f', 'nila', 'Nila', 5, 4), accepted: false, incoming: false),
        ]);
      }
      app = ChangeNotifierProvider<SupabaseService>.value(
        value: s,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: SearchFriendsScreen(load: false, initialTab: tab, previewSuggested: [
            _p('g', 'rahul.runs', 'Rahul', 33, 12),
            _p('h', 'divya_draws', 'Divya', 17, 6),
            _p('i', 'sam_learns', 'Sam', 9, 4),
          ]),
        ),
      );
    });
    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future.any([Hive.close(), Future<void>.delayed(const Duration(seconds: 3))]));
    tester.view.reset();
  }

  testWidgets('friends', (t) => shoot(t, 'friends', 0));
  testWidgets('friends requests', (t) => shoot(t, 'friends_requests', 1));
}
