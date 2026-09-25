import 'package:flutter/material.dart';
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
  const AiChatScreen({super.key, this.debugMessages});

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
      _msgs.addAll(dbg.map((m) => _Msg(m.$1, m.$2, draft: m.$3)));
    } else {
      AiService.hasKey().then((v) {
        if (mounted) setState(() => _hasKey = v);
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
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
    final ctrl = TextEditingController();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SysColors.bg,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('GEMINI API KEY', style: SysText.header),
          const SizedBox(height: 10),
          const Text('Stored only on this phone. Never synced or backed up.', style: TextStyle(color: SysColors.muted)),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            obscureText: true,
            autocorrect: false,
            style: SysText.body,
            decoration: const InputDecoration(hintText: 'Paste your key'),
          ),
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
                if (ctrl.text.trim().length < 20) return;
                await AiService.saveKey(ctrl.text);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              style: _filled,
              child: const Text('Save'),
            ),
          ]),
        ]),
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
          const Text('Describe a goal and the System drafts the quest for you. It uses Google Gemini, which has a free tier.',
              style: TextStyle(color: SysColors.muted, height: 1.4)),
          const SizedBox(height: 16),
          step('01', 'Open Google AI Studio and sign in with your Google account.'),
          step('02', 'Tap "Create API key" and copy it.'),
          step('03', 'Paste it here. It stays on this phone only.'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse(AiService.keyPageUrl), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Get a free key'),
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
            'Hunter, tell me what you want to become. I will draft a quest. You review it before anything is added.')),
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
              decoration: const InputDecoration(
                hintText: 'Describe your goal...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          IconButton(
            onPressed: _busy ? null : _send,
            icon: const Icon(Icons.send_rounded, color: SysColors.cyan),
          ),
        ]),
      );
}
