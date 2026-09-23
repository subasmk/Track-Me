import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../models/quest.dart';
import '../models/quest_item.dart';

/// Share a quest with a friend as a short text code (no account or server
/// needed). The friend pastes it into "Import quest" to get their own copy,
/// with a fresh streak.
class QuestShare {
  QuestShare._();

  static const prefix = 'TRACKME-QUEST:';

  static String encode(Quest q) {
    final data = {
      'v': 1,
      't': q.title,
      'e': q.emoji,
      'ty': q.type,
      'd': q.difficulty,
      if (q.startTime != null) 's': q.startTime,
      if (q.endTime != null) 'en': q.endTime,
      'days': q.days,
      'f': q.focusStats,
      'i': [
        for (final i in q.items) [i.name, i.target, i.sets, i.unit],
      ],
    };
    return prefix + base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
  }

  static String shareText(Quest q) =>
      'Join my TrackMe quest ${q.emoji} ${q.title}!\n'
      'In TrackMe: Quests > menu > Import quest, then paste this code:\n\n${encode(q)}';

  /// Decodes a code (or a whole shared message containing one).
  /// Returns null if nothing valid is found.
  static SharedQuest? decode(String text) {
    final start = text.indexOf(prefix);
    if (start == -1) return null;
    final match = RegExp(r'[A-Za-z0-9_-]+').matchAsPrefix(text, start + prefix.length);
    if (match == null) return null;
    var b64 = match.group(0)!;
    while (b64.length % 4 != 0) {
      b64 += '=';
    }
    try {
      final map = jsonDecode(utf8.decode(base64Url.decode(b64))) as Map<String, dynamic>;
      const uuid = Uuid();
      final title = (map['t'] as String?)?.trim() ?? '';
      if (title.isEmpty) return null;
      return SharedQuest(
        title: title,
        emoji: (map['e'] as String?) ?? '⚔️',
        type: (map['ty'] as String?) ?? 'Custom',
        difficulty: (map['d'] as String?) ?? 'Medium',
        startTime: map['s'] as String?,
        endTime: map['en'] as String?,
        days: ((map['days'] as List?) ?? const [1, 2, 3, 4, 5, 6, 7])
            .whereType<int>()
            .where((d) => d >= 1 && d <= 7)
            .toList(),
        focusStats: map['f'] as String?,
        items: [
          for (final raw in (map['i'] as List? ?? const []))
            if (raw is List && raw.length >= 4)
              QuestItem(
                id: uuid.v4(),
                name: '${raw[0]}',
                target: raw[1] is int ? raw[1] as int : 1,
                sets: raw[2] is int ? raw[2] as int : 1,
                unit: '${raw[3]}',
              ),
        ],
      );
    } catch (_) {
      return null;
    }
  }
}

class SharedQuest {
  final String title;
  final String emoji;
  final String type;
  final String difficulty;
  final String? startTime;
  final String? endTime;
  final List<int> days;
  final String? focusStats;
  final List<QuestItem> items;
  const SharedQuest({
    required this.title,
    required this.emoji,
    required this.type,
    required this.difficulty,
    this.startTime,
    this.endTime,
    required this.days,
    this.focusStats,
    required this.items,
  });
}
