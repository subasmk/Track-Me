import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/quest_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../models/quest.dart';
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
    final activeQuests = questService.activeQuestsToday;
    final completedQuests = questService.completedQuestsToday;
    final otherQuests = questService.otherDaysQuests;
    final totalCount = questService.totalQuestsCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Quests'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Text(
              '${questService.completedTodayCount}/${questService.totalTodayCount} today',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddQuestScreen()),
        ),
        backgroundColor: AppColors.purpleMid,
        child: const Icon(Icons.add, color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: totalCount == 0
            ? const _EmptyState()
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, 100),
                children: [
                  // Active Quests Today Section
                  if (activeQuests.isNotEmpty) ...[
                    ...activeQuests.map((quest) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _QuestCard(quest: quest),
                        )),
                  ] else if (completedQuests.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.success.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppColors.success, size: 28),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'All quests for today are completed! 🎉',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Center(
                        child: Text(
                          'No active quests for today',
                          style: AppTextStyles.bodyMuted,
                        ),
                      ),
                    ),
                  ],

                  // Completed Today Section (Invisible by default, toggleable)
                  if (completedQuests.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    InkWell(
                      onTap: () => setState(() => _showCompleted = !_showCompleted),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(
                          children: [
                            Icon(
                              _showCompleted
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_right,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Completed Today (${completedQuests.length})',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showCompleted) ...[
                      const SizedBox(height: 6),
                      ...completedQuests.map((quest) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _QuestCard(quest: quest),
                          )),
                    ],
                  ],

                  // Other Days Section (Toggleable)
                  if (otherQuests.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    InkWell(
                      onTap: () => setState(() => _showOtherDays = !_showOtherDays),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(
                          children: [
                            Icon(
                              _showOtherDays
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_right,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Scheduled for Other Days (${otherQuests.length})',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showOtherDays) ...[
                      const SizedBox(height: 6),
                      ...otherQuests.map((quest) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _QuestCard(quest: quest),
                          )),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  final Quest quest;
  const _QuestCard({required this.quest});

  @override
  Widget build(BuildContext context) {
    final done = quest.isCompletedToday;
    final questService = context.watch<QuestService>();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: done
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.surfaceBorder,
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuestDetailScreen(questId: quest.id),
              ),
            ),
            child: Row(
              children: [
                // Left: emoji + done ring
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      alignment: Alignment.center,
                      child: Text(quest.emoji, style: const TextStyle(fontSize: 26)),
                    ),
                    if (done)
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 2),
                        ),
                        child: const Icon(Icons.check, size: 10, color: Colors.white),
                      ),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                // Middle: info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(quest.title, style: AppTextStyles.body, maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          _Chip(label: quest.type, color: AppColors.purpleMid),
                          const SizedBox(width: 6),
                          _Chip(
                            label: quest.difficulty,
                            color: _difficultyColor(quest.difficulty),
                          ),
                          const SizedBox(width: 6),
                          _Chip(
                            label: quest.daysLabel,
                            color: AppColors.purpleLight,
                          ),
                          if (quest.items.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            _Chip(
                              label: '${quest.items.length} sub-tasks',
                              color: AppColors.textMuted,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.local_fire_department,
                              color: AppColors.flameOrange, size: 14),
                          const SizedBox(width: 3),
                          Text(
                            '${quest.streak} day streak',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.flameOrange),
                          ),
                          if (quest.timeRange != null) ...[
                            const SizedBox(width: 10),
                            const Icon(Icons.schedule,
                                color: AppColors.textMuted, size: 13),
                            const SizedBox(width: 3),
                            Text(
                              quest.timeRange!,
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Right: XP badge
                Column(
                  children: [
                    Text(
                      '${quest.xp}',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.purpleLight,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text('XP', style: AppTextStyles.caption),
                  ],
                ),
              ],
            ),
          ),

          // Sub-tasks checklist section inside Quest card
          if (quest.items.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(color: AppColors.surfaceBorder, height: 16),
            ...quest.items.map((item) {
              final itemDone = done || item.isDone;
              return InkWell(
                onTap: () async {
                  await questService.toggleQuestItem(quest.id, item.id);
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: itemDone
                              ? AppColors.success
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: itemDone
                                ? AppColors.success
                                : AppColors.textMuted,
                            width: 1.5,
                          ),
                        ),
                        child: itemDone
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.name,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 13,
                            decoration: itemDone ? TextDecoration.lineThrough : null,
                            color: itemDone ? AppColors.textMuted : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${item.target} ${item.unit}',
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Color _difficultyColor(String d) {
    switch (d) {
      case 'Easy':
        return AppColors.success;
      case 'Hard':
        return AppColors.flameRed;
      default:
        return AppColors.flameYellow;
    }
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: AppTextStyles.caption.copyWith(color: color, fontSize: 10)),
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
            const Icon(Icons.shield_outlined, size: 64, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text('No quests yet', style: AppTextStyles.title),
            const SizedBox(height: 6),
            Text(
              'Tap the + button to create your first quest — a structured daily challenge with multiple goals.',
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
