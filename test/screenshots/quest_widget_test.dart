// Mock of the new quest home-screen widget (widget_quest_sys.xml /
// QuestSysWidget.kt) drawn in Flutter with the same colors and layout, for
// visual review. The real widget is RemoteViews and only renders on a phone.
//   flutter test --run-skipped -t screenshots --update-goldens test/screenshots/quest_widget_test.dart
@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(Future.value(ByteData.view(File(p).readAsBytesSync().buffer)));
  }
  await loader.load();
}

const _cyan = Color(0xFF3FD4FF);
const _ok = Color(0xFF4DFFB8);

class _Mock extends StatelessWidget {
  final String emoji, title, meta;
  final bool done;
  final List<(String, String, bool)> rows;
  const _Mock(this.emoji, this.title, this.meta, this.rows,
      {this.done = false});

  @override
  Widget build(BuildContext context) {
    final accent = done ? _ok : _cyan;
    Widget br(Alignment a) => Align(
          alignment: a,
          child: SizedBox(
            width: 16,
            height: 16,
            child: CustomPaint(painter: _Bracket(accent, a)),
          ),
        );
    return Container(
      height: 190,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: done
                ? const [Color(0xF20A1F2A), Color(0xF2051418)]
                : const [Color(0xF20A1A33), Color(0xF2050D1C)]),
        border: Border.all(color: accent.withValues(alpha: 0.7), width: 1.5),
      ),
      child: Stack(children: [
        br(Alignment.topLeft), br(Alignment.topRight),
        br(Alignment.bottomLeft), br(Alignment.bottomRight),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: const Color(0x143FD4FF),
                    border: Border.all(color: const Color(0xB33FD4FF))),
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: done ? const Color(0xFFB8FFE4) : const Color(0xFFE6F7FF),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          shadows: const [Shadow(color: Color(0xCC3FD4FF), blurRadius: 8)])),
                  const SizedBox(height: 2),
                  Text(meta,
                      maxLines: 1,
                      style: const TextStyle(
                          color: Color(0xFF7FA9C7),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                ]),
              ),
              Text(done ? 'CLEAR' : '+120 XP',
                  style: TextStyle(
                      color: done ? _ok : const Color(0xFFFFD166),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
            ]),
            const SizedBox(height: 4),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Expanded(
                      child: Text(r.$1,
                          style: TextStyle(
                              color: r.$3 ? const Color(0xFF7FA9C7) : const Color(0xFFE6F7FF),
                              fontSize: 14))),
                  Text(r.$3 ? '[${r.$2}]' : '[0 / ${r.$2}]',
                      style: TextStyle(
                          color: r.$3 ? _ok : const Color(0xFF8BE6FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 10),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: r.$3 ? const Color(0x334DFFB8) : Colors.transparent,
                      border: Border.all(
                          color: r.$3 ? _ok : const Color(0xFF7FA9C7), width: 1.5),
                    ),
                    child: r.$3 ? const Icon(Icons.check, size: 16, color: _ok) : null,
                  ),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _Bracket extends CustomPainter {
  final Color color;
  final Alignment a;
  _Bracket(this.color, this.a);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = color;
    final left = a.x < 0, top = a.y < 0;
    c.drawRect(Rect.fromLTWH(0, top ? 0 : s.height - 3, s.width, 3), p);
    c.drawRect(Rect.fromLTWH(left ? 0 : s.width - 3, 0, 3, s.height), p);
  }

  @override
  bool shouldRepaint(_) => false;
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

  testWidgets('quest widget', (tester) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 3;
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1B2433),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 30, 16, 0),
          child: Column(children: [
            const _Mock('💪', 'MORNING WORKOUT', 'RANK D  ·  07:00 - 07:40', [
              ('Pushups', '15 reps × 3', false),
              ('Squats', '20 reps × 3', false),
              ('Plank', '60 sec', false),
            ]),
            const _Mock('💪', 'MORNING WORKOUT', 'RANK D  ·  07:00 - 07:40  ·  0/2 TODAY', [
              ('Pushups', '15 reps × 3', true),
              ('Squats', '20 reps × 3', false),
              ('Plank', '60 sec', false),
            ]),
            const _Mock('💪', 'MORNING WORKOUT', 'RANK D  ·  07:00 - 07:40', [
              ('Pushups', '15 reps × 3', true),
              ('Squats', '20 reps × 3', true),
              ('Plank', '60 sec', true),
            ], done: true),
          ]),
        ),
      ),
    ));
    await tester.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/quest_widget.png'));
    tester.view.reset();
  });
}
