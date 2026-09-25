import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/quest.dart';
import '../../models/quest_templates.dart';
import '../../services/ai_service.dart';
import '../../widgets/system_ui.dart';
import '../add_goal/add_goal_screen.dart';
import '../quests/add_quest_screen.dart';

class _Msg {
  final bool fromUser;
  final String text;
  final AiDraft? draft;
  final bool error;
  const _Msg(this.fromUser, this.text, {this.draft, this.error = false});
}

/// Chat-style "System" assistant that drafts quests and goals from a
/// prompt. It only suggests: a draft opens in the normal create screen,
/// and nothing is saved until the user taps Create there.
class AiChatScreen extends StatefulWidget {
  /// For previews and tests: skip the key check and show these messages.
  final List<(bool fromUser, String text, AiDraft? draft)>? debugMessages;
  /// For previews: show the composer in its listening state.
  final bool debugListening;
  const AiChatScreen({super.key, this.debugMessages, this.debugListening = false});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

final _shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(4));
final _filled = FilledButton.styleFrom(
    backgroundColor: SysColors.blue, foregroundColor: Colors.white, shape: _shape,
    textStyle: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800, letterSpacing: 1));
final _outlined = OutlinedButton.styleFrom(
    foregroundColor: SysColors.cyanSoft, side: const BorderSide(color: SysColors.cyan), shape: _shape,
    textStyle: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800, letterSpacing: 1));

class _AiChatScreenState extends State<AiChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _msgs = <_Msg>[];
  bool? _hasKey;
  bool _busy = false;

  // Voice input: on-device speech-to-text. Spoken words land in the
  // composer so they can be edited before sending.
  final _speech = SpeechToText();
  bool _speechReady = false;
  bool _listening = false;
  String _textBeforeVoice = '';

  static const _suggestions = [
    'I want to learn AWS in 30 days',
    'Morning workout for a beginner',
    'Read 20 pages every night',
    'Practice guitar 3 times a week',
  ];

  @override
  void initState() {
    super.initState();
    final dbg = widget.debugMessages;
    if (dbg != null) {
      _hasKey = true;
      _listening = widget.debugListening;
      if (_listening) _input.text = 'I want to run a 5K in two months';
      _msgs.addAll(dbg.map((m) => _Msg(m.$1, m.$2, draft: m.$3)));
    } else {
      AiService.hasKey().then((v) {
        if (mounted) setState(() => _hasKey = v);
      });
    }
  }

  @override
  void dispose() {
    if (_listening && !widget.debugListening) _speech.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _toggleVoice() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!_speechReady) {
      try {
        _speechReady = await _speech.initialize(
          onStatus: (s) {
            if ((s == 'done' || s == 'notListening') && mounted && _listening) {
              setState(() => _listening = false);
            }
          },
          onError: (SpeechRecognitionError e) {
            if (mounted) setState(() => _listening = false);
            if (e.errorMsg == 'error_no_match' || e.errorMsg == 'error_speech_timeout') {
              _toast("Didn't catch that. Tap the mic and try again.");
            } else if (e.errorMsg.contains('permission')) {
              _toast('Microphone access is off. Allow it in Settings to use voice.');
            } else if (e.errorMsg.contains('network')) {
              _toast('Voice needs a connection on this phone. You can type instead.');
            }
          },
        );
      } catch (_) {
        _speechReady = false;
      }
      if (!_speechReady) {
        final perm = await _speech.hasPermission.catchError((_) => false);
        _toast(perm
            ? 'Voice input is not available on this phone. You can type instead.'
            : 'Microphone access is off. Allow it in Settings to use voice.');
        return;
      }
    }
    _textBeforeVoice = _input.text.trim();
    setState(() => _listening = true);
    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult r) {
          final heard = r.recognizedWords;
          final text = _textBeforeVoice.isEmpty ? heard : '$_textBeforeVoice $heard';
          _input.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 4),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _listening = false);
      _toast('Voice input is not available on this phone. You can type instead.');
    }
  }

  Future<void> _send([String? preset]) async {
    if (_listening) {
      _speech.stop();
      _listening = false;
    }
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _busy) return;
    _input.clear();
    setState(() {
      _msgs.add(_Msg(true, text));
      _busy = true;
    });
    _toBottom();
    final turns = <AiTurn>[
      for (final m in _msgs.where((m) => !m.error).toList().reversed.take(10).toList().reversed)
        AiTurn(m.fromUser, m.fromUser ? m.text : _describe(m)),
    ];
    try {
      final d = await AiService.draft(turns);
      if (mounted) setState(() => _msgs.add(_Msg(false, d.reply, draft: d.hasDraft ? d : null)));
    } on AiException catch (e) {
      if (mounted) setState(() => _msgs.add(_Msg(false, e.message, error: true)));
    } catch (_) {
      if (mounted) setState(() => _msgs.add(const _Msg(false, 'Something went wrong. Try again.', error: true)));
    } finally {
      if (mounted) setState(() => _busy = false);
      _toBottom();
    }
  }

  /// What the assistant said last time, so it can refine its own draft.
  String _describe(_Msg m) {
    final d = m.draft;
    if (d == null) return m.text;
    if (d.isQuest) {
      final q = d.quest!;
      final items = q.items.map((i) => '${i.$1}: ${i.$2}x${i.$3} ${i.$4}').join('; ');
      return '${m.text}\n[Draft quest: ${q.title} ${q.emoji}, ${q.type}, ${q.difficulty}, '
          '${q.startTime ?? '-'}-${q.endTime ?? '-'}, days ${q.days.join(',')}, items: $items]';
    }
    return '${m.text}\n[Draft goal: ${d.goalTitle} ${d.goalEmoji}, ${d.goalMinutes} min/day]';
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 200,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _open(AiDraft d) async {
    final route = d.isQuest
        ? MaterialPageRoute(builder: (_) => AddQuestScreen(draft: d.quest))
        : MaterialPageRoute(
            builder: (_) => AddGoalScreen(
                initialTitle: d.goalTitle, initialEmoji: d.goalEmoji, initialMinutes: d.goalMinutes));
    await Navigator.push(context, route);
  }

  Future<void> _keySheet() async {
    var prov = await AiService.provider();
    final ctrl = TextEditingController();
    final modelCtrl = TextEditingController(text: await AiService.customModel(prov.id) ?? '');
    var showAdvanced = modelCtrl.text.isNotEmpty;
    String? error;
    if (!mounted) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SysColors.bg,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('AI PROVIDER', style: SysText.header),
            const SizedBox(height: 6),
            const Text('Use a key from any provider below. Stored only on this phone. Never synced or backed up.',
                style: TextStyle(color: SysColors.muted, height: 1.35)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in AiService.providers)
                ChoiceChip(
                  label: Text(p.isGemini ? 'Gemini (free)' : p.name),
                  selected: p.id == prov.id,
                  onSelected: (_) => setSheet(() {
                    prov = p;
                    error = null;
                  }),
                  selectedColor: SysColors.blue.withValues(alpha: 0.35),
                  side: BorderSide(color: p.id == prov.id ? SysColors.cyan : SysColors.cyan.withValues(alpha: 0.3)),
                  shape: _shape,
                  labelStyle: TextStyle(
                      color: p.id == prov.id ? Colors.white : SysColors.cyanSoft, fontWeight: FontWeight.w700),
                  showCheckmark: false,
                ),
            ]),
            const SizedBox(height: 10),
            Text(prov.note, style: const TextStyle(color: SysColors.muted)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(prov.keyUrl), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text('Get a ${prov.name} key'),
                style: TextButton.styleFrom(foregroundColor: SysColors.cyan, padding: EdgeInsets.zero),
              ),
            ),
            TextField(
              controller: ctrl,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              style: SysText.body,
              onChanged: (v) {
                final g = AiService.guessProvider(v);
                if (g != null && g.id != prov.id) setSheet(() => prov = g);
              },
              decoration: InputDecoration(hintText: 'Paste your key (${prov.keyHint})', errorText: error),
            ),
            if (!showAdvanced)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setSheet(() => showAdvanced = true),
                  style: TextButton.styleFrom(foregroundColor: SysColors.muted, padding: EdgeInsets.zero),
                  child: const Text('Advanced: choose a model'),
                ),
              )
            else ...[
              const SizedBox(height: 10),
              TextField(
                controller: modelCtrl,
                autocorrect: false,
                style: SysText.body,
                decoration: InputDecoration(
                    hintText: 'Model (optional, default ${prov.models.first})', helperText: 'Leave empty for the default.'),
              ),
            ],
            const SizedBox(height: 14),
            Row(children: [
              if (_hasKey == true)
                TextButton(
                  onPressed: () async {
                    await AiService.removeKey();
                    if (ctx.mounted) Navigator.pop(ctx, false);
                  },
                  child: const Text('Remove key', style: TextStyle(color: SysColors.warn)),
                ),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  if (ctrl.text.trim().length < 20) {
                    setSheet(() => error = 'That key looks too short.');
                    return;
                  }
                  await AiService.saveKey(ctrl.text, providerId: prov.id, model: modelCtrl.text);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                style: _filled,
                child: const Text('Save'),
              ),
            ]),
          ]),
        ),
      ),
    );
    if (saved != null) {
      final has = await AiService.hasKey();
      if (mounted) setState(() => _hasKey = has);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SysColors.bg,
      appBar: AppBar(
        backgroundColor: SysColors.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('SYSTEM ASSISTANT', style: SysText.header),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'API key',
            icon: const Icon(Icons.key_rounded, color: SysColors.cyanSoft),
            onPressed: _keySheet,
          ),
        ],
      ),
      body: SysBackground(
        child: SafeArea(
          top: false,
          child: _hasKey == null
              ? const SizedBox()
              : _hasKey == false
                  ? _setup()
                  : Column(children: [
                      Expanded(child: _chat()),
                      _composer(),
                    ]),
        ),
      ),
    );
  }

  Widget _setup() {
    Widget step(String n, String t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$n  ', style: SysText.label),
            Expanded(child: Text(t, style: SysText.body)),
          ]),
        );
    return ListView(padding: const EdgeInsets.all(20), children: [
      SysPanel(
        tag: 'ACTIVATE ASSISTANT',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text(
              'Describe a goal and the System drafts the quest for you. Bring a key from any AI provider: Gemini, OpenAI, Claude, Groq, DeepSeek or OpenRouter.',
              style: TextStyle(color: SysColors.muted, height: 1.4)),
          const SizedBox(height: 16),
          step('01', 'Recommended: Google Gemini is free. Open Google AI Studio and sign in.'),
          step('02', 'Tap "Create API key" and copy it.'),
          step('03', 'Tap Add key, pick your provider and paste it. It stays on this phone only.'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse(AiService.keyPageUrl), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Get a free Gemini key'),
            style: _outlined,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _keySheet,
            icon: const Icon(Icons.key_rounded, size: 18),
            label: const Text('Add key'),
            style: _filled,
          ),
        ]),
      ),
    ]);
  }

  Widget _chat() {
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      children: [
        _bot(const _Msg(false,
            'Human, tell me what you want to become. I will draft a quest. You review it before anything is added.')),
        if (_msgs.isEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in _suggestions)
              ActionChip(
                label: Text(s, style: const TextStyle(color: SysColors.cyanSoft, fontSize: 12)),
                backgroundColor: SysColors.panelBottom,
                side: BorderSide(color: SysColors.cyan.withValues(alpha: 0.5)),
                onPressed: () => _send(s),
              ),
          ]),
        ],
        for (final m in _msgs) m.fromUser ? _user(m.text) : _bot(m),
        if (_busy) _typing(),
      ],
    );
  }

  Widget _user(String text) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(top: 10, left: 60),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: SysColors.blue.withValues(alpha: 0.35),
            border: Border.all(color: SysColors.blue.withValues(alpha: 0.8)),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14), topRight: Radius.circular(14), bottomLeft: Radius.circular(14)),
          ),
          child: Text(text, style: SysText.body),
        ),
      );

  Widget _avatar() => Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.only(right: 8, top: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: SysColors.cyan),
          boxShadow: [BoxShadow(color: SysColors.cyan.withValues(alpha: 0.4), blurRadius: 8)],
          color: SysColors.panelBottom,
        ),
        child: const Text('!', style: TextStyle(color: SysColors.cyan, fontWeight: FontWeight.w900)),
      );

  Widget _bot(_Msg m) => Padding(
        padding: const EdgeInsets.only(top: 10, right: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _avatar(),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: SysColors.panelTop,
                  border: Border.all(
                      color: (m.error ? SysColors.warn : SysColors.cyan).withValues(alpha: 0.6)),
                ),
                child: Text(m.text,
                    style: SysText.body.copyWith(color: m.error ? SysColors.warn : SysColors.text, height: 1.35)),
              ),
              if (m.draft != null) ...[const SizedBox(height: 8), _draftCard(m.draft!)],
            ]),
          ),
        ]),
      );

  Widget _draftCard(AiDraft d) {
    if (d.isGoal) {
      return SysPanel(
        tag: 'NEW GOAL',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${d.goalEmoji}  ${d.goalTitle}'.toUpperCase(), style: SysText.header.copyWith(fontSize: 14, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text('${d.goalMinutes} min every day', style: SysText.mono),
          const SizedBox(height: 14),
          _cardButtons(d),
        ]),
      );
    }
    final QuestTemplate q = d.quest!;
    final window = q.startTime == null ? 'ANY TIME' : '${q.startTime}${q.endTime != null ? ' - ${q.endTime}' : ''}';
    const dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final days = q.days.length >= 7 ? 'EVERYDAY' : q.days.map((x) => dayNames[x - 1]).join(' ');
    return SysPanel(
      tag: 'NEW QUEST',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${q.emoji}  ${q.title}'.toUpperCase(), style: SysText.header.copyWith(fontSize: 14, letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Text('${q.type.toUpperCase()}  ·  ${q.difficulty.toUpperCase()}  ·  $window  ·  $days', style: SysText.label),
        const SizedBox(height: 12),
        for (final i in q.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              const SysCheck(checked: false, size: 16),
              const SizedBox(width: 10),
              Expanded(child: Text(i.$1, style: SysText.body)),
              Text('[${i.$2}${i.$4.isEmpty ? '' : ' ${i.$4}'}${i.$3 > 1 ? ' × ${i.$3}' : ''}]',
                  style: SysText.mono.copyWith(color: SysColors.cyanSoft)),
            ]),
          ),
        const SizedBox(height: 10),
        Text('REWARD  +${Quest.xpForDifficulty(q.difficulty)} XP  ·  +${Quest.goldForDifficulty(q.difficulty)} GOLD',
            style: SysText.label.copyWith(color: SysColors.gold)),
        const SizedBox(height: 14),
        _cardButtons(d),
      ]),
    );
  }

  Widget _cardButtons(AiDraft d) => Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _busy ? null : () => _send('Make it a bit different'),
style: _outlined,
            child: const Text('Try again'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            onPressed: () => _open(d),
            style: _filled,
            child: const Text('Review'),
          ),
        ),
      ]);

  Widget _typing() => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(children: [
          _avatar(),
          const Text('Analyzing...', style: SysText.label),
        ]),
      );

  Widget _composer() => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: SysColors.panelBottom,
          border: Border(top: BorderSide(color: SysColors.cyan.withValues(alpha: 0.4))),
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              style: SysText.body,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: _listening ? 'Listening... speak your goal' : 'Describe your goal or tap the mic',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          IconButton(
            tooltip: _listening ? 'Stop listening' : 'Speak',
            onPressed: _busy ? null : _toggleVoice,
            icon: _listening
                ? Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: SysColors.cyan.withValues(alpha: 0.18),
                      border: Border.all(color: SysColors.cyan),
                      boxShadow: [BoxShadow(color: SysColors.cyan.withValues(alpha: 0.6), blurRadius: 12)],
                    ),
                    child: const Icon(Icons.mic_rounded, color: SysColors.cyan, size: 20),
                  )
                : const Icon(Icons.mic_none_rounded, color: SysColors.cyan),
          ),
          IconButton(
            onPressed: _busy ? null : _send,
            icon: const Icon(Icons.send_rounded, color: SysColors.cyan),
          ),
        ]),
      );
}
