@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:trackme/screens/auth/setup_profile_screen.dart';
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
      '/usr/lib/firefox-esr/fonts/TwemojiMozilla.ttf',
    ]);
    await _loadFont('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
  });

  Future<void> shoot(WidgetTester tester, String name, {String? typed}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('trackme_setup');
      Hive.init(dir.path);
      await Hive.openBox('settings_box');
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsService()),
          ChangeNotifierProvider(create: (_) => SupabaseService()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: const SetupProfileScreen(),
        ),
      ));
    });
    if (typed != null) {
      await tester.enterText(find.byType(TextField).first, typed);
    }
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
    await tester.runAsync(Hive.close);
    tester.view.reset();
  }

  testWidgets('profile setup', (t) => shoot(t, 'profile_setup'));
  testWidgets('profile setup bad name', (t) => shoot(t, 'profile_setup_invalid', typed: 'Hi!'));
}
