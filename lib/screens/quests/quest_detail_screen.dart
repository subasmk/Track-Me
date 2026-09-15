import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/quest_service.dart';
import '../../services/home_widget_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../models/quest.dart';
import 'add_quest_screen.dart';

class QuestDetailScreen extends StatelessWidget {
  final String questId;
  const QuestDetailScreen({super.key, required this.questId});

  @override
  Widget build(BuildContext context) {
    final questService = context.watch<QuestService>();
    final quest = questService.questById(questId);

    if (quest == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(leading: const BackButton()),
        body: const Center(
          child: Text('Quest not found', style: TextStyle(color: AppColors.textMuted)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: _QuestInfoPanel(quest: quest, questService: questService),
        ),
      ),
    );
  }
}

class _QuestInfoPanel extends StatelessWidget {
  final Quest quest;
  final QuestService questService;
  const _QuestInfoPanel({required this.quest, required this.questService});

  @override
  Widget build(BuildContext context) {
    final done = quest.isCompletedToday;

    return Column(
      children: [
        // Header row: checkmark icon + "QUEST INFO" + close
        _Header(quest: quest, onClose: () => Navigator.pop(context)),
        const SizedBox(height: AppSpacing.md),

        // Main panel
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: done
                    ? AppColors.success.withOpacity(0.5)
                    : AppColors.purpleMid.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quest name
                  Center(
                    child: Text(
                      '[Quest: ${quest.title}]',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Time range
                  if (quest.timeRange != null)
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule,
                              color: AppColors.textMuted, size: 15),
                          const SizedBox(width: 5),
                          Text(
                            quest.timeRange!,
                            style: AppTextStyles.body.copyWith(
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: AppSpacing.md),

                  // Streak row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.trending_up,
                          color: AppColors.flameOrange, size: 16),
                      const SizedBox(width: 5),
                      Text(
                        '${quest.streak} Day Streak',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.flameOrange,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 20),
                      const Icon(Icons.emoji_events,
                          color: AppColors.flameYellow, size: 16),
                      const SizedBox(width: 5),
                      Text(
                        'Longest: ${quest.longestStreak}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.flameYellow,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Divider
                  Divider(
                    color: AppColors.surfaceBorder,
                    thickness: 1,
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // Goals section header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.checklist_rounded,
                          color: AppColors.purpleMid, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Goals',
                        style: AppTextStyles.title.copyWith(
                            color: AppColors.purpleLight),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // Quest items
                  if (quest.items.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No goals added yet',
                          style: AppTextStyles.bodyMuted,
                        ),
                      ),
                    )
                  else
                    ...quest.items.map((item) => _GoalRow(
                          item: item,
                          completed: done,
                        )),

                  const SizedBox(height: AppSpacing.md),

                  // Footer: type, difficulty, xp, gold, focus
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Type: ${quest.type} | Difficulty: ${quest.difficulty}',
                          style: AppTextStyles.caption,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${quest.xp} XP | ${quest.gold} G | Focus: ${quest.focusStats}',
                          style: AppTextStyles.caption,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Add to Home Screen Widget Option
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await HomeWidgetService.pinQuestWidget(quest);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Requested adding "${quest.title}" widget to Home Screen! 📲'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.widgets_outlined, size: 18),
                      label: const Text('Add to Home Screen'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.purpleLight,
                        side: const BorderSide(color: AppColors.purpleMid),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Actions row: Edit + Complete
        Row(
          children: [
            // Edit button
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddQuestScreen(existingQuest: quest),
                ),
              ),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.surfaceBorder),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 12),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Complete button
            Expanded(
              child: _CompleteButton(quest: quest, questService: questService),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.sm),

        // Delete button
        TextButton(
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.surface,
                title: const Text('Delete Quest'),
                content: Text(
                    'Delete "${quest.title}"? This cannot be undone.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete',
                        style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              ),
            );
            if (confirm == true && context.mounted) {
              await questService.deleteQuest(quest.id);
              if (context.mounted) Navigator.pop(context);
            }
          },
          child: Text('Delete Quest',
              style: AppTextStyles.caption.copyWith(color: AppColors.danger)),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final Quest quest;
  final VoidCallback onClose;
  const _Header({required this.quest, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.success, width: 1.5),
          ),
          child: const Icon(Icons.check_circle_outline,
              color: AppColors.success, size: 24),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.surfaceBorder, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              'QUEST INFO',
              style: AppTextStyles.headline.copyWith(
                fontSize: 18,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        GestureDetector(
          onTap: onClose,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.danger.withOpacity(0.4), width: 1),
            ),
            child: const Icon(Icons.close, color: AppColors.danger, size: 18),
          ),
        ),
      ],
    );
  }
}

class _GoalRow extends StatelessWidget {
  final dynamic item; // QuestItem
  final bool completed;
  const _GoalRow({required this.item, required this.completed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(item.name, style: AppTextStyles.body),
          ),
          Text(
            '[${item.target}/${item.target} ${item.sets}]',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: completed
                  ? AppColors.success.withOpacity(0.2)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: completed
                    ? AppColors.success
                    : AppColors.surfaceBorder,
                width: 1.5,
              ),
            ),
            child: completed
                ? const Icon(Icons.check, size: 14, color: AppColors.success)
                : null,
          ),
        ],
      ),
    );
  }
}

class _CompleteButton extends StatelessWidget {
  final Quest quest;
  final QuestService questService;
  const _CompleteButton({required this.quest, required this.questService});

  @override
  Widget build(BuildContext context) {
    final done = quest.isCompletedToday;

    return ElevatedButton.icon(
      onPressed: done
          ? null
          : () async {
              await questService.completeToday(quest.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${quest.emoji} Quest completed! +${quest.xp} XP',
                    ),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
      icon: Icon(
        done ? Icons.check_circle : Icons.check_circle_outline,
        size: 20,
        color: done ? AppColors.textMuted : AppColors.textPrimary,
      ),
      label: Text(
        done ? 'COMPLETED' : 'COMPLETE QUEST',
        style: AppTextStyles.button.copyWith(
          color: done ? AppColors.textMuted : AppColors.textPrimary,
          letterSpacing: 1.2,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: done ? AppColors.surfaceLight : AppColors.success,
        disabledBackgroundColor: AppColors.surfaceLight,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: done ? AppColors.surfaceBorder : AppColors.success,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
