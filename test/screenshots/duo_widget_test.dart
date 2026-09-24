// Renders the home-screen widget preview in every urgency state and a few
// themes for visual review (the real widget is RemoteViews, drawn by DuoWidget.kt):
//   flutter test --run-skipped -t screenshots --update-goldens test/screenshots/duo_widget_test.dart
@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackme/theme/widget_themes.dart';
import 'package:trackme/widgets/duo_widget_preview.dart';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(Future.value(ByteData.view(File(p).readAsBytesSync().buffer)));
  }
  await loader.load();
}

Future<void> _settle(WidgetTester tester) async {
  for (final e in find.byType(Image).evaluate()) {
    await tester.runAsync(() => precacheImage((e.widget as Image).image, e));
  }
  await tester.pump(const Duration(milliseconds: 300));
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
  });

  testWidgets('widget states', (tester) async {
    tester.view.physicalSize = const Size(1080, 2850);
    tester.view.devicePixelRatio = 3;
    final today = DateTime(2026, 9, 23);
    Widget w(DuoUrgency u, String style, {bool quest = false, int streak = 12}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: DuoWidgetPreview(
            urgency: u,
            style: style,
            name: 'Subash MK',
            title: quest ? 'Daily Quest · 2/4' : 'Learn Flutter',
            streak: streak,
            last5: [true, true, false, true, u == DuoUrgency.done],
            today: today,
            quest: quest,
          ),
        );
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1B1F24),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(14, 30, 14, 0),
          child: Column(children: [
            w(DuoUrgency.ready, 'auto'),
            w(DuoUrgency.forgot, 'auto'),
            w(DuoUrgency.late, 'auto', quest: true),
            w(DuoUrgency.lastCall, 'auto', streak: 1),
            w(DuoUrgency.done, 'auto'),
          ]),
        ),
      ),
    ));
    await _settle(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/duo_widget_states.png'));

    final themes = WidgetThemes.all.take(5).toList();
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1B1F24),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(14, 30, 14, 0),
          child: Column(children: [
            for (final t in themes) w(DuoUrgency.ready, t.id),
          ]),
        ),
      ),
    ));
    await _settle(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/duo_widget_themes.png'));
    tester.view.reset();
  });
}
