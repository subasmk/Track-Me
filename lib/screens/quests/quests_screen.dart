import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/progression_service.dart';
import '../../services/quest_service.dart';
import '../../services/quest_share.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../models/quest.dart';
import '../../utils/app_clock.dart';
import '../../widgets/pin_quest_widget.dart';
import '../../widgets/quest_ui.dart';
import '../../widgets/sloth_sticker.dart';
import '../../widgets/system_ui.dart';
import 'quest_detail_screen.dart';
import 'add_quest_screen.dart';
import 'quest_analytics_screen.dart';

class QuestsScreen extends StatefulWidget {
  const QuestsScreen({super.key});

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
  bool _showCompleted = false;
  bool _showOtherDays = false;

  @override
  Widget build(BuildContext context) {
    final questService = context.watch<QuestService>();
    final activeQuests = questService.activeQuestsToday
      ..sort((a, b) => (a.startTime ?? '99').compareTo(b.startTime ?? '99'));
    final completedQuests = questService.completedQuestsToday;
    final otherQuests = questService.otherDaysQuests;
    final totalCount = questService.totalQuestsCount;

    return Scaffold(
      backgroundColor: SysColors.bg,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: SysColors.bg,
        leading: const BackButton(color: SysColors.cyanSoft),
        iconTheme: const IconThemeData(color: SysColors.cyanSoft),
        title: const Text('QUEST LOG', style: SysText.header),
        actions: [
          IconButton(
            tooltip: 'Stats',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const QuestAnalyticsScreen())),
          ),
          IconButton(
            tooltip: 'Import a shared quest',
            icon: const Icon(Icons.group_add_outlined),
            onPressed: () => showImportQuestDialog(context),
          ),
          IconButton(
            tooltip: 'Add widget to home screen',
            icon: const Icon(Icons.widgets_outlined),
            onPressed: () => pinQuestWidgetWithFeedback(context, null),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddQuestScreen()),
        ),
        backgroundColor: SysColors.bg,
        shape: const BeveledRectangleBorder(
            side: BorderSide(color: SysColors.cyan, width: 1.4),
            borderRadius: BorderRadius.all(Radius.circular(8))),
        icon: const Icon(Icons.add, color: SysColors.cyan),
        label: const Text('NEW QUEST', style: SysText.label),
      ),
      body: SysBackground(
        child: SafeArea(
        child: totalCount == 0
            ? const _EmptyState()
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, 100),
                children: [
                  _TodayHero(
                    done: questService.completedTodayCount,
                    total: questService.totalTodayCount,
                    next: activeQuests.isEmpty ? null : activeQuests.first,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (activeQuests.isNotEmpty) ...[
                    const Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 10),
                        child: Text('ACTIVE QUESTS', style: SysText.label)),
                    ...activeQuests.map((quest) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: QuestCard(quest: quest),
                        )),
                  ] else if (completedQuests.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Center(
                        child: Text('No quests scheduled today. Enjoy the rest day.',
                            style: SysText.body.copyWith(color: SysColors.muted)),
                      ),
                    ),
                  if (completedQuests.isNotEmpty)
                    _Collapsible(
                      label: 'Completed today (${completedQuests.length})',
                      open: _showCompleted || activeQuests.isEmpty,
                      onTap: () => setState(() => _showCompleted = !_showCompleted),
                      children: completedQuests.map((q) => QuestCard(quest: q)).toList(),
                    ),
                  if (otherQuests.isNotEmpty)
                    _Collapsible(
                      label: 'Other days (${otherQuests.length})',
                      open: _showOtherDays,
                      onTap: () => setState(() => _showOtherDays = !_showOtherDays),
                      children: otherQuests.map((q) => QuestCard(quest: q)).toList(),
                    ),
                ],
              ),
        ),
      ),
    );
  }
}

class _TodayHero extends StatelessWidget {
  final int done;
  final int total;
  final Quest? next;
  const _TodayHero({required this.done, required this.total, required this.next});

  @override
  Widget build(BuildContext context) {
    final progression = context.watch<ProgressionService>();
    final quests = context.watch<QuestService>().quests;
    final progress = total == 0 ? 0.0 : done / total;
    final allDone = total > 0 && done == total;
    final sticker = stickerFor(
      progress: progress,
      allDone: allDone,
      hour: AppClock.now().hour,
      type: next?.type,
    );

    // Stats grow with every completed quest of that type.
    int stat(List<String> types) => 10 +
        quests
            .where((q) => types.contains(q.type))
            .fold<int>(0, (n, q) => n + q.completionHistory.length);
    final today = quests.where((q) => q.isScheduledForToday).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SysPanel(
        tag: 'Status',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('LEVEL', style: SysText.label),
              Text('${progression.level}',
                  style: const TextStyle(
                      color: SysColors.text,
                      fontSize: 48,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: SysColors.cyan, blurRadius: 16)])),
            ]),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('RANK  ${SysRank.rank(progression.level)}', style: SysText.label),
                const SizedBox(height: 4),
                Text('TITLE  ${SysRank.title(progression.level)}',
                    style: SysText.label.copyWith(color: SysColors.gold)),
                const SizedBox(height: 8),
                SysBar(value: progression.levelProgress),
                const SizedBox(height: 4),
                Text('XP ${progression.xpIntoLevel} / ${progression.xpForNextLevel}',
                    style: SysText.mono.copyWith(fontSize: 11, color: SysColors.muted)),
              ]),
            ),
            SlothStickerView(sticker: sticker, size: 72, glow: false),
          ]),
          const SizedBox(height: 14),
          Container(height: 1, color: SysColors.cyan.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: SysStat(label: 'STR', value: stat(['Fitness']), icon: Icons.fitness_center)),
            const SizedBox(width: 24),
            Expanded(child: SysStat(label: 'INT', value: stat(['Study']), icon: Icons.psychology_alt)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: SysStat(label: 'AGI', value: stat(['Skill']), icon: Icons.bolt)),
            const SizedBox(width: 24),
            Expanded(child: SysStat(label: 'SEN', value: stat(['Mindfulness', 'Custom']), icon: Icons.visibility)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.toll, size: 16, color: SysColors.gold),
            const SizedBox(width: 6),
            Text('GOLD', style: SysText.label.copyWith(color: SysColors.gold)),
            const Spacer(),
            Text('${progression.gold}', style: SysText.mono.copyWith(fontSize: 16, color: SysColors.gold)),
          ]),
        ]),
      ),
      const SizedBox(height: 18),
      SysPanel(
        tag: 'Daily Quest',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
              allDone
                  ? 'All daily quests cleared.'
                  : total == 0
                      ? 'No quests today. Rest and recover.'
                      : 'Complete today\'s quests to grow stronger.',
              textAlign: TextAlign.center,
              style: SysText.body.copyWith(color: SysColors.cyanSoft)),
          if (today.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Center(child: Text('GOALS', style: SysText.label)),
            const SizedBox(height: 10),
            for (final q in today)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Expanded(
                      child: Text(q.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: SysText.body)),
                  Text(
                      q.items.isEmpty
                          ? (q.isCompletedToday ? '[1/1]' : '[0/1]')
                          : '[${q.isCompletedToday ? q.items.length : q.doneItemCount}/${q.items.length}]',
                      style: SysText.mono.copyWith(
                          color: q.isCompletedToday ? SysColors.ok : SysColors.text)),
                  const SizedBox(width: 10),
                  SysCheck(checked: q.isCompletedToday),
                ]),
              ),
            const SizedBox(height: 12),
            SysBar(value: progress, height: 5),
            const SizedBox(height: 14),
            Text(
                allDone
                    ? 'REWARD: streaks protected, XP and gold granted.'
                    : 'WARNING: Leave a daily quest unfinished and its streak resets to 0.',
                textAlign: TextAlign.center,
                style: SysText.label.copyWith(
                    color: allDone ? SysColors.ok : SysColors.warn, letterSpacing: 0.8, fontSize: 12)),
          ],
        ]),
      ),
    ]);
  }
}

class _Collapsible extends StatelessWidget {
  final String label;
  final bool open;
  final VoidCallback onTap;
  final List<Widget> children;
  const _Collapsible(
      {required this.label, required this.open, required this.onTap, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(children: [
              Icon(open ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  color: SysColors.cyanSoft, size: 20),
              const SizedBox(width: 4),
              Text(label.toUpperCase(), style: SysText.label),
            ]),
          ),
        ),
        if (open)
          ...children.map((c) =>
              Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: c)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SlothStickerView(sticker: SlothSticker.ready, size: 150),
            const SizedBox(height: AppSpacing.md),
            Text('No quests yet', style: AppTextStyles.title),
            const SizedBox(height: 6),
            Text(
              'Create a quest: a daily challenge with a few small tasks. Start from a template or build your own.',
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens a quest's detail screen.
void openQuest(BuildContext context, Quest quest) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuestDetailScreen(questId: quest.id)),
    );


/// Paste a quest code a friend shared and add it as a new quest.
Future<void> showImportQuestDialog(BuildContext context) async {
  final controller = TextEditingController();
  final clip = await Clipboard.getData(Clipboard.kTextPlain);
  if (clip?.text != null && QuestShare.decode(clip!.text!) != null) {
    controller.text = clip.text!;
  }
  if (!context.mounted) return;
  final questService = context.read<QuestService>();
  final messenger = ScaffoldMessenger.of(context);
  final shared = await showDialog<SharedQuest>(
    context: context,
    builder: (ctx) {
      String? error;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Import a shared quest'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Paste the message or code your friend sent',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final q = QuestShare.decode(controller.text);
                if (q == null) {
                  setState(() => error = 'No valid quest code found');
                } else {
                  Navigator.pop(ctx, q);
                }
              },
              child: const Text('Import'),
            ),
          ],
        ),
      );
    },
  );
  controller.dispose();
  if (shared == null) return;
  await questService.addQuest(
    title: shared.title,
    emoji: shared.emoji,
    type: shared.type,
    difficulty: shared.difficulty,
    startTime: shared.startTime,
    endTime: shared.endTime,
    items: shared.items,
    focusStats: shared.focusStats,
    targetDays: shared.days,
  );
  messenger.showSnackBar(SnackBar(content: Text('Added "${shared.title}" to your quests')));
}
