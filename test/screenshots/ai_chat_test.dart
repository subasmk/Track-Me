// Renders the AI assistant for visual review:
//   flutter test --run-skipped -t screenshots --update-goldens test/screenshots/ai_chat_test.dart
@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:trackme/screens/ai/ai_chat_screen.dart';
import 'package:trackme/services/ai_service.dart';
import 'package:trackme/theme/app_theme.dart';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    if (File(p).existsSync()) loader.addFont(Future.value(ByteData.view(File(p).readAsBytesSync().buffer)));
  }
  await loader.load();
}

void main() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/tmp/flutter';
  final fonts = '$flutterRoot/bin/cache/artifacts/material_fonts';

  setUpAll(() async {
    await _loadFont('Roboto', [
      '$fonts/Roboto-Regular.ttf', '$fonts/Roboto-Medium.ttf', '$fonts/Roboto-Bold.ttf', '$fonts/Roboto-Black.ttf',
    ]);
    await _loadFont('Emoji', ['/tmp/fonts/NotoColorEmoji.ttf']);
    await _loadFont('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
  });

  ThemeData theme() {
    final t = AppTheme.dark;
    return t.copyWith(textTheme: t.textTheme.apply(fontFamilyFallback: const ['Emoji']));
  }

  Future<void> shoot(WidgetTester tester, Widget screen, String name) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: theme(), home: screen));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
    addTearDown(tester.view.reset);
  }

  testWidgets('ai chat with draft', (tester) async {
    final quest = AiService.parseDraft('''{"kind":"quest","reply":"Quest generated. Clear it daily and the cloud will bend to you.",
"quest":{"title":"AWS Cloud Practitioner","emoji":"☁️","type":"Study","difficulty":"Hard","startTime":"19:00","endTime":"20:00",
"days":[1,2,3,4,5],"items":[{"name":"Watch course module","target":30,"sets":1,"unit":"min"},
{"name":"Practice questions","target":10,"sets":1,"unit":"problems"},{"name":"Hands-on lab","target":1,"sets":1,"unit":"lab"}]}}''');
    await shoot(
        tester,
        AiChatScreen(debugMessages: [
          (true, 'I want to learn AWS in 30 days, evenings after work', null),
          (false, quest.reply, quest),
        ]),
        'ai_chat');
  });

  testWidgets('ai setup', (tester) async {
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('trackme_ai');
      Hive.init(dir.path);
    });
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
    });
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: theme(), home: const AiChatScreen()));
      await Future.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/ai_setup.png'));
    addTearDown(tester.view.reset);
  });
}
