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

/// An AI provider the user can bring their own key for.
class AiProvider {
  final String id;
  final String name;
  final String note; // one line shown in the picker
  final String keyUrl; // where to create a key
  final String keyHint; // what the key usually starts with
  final List<String> models; // tried in order unless the user sets one
  final String? baseUrl; // OpenAI-compatible chat endpoint base
  const AiProvider({
    required this.id,
    required this.name,
    required this.note,
    required this.keyUrl,
    required this.keyHint,
    required this.models,
    this.baseUrl,
  });

  bool get isGemini => id == 'gemini';
  bool get isAnthropic => id == 'anthropic';
  bool get isOpenAiCompatible => baseUrl != null;
}

/// Drafts quests and goals with the user's own AI key.
///
/// Supported: Google Gemini (recommended, free tier), OpenAI, Anthropic
/// Claude, Groq, DeepSeek and OpenRouter. The key is typed in by the user on
/// their own phone and kept in a device-only Hive box. It is never in the
/// repo, never synced to the cloud, and never included in backups or the
/// per-account data swap.
class AiService {
  AiService._();

  static const boxName = 'ai_config';
  static const _providerField = 'provider';
  static const _legacyGeminiKey = 'gemini_api_key';

  static const providers = <AiProvider>[
    AiProvider(
      id: 'gemini',
      name: 'Google Gemini',
      note: 'Recommended. Free tier, no card needed.',
      keyUrl: 'https://aistudio.google.com/apikey',
      keyHint: 'AIza... or AQ...',
      models: ['gemini-3.5-flash-lite', 'gemini-3.1-flash-lite'],
    ),
    AiProvider(
      id: 'openai',
      name: 'OpenAI (ChatGPT)',
      note: 'Paid per use.',
      keyUrl: 'https://platform.openai.com/api-keys',
      keyHint: 'sk-...',
      models: ['gpt-4o-mini'],
      baseUrl: 'https://api.openai.com/v1',
    ),
    AiProvider(
      id: 'anthropic',
      name: 'Anthropic Claude',
      note: 'Paid per use.',
      keyUrl: 'https://console.anthropic.com/settings/keys',
      keyHint: 'sk-ant-...',
      models: ['claude-haiku-4-5', 'claude-sonnet-5'],
    ),
    AiProvider(
      id: 'groq',
      name: 'Groq',
      note: 'Free tier, very fast.',
      keyUrl: 'https://console.groq.com/keys',
      keyHint: 'gsk_...',
      models: ['llama-3.3-70b-versatile', 'openai/gpt-oss-20b'],
      baseUrl: 'https://api.groq.com/openai/v1',
    ),
    AiProvider(
      id: 'deepseek',
      name: 'DeepSeek',
      note: 'Low cost, paid per use.',
      keyUrl: 'https://platform.deepseek.com/api_keys',
      keyHint: 'sk-...',
      models: ['deepseek-flash'],
      baseUrl: 'https://api.deepseek.com',
    ),
    AiProvider(
      id: 'openrouter',
      name: 'OpenRouter',
      note: 'One key for many models.',
      keyUrl: 'https://openrouter.ai/keys',
      keyHint: 'sk-or-...',
      models: ['openrouter/auto'],
      baseUrl: 'https://openrouter.ai/api/v1',
    ),
  ];

  static AiProvider providerById(String? id) =>
      providers.firstWhere((p) => p.id == id, orElse: () => providers.first);

  /// Best guess of the provider from what a pasted key looks like.
  static AiProvider? guessProvider(String key) {
    final k = key.trim();
    if (k.startsWith('sk-ant-')) return providerById('anthropic');
    if (k.startsWith('sk-or-')) return providerById('openrouter');
    if (k.startsWith('gsk_')) return providerById('groq');
    if (k.startsWith('AIza') || k.startsWith('AQ.')) return providerById('gemini');
    return null; // "sk-..." could be OpenAI or DeepSeek; keep the user's pick
  }

  // Kept for the setup screen's default link.
  static const keyPageUrl = 'https://aistudio.google.com/apikey';

  static Future<Box> _box() async =>
      Hive.isBoxOpen(boxName) ? Hive.box(boxName) : await Hive.openBox(boxName);

  static Future<AiProvider> provider() async => providerById((await _box()).get(_providerField) as String?);

  static Future<String?> apiKey() async {
    final b = await _box();
    final p = providerById(b.get(_providerField) as String?);
    var k = b.get('key_${p.id}') as String?;
    if (k == null && p.isGemini) k = b.get(_legacyGeminiKey) as String?; // keys saved by the first build
    return (k == null || k.trim().isEmpty) ? null : k.trim();
  }

  static Future<String?> customModel(String providerId) async {
    final m = (await _box()).get('model_$providerId') as String?;
    return (m == null || m.trim().isEmpty) ? null : m.trim();
  }

  static Future<bool> hasKey() async => (await apiKey()) != null;

  static Future<void> saveKey(String key, {String providerId = 'gemini', String? model}) async {
    final b = await _box();
    await b.put(_providerField, providerId);
    await b.put('key_$providerId', key.trim());
    if (model != null && model.trim().isNotEmpty) {
      await b.put('model_$providerId', model.trim());
    } else {
      await b.delete('model_$providerId');
    }
  }

  static Future<void> removeKey() async {
    final b = await _box();
    final p = providerById(b.get(_providerField) as String?);
    await b.delete('key_${p.id}');
    await b.delete('model_${p.id}');
    if (p.isGemini) await b.delete(_legacyGeminiKey);
  }

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
    final p = await provider();
    final key = await apiKey();
    if (key == null) throw const AiException('Add your AI key first (key icon).');
    final custom = await customModel(p.id);
    final models = custom != null ? [custom] : p.models;
    final c = client ?? http.Client();
    try {
      AiException? last;
      for (final model in models) {
        try {
          return await _call(c, p, model, key, turns);
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

  /// Builds the HTTP request for [p]. Public for tests.
  static (Uri, Map<String, String>, Map<String, dynamic>) buildRequest(
      AiProvider p, String model, String key, List<AiTurn> turns) {
    if (p.isGemini) {
      return (
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'),
        {'Content-Type': 'application/json', 'x-goog-api-key': key},
        {
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
        }
      );
    }
    if (p.isAnthropic) {
      return (
        Uri.parse('https://api.anthropic.com/v1/messages'),
        {
          'Content-Type': 'application/json',
          'x-api-key': key,
          'anthropic-version': '2023-06-01',
          'anthropic-dangerous-direct-browser-access': 'true',
        },
        {
          'model': model,
          'max_tokens': 1500,
          'system': systemPrompt,
          'messages': [
            for (final t in turns) {'role': t.fromUser ? 'user' : 'assistant', 'content': t.text}
          ],
        }
      );
    }
    // OpenAI-compatible chat completions (OpenAI, Groq, DeepSeek, OpenRouter).
    return (
      Uri.parse('${p.baseUrl}/chat/completions'),
      {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
        if (p.id == 'openrouter') 'X-Title': 'TrackMe',
      },
      {
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          for (final t in turns) {'role': t.fromUser ? 'user' : 'assistant', 'content': t.text}
        ],
        if (p.id != 'openrouter') 'response_format': {'type': 'json_object'},
      }
    );
  }

  static Future<AiDraft> _call(http.Client c, AiProvider p, String model, String key, List<AiTurn> turns) async {
    final (uri, headers, body) = buildRequest(p, model, key, turns);
    final http.Response res;
    try {
      res = await c.post(uri, headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 45));
    } catch (_) {
      throw const AiException('No connection. AI needs internet; everything else works offline.');
    }
    final lower = res.body.toLowerCase();
    final modelProblem = lower.contains('model') &&
        (lower.contains('not found') || lower.contains('does not exist') || lower.contains('not_found') ||
            lower.contains('decommissioned') || lower.contains('invalid model') || lower.contains('not supported'));
    if (res.statusCode == 404 || (res.statusCode == 400 && modelProblem)) {
      throw const AiException('model:This AI model is not available right now. You can set a model name in the key menu.');
    }
    if (res.statusCode == 429) {
      throw const AiException('AI usage limit reached for now. Check your provider quota and try later.');
    }
    if (res.statusCode == 402) {
      throw AiException('Your ${p.name} account has no credit left. Add credit or switch provider (key icon).');
    }
    if (res.statusCode == 400 || res.statusCode == 401 || res.statusCode == 403) {
      throw AiException('Your ${p.name} key was rejected. Check it in the AI menu (key icon).');
    }
    if (res.statusCode >= 500) throw const AiException('The AI service is busy. Try again.');
    if (res.statusCode != 200) throw AiException('AI error (${res.statusCode}).');

    final text = extractText(res.body);
    if (text == null) throw const AiException('The AI gave an empty answer. Try rephrasing.');
    return parseDraft(text);
  }

  /// Pulls the answer text out of a Gemini, Anthropic or OpenAI-style response.
  static String? extractText(String responseBody) {
    try {
      final j = jsonDecode(responseBody) as Map<String, dynamic>;
      final buf = StringBuffer();
      final candidates = j['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final parts = ((candidates.first as Map?)?['content'] as Map?)?['parts'] as List?;
        for (final p in parts ?? const []) {
          if (p is Map && p['thought'] != true && p['text'] is String) buf.write(p['text']);
        }
      } else if (j['choices'] is List && (j['choices'] as List).isNotEmpty) {
        final content = (((j['choices'] as List).first as Map)['message'] as Map?)?['content'];
        if (content is String) buf.write(content);
      } else if (j['content'] is List) {
        for (final b in j['content'] as List) {
          if (b is Map && b['type'] == 'text' && b['text'] is String) buf.write(b['text']);
        }
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
