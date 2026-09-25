import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../models/quest_templates.dart';

/// A draft the assistant proposes. Nothing is saved until the user opens it
/// in the normal create screen and taps Create.
class AiDraft {
  /// 'quest' or 'goal'.
  final String kind;
  final String reply;
  final QuestTemplate? quest;
  final String? goalTitle;
  final String? goalEmoji;
  final int? goalMinutes;

  const AiDraft({
    required this.kind,
    required this.reply,
    this.quest,
    this.goalTitle,
    this.goalEmoji,
    this.goalMinutes,
  });

  bool get isQuest => kind == 'quest' && quest != null;
  bool get isGoal => kind == 'goal' && goalTitle != null;
  bool get hasDraft => isQuest || isGoal;
}

/// One turn of the chat, sent back so the assistant can refine its draft.
class AiTurn {
  final bool fromUser;
  final String text;
  const AiTurn(this.fromUser, this.text);
}

class AiException implements Exception {
  final String message;
  const AiException(this.message);
  @override
  String toString() => message;
}

/// Drafts quests and goals with Google's Gemini API.
///
/// The API key is typed in by the user on their own phone and kept in a
/// device-only Hive box. It is never in the repo, never synced to the cloud,
/// and never included in backups or the per-account data swap.
class AiService {
  AiService._();

  static const boxName = 'ai_config';
  static const _keyField = 'gemini_api_key';
  static const models = ['gemini-flash-latest', 'gemini-2.5-flash-lite'];
  static const keyPageUrl = 'https://aistudio.google.com/apikey';

  static Future<Box> _box() async =>
      Hive.isBoxOpen(boxName) ? Hive.box(boxName) : await Hive.openBox(boxName);

  static Future<String?> apiKey() async {
    final k = (await _box()).get(_keyField) as String?;
    return (k == null || k.trim().isEmpty) ? null : k.trim();
  }

  static Future<bool> hasKey() async => (await apiKey()) != null;
  static Future<void> saveKey(String key) async => (await _box()).put(_keyField, key.trim());
  static Future<void> removeKey() async => (await _box()).delete(_keyField);

  static const systemPrompt = '''
You are the quest assistant inside TrackMe, a habit tracker styled like the Solo Leveling "System".
The user describes something they want to do. Turn it into ONE of:
- a "quest": a structured daily routine with 1-6 measurable sub-tasks, or
- a "goal": a single daily habit with a minutes-per-day target (for simple things like "read daily").
Prefer a quest when the request has several steps. If the user asks to change the previous draft, return the full updated draft.
If the request is unclear or not about habits, set kind to "none" and ask one short question in reply.

Return ONLY JSON with this shape:
{
  "kind": "quest" | "goal" | "none",
  "reply": "1-2 short sentences in the System's voice, e.g. 'Quest generated. Clear it daily to grow stronger.'",
  "quest": {
    "title": "short title, max 30 chars",
    "emoji": "one emoji",
    "type": "Fitness" | "Study" | "Mindfulness" | "Skill" | "Custom",
    "difficulty": "Easy" | "Medium" | "Hard",
    "startTime": "HH:mm or null",
    "endTime": "HH:mm or null",
    "days": [1-7, Monday=1],
    "items": [{"name": "max 24 chars", "target": integer, "sets": integer, "unit": "reps|min|sec|km|pages|problems|steps|glasses|..."}]
  },
  "goal": {"title": "max 30 chars", "emoji": "one emoji", "minutes": integer 5-180}
}
If you address the user, call them "human". Never call them "hunter" or "player".
Keep targets realistic for a beginner unless the user says otherwise. Use sets 1 unless it is a rep-based exercise.
''';

  /// Sends the conversation and returns the assistant's draft.
  static Future<AiDraft> draft(List<AiTurn> turns, {http.Client? client}) async {
    final key = await apiKey();
    if (key == null) throw const AiException('Add your Gemini API key first.');
    final c = client ?? http.Client();
    try {
      AiException? last;
      for (final model in models) {
        try {
          return await _call(c, model, key, turns);
        } on AiException catch (e) {
          last = e;
          if (!e.message.startsWith('model:')) rethrow; // only retry model problems
        }
      }
      throw AiException(last?.message.replaceFirst('model:', '') ?? 'AI is unavailable.');
    } finally {
      if (client == null) c.close();
    }
  }

  static Future<AiDraft> _call(http.Client c, String model, String key, List<AiTurn> turns) async {
    final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent');
    final body = {
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'contents': [
        for (final t in turns)
          {
            'role': t.fromUser ? 'user' : 'model',
            'parts': [
              {'text': t.text}
            ]
          }
      ],
      'generationConfig': {'responseMimeType': 'application/json', 'temperature': 0.6},
    };
    final http.Response res;
    try {
      res = await c
          .post(uri,
              headers: {'Content-Type': 'application/json', 'x-goog-api-key': key},
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 40));
    } catch (_) {
      throw const AiException('No connection. AI needs internet; everything else works offline.');
    }
    if (res.statusCode == 404) throw const AiException('model:This AI model is not available right now.');
    if (res.statusCode == 429) {
      throw const AiException('model:Free AI limit reached for now. Try again in a minute.');
    }
    if (res.statusCode == 400 || res.statusCode == 401 || res.statusCode == 403) {
      throw const AiException('Your Gemini API key was rejected. Check it in the AI menu (key icon).');
    }
    if (res.statusCode >= 500) throw const AiException('model:The AI service is busy. Try again.');
    if (res.statusCode != 200) throw AiException('AI error (${res.statusCode}).');

    final text = extractText(res.body);
    if (text == null) throw const AiException('The AI gave an empty answer. Try rephrasing.');
    return parseDraft(text);
  }

  static String? extractText(String responseBody) {
    try {
      final j = jsonDecode(responseBody) as Map<String, dynamic>;
      final parts = (((j['candidates'] as List?)?.first as Map?)?['content'] as Map?)?['parts'] as List?;
      if (parts == null) return null;
      final buf = StringBuffer();
      for (final p in parts) {
        if (p is Map && p['thought'] != true && p['text'] is String) buf.write(p['text']);
      }
      final s = buf.toString().trim();
      return s.isEmpty ? null : s;
    } catch (_) {
      return null;
    }
  }

  static const _types = ['Fitness', 'Study', 'Mindfulness', 'Skill', 'Custom'];
  static const _difficulties = ['Easy', 'Medium', 'Hard'];

  /// Turns the model's JSON into a safe draft, clamping every field so a
  /// bad answer can never produce a broken quest.
  static AiDraft parseDraft(String raw) {
    var s = raw.trim();
    if (s.startsWith('```')) {
      s = s.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '').replaceFirst(RegExp(r'```\s*$'), '');
    }
    final start = s.indexOf('{'), end = s.lastIndexOf('}');
    if (start < 0 || end <= start) {
      return AiDraft(kind: 'none', reply: s.isEmpty ? 'Try describing your goal again.' : s);
    }
    Map<String, dynamic> j;
    try {
      j = jsonDecode(s.substring(start, end + 1)) as Map<String, dynamic>;
    } catch (_) {
      return const AiDraft(kind: 'none', reply: 'I could not read that answer. Try again.');
    }
    final reply = _str(j['reply'], 200) ?? '';
    final kind = j['kind'];

    if (kind == 'quest' && j['quest'] is Map) {
      final q = (j['quest'] as Map).cast<String, dynamic>();
      final items = <(String, int, int, String)>[];
      for (final it in (q['items'] as List? ?? const []).whereType<Map>().take(8)) {
        final name = _str(it['name'], 24);
        if (name == null) continue;
        items.add((name, _int(it['target'], 1, 100000, 1), _int(it['sets'], 1, 20, 1), _str(it['unit'], 12) ?? ''));
      }
      final title = _str(q['title'], 30);
      if (title != null && items.isNotEmpty) {
        final days = (q['days'] as List? ?? const [])
            .map((d) => d is num ? d.toInt() : int.tryParse('$d'))
            .whereType<int>()
            .where((d) => d >= 1 && d <= 7)
            .toSet()
            .toList()
          ..sort();
        return AiDraft(
          kind: 'quest',
          reply: reply.isEmpty ? 'Quest generated.' : reply,
          quest: QuestTemplate(
            title: title,
            emoji: _emoji(q['emoji'], '⚔️'),
            type: _types.contains(q['type']) ? q['type'] as String : 'Custom',
            difficulty: _difficulties.contains(q['difficulty']) ? q['difficulty'] as String : 'Medium',
            startTime: _time(q['startTime']),
            endTime: _time(q['endTime']),
            days: days.isEmpty ? const [1, 2, 3, 4, 5, 6, 7] : days,
            items: items,
          ),
        );
      }
    }
    if (kind == 'goal' && j['goal'] is Map) {
      final g = (j['goal'] as Map).cast<String, dynamic>();
      final title = _str(g['title'], 30);
      if (title != null) {
        return AiDraft(
          kind: 'goal',
          reply: reply.isEmpty ? 'Goal generated.' : reply,
          goalTitle: title,
          goalEmoji: _emoji(g['emoji'], '🎯'),
          goalMinutes: (_int(g['minutes'], 5, 180, 30) / 5).round() * 5,
        );
      }
    }
    return AiDraft(kind: 'none', reply: reply.isEmpty ? 'Tell me a bit more about what you want to do.' : reply);
  }

  static String? _str(dynamic v, int max) {
    if (v is! String) return null;
    final s = v.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (s.isEmpty) return null;
    return s.length > max ? s.substring(0, max).trim() : s;
  }

  static int _int(dynamic v, int min, int max, int fallback) {
    final n = v is num ? v.round() : int.tryParse('$v');
    if (n == null) return fallback;
    return n.clamp(min, max);
  }

  static String? _time(dynamic v) {
    if (v is! String) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(v.trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!), mi = int.parse(m.group(2)!);
    if (h > 23 || mi > 59) return null;
    return '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}';
  }

  static String _emoji(dynamic v, String fallback) {
    if (v is! String) return fallback;
    final s = v.trim();
    if (s.isEmpty || s.runes.length > 8 || RegExp(r'[A-Za-z0-9]').hasMatch(s)) return fallback;
    return s;
  }
}
