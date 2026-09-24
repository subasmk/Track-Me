import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/widget_themes.dart';
import 'sloth_sticker.dart';

/// In-app preview of the Duolingo-style home-screen widget. Mirrors
/// DuoWidget.kt (urgency colors, copy, sloth mood) so Settings shows what
/// the real widget will look like.
enum DuoUrgency { done, ready, forgot, late, lastCall }

DuoUrgency duoUrgencyFor(bool done, int hour) {
  if (done) return DuoUrgency.done;
  if (hour >= 22 || hour < 4) return DuoUrgency.lastCall;
  if (hour >= 19) return DuoUrgency.late;
  if (hour >= 15) return DuoUrgency.forgot;
  return DuoUrgency.ready;
}

String duoMessage(DuoUrgency u, String name, int streak, {bool quest = false}) {
  final n = name.trim().isEmpty || name.toLowerCase() == 'learner'
      ? ''
      : ', ${name.split(RegExp(r'[ ._]')).first.toUpperCase()}';
  return switch (u) {
    DuoUrgency.done => streak >= 7 ? 'On fire$n! 🔥' : 'Nice work$n!',
    DuoUrgency.ready => 'You ready$n?',
    DuoUrgency.forgot => 'Hmm, forgot your ${quest ? 'quest' : 'lesson'}?',
    DuoUrgency.late => "It's late!",
    DuoUrgency.lastCall => "Don't forget me...",
  };
}

const _urgencyColors = {
  DuoUrgency.done: [Color(0xFFC77DFF), Color(0xFFA24BFF), Color(0xFF7B2FF7)],
  DuoUrgency.ready: [Color(0xFFC77DFF), Color(0xFFA24BFF), Color(0xFF7B2FF7)],
  DuoUrgency.forgot: [Color(0xFFFFB347), Color(0xFFFF8A00), Color(0xFFF26B00)],
  DuoUrgency.late: [Color(0xFFE5484D), Color(0xFFC62828), Color(0xFF8E1B3A)],
  DuoUrgency.lastCall: [Color(0xFF8B1E2B), Color(0xFF5C0F1C), Color(0xFF3A0710)],
};

SlothSticker _mascot(DuoUrgency u, int streak) => switch (u) {
      DuoUrgency.done => streak >= 7 ? SlothSticker.levelUp : SlothSticker.cheering,
      DuoUrgency.ready => SlothSticker.ready,
      DuoUrgency.forgot || DuoUrgency.late => SlothSticker.worried,
      DuoUrgency.lastCall => SlothSticker.sleepy,
    };

class DuoWidgetPreview extends StatelessWidget {
  final DuoUrgency urgency;
  final String style; // 'auto' or theme id
  final String? bgPath;
  final String name;
  final String title;
  final int streak;
  final List<bool> last5;
  final DateTime today;
  final bool quest;

  const DuoWidgetPreview({
    super.key,
    required this.urgency,
    required this.style,
    required this.name,
    required this.title,
    required this.streak,
    required this.last5,
    required this.today,
    this.bgPath,
    this.quest = false,
  });

  @override
  Widget build(BuildContext context) {
    final done = urgency == DuoUrgency.done;
    final colors = style == 'auto'
        ? _urgencyColors[urgency]!
        : [WidgetThemes.byId(style).light, WidgetThemes.byId(style).mid, WidgetThemes.byId(style).dark];
    final photo = bgPath != null && File(bgPath!).existsSync() ? bgPath : null;
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return AspectRatio(
      aspectRatio: 2.05,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(fit: StackFit.expand, children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
            ),
          ),
          if (photo != null) ...[
            Image.file(File(photo), fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xB3000000), Color(0x1A000000)]),
              ),
            ),
          ],
          Positioned(
            right: 4,
            bottom: -22,
            top: 6,
            width: 120,
            child: Image.asset(_mascot(urgency, streak).asset,
                fit: BoxFit.contain, alignment: Alignment.bottomRight),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 116, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Stack(children: [
                      const Center(child: Icon(Icons.local_fire_department, size: 26, color: Color(0xFFFFC800))),
                      if (!done && urgency != DuoUrgency.ready)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: const Color(0xFFE53935),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5)),
                            child: const Text('!',
                                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(width: 4),
                  Text('$streak ${streak == 1 ? 'day' : 'days'}',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 2),
                Text(duoMessage(urgency, name, streak, quest: quest),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12)),
                const SizedBox(height: 6),
                Row(children: [
                  for (var i = 0; i < 5; i++)
                    Expanded(
                      child: Column(children: [
                        Text(letters[today.subtract(Duration(days: 4 - i)).weekday - 1],
                            style: const TextStyle(
                                color: Color(0xE6FFFFFF), fontSize: 12, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: last5[i] ? const Color(0x59FFFFFF) : const Color(0x33000000),
                            border: i == 4 && !last5[i]
                                ? Border.all(color: const Color(0xCCFFFFFF), width: 2)
                                : null,
                          ),
                          child: last5[i]
                              ? const Icon(Icons.check, size: 15, color: Colors.white)
                              : null,
                        ),
                      ]),
                    ),
                ]),
              ],
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? Colors.white : const Color(0x33FFFFFF),
                border: done ? null : Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(Icons.check,
                  size: 20, color: done ? const Color(0xFF58CC02) : Colors.white),
            ),
          ),
        ]),
      ),
    );
  }
}
