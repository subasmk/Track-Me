import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/progression_service.dart';
import '../../services/quest_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../models/quest.dart';
import '../../utils/app_clock.dart';
import '../../widgets/pin_quest_widget.dart';
import '../../widgets/quest_ui.dart';
import '../../widgets/sloth_sticker.dart';
import 'quest_detail_screen.dart';
import 'add_quest_screen.dart';

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Quests'),
        actions: [
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
        backgroundColor: AppColors.purpleMid,
        icon: const Icon(Icons.add, color: AppColors.textPrimary),
        label: const Text('New quest',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
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
                    const SectionLabel('Up next'),
                    ...activeQuests.map((quest) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: QuestCard(quest: quest),
                        )),
                  ] else if (completedQuests.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Center(
                        child: Text('No quests scheduled today. Enjoy the rest day.',
                            style: AppTextStyles.bodyMuted),
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
    final progress = total == 0 ? 0.0 : done / total;
    final allDone = total > 0 && done == total;
    final sticker = stickerFor(
      progress: progress,
      allDone: allDone,
      hour: AppClock.now().hour,
      type: next?.type,
    );
    final headline = allDone
        ? 'All done today!'
        : total == 0
            ? 'Rest day'
            : done == 0
                ? "Let's get moving"
                : 'Keep going';
    final sub = allDone
        ? 'Every quest is complete. Streaks are safe.'
        : next != null
            ? 'Next: ${next!.emoji} ${next!.title}${next!.startTime != null ? ' at ${next!.startTime}' : ''}'
            : 'Nothing left for today.';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B7FD4), Color(0xFF063370)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProgressRing(
                progress: progress,
                size: 84,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$done/$total',
                      style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w900)),
                  Text('today', style: AppTextStyles.caption.copyWith(color: Colors.white70)),
                ]),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headline,
                        style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              SlothStickerView(sticker: sticker, size: 88, glow: false),
            ],
          ),
          ...[
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              LevelBadge(level: progression.level),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progression.levelProgress,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation(AppColors.flameYellow),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${progression.xpIntoLevel} / ${progression.xpForNextLevel} XP to level ${progression.level + 1}',
                      style: AppTextStyles.caption.copyWith(color: Colors.white70, fontSize: 11)),
                ]),
              ),
              const SizedBox(width: 10),
              Text('🪙 ${progression.gold}',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800)),
            ]),
          ],
        ],
      ),
    );
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
                  color: AppColors.textMuted, size: 20),
              const SizedBox(width: 4),
              Text(label,
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
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
