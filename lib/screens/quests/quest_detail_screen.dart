import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/quest_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../models/quest.dart';
import '../../services/quest_share.dart';
import '../../services/reminder_service.dart';
import '../../utils/app_clock.dart';
import '../../widgets/pin_quest_widget.dart';
import '../../widgets/sloth_sticker.dart';
import '../../widgets/system_ui.dart';
import 'add_quest_screen.dart';
import 'focus_timer_screen.dart';

class QuestDetailScreen extends StatefulWidget {
  final String questId;
  const QuestDetailScreen({super.key, required this.questId});

  @override
  State<QuestDetailScreen> createState() => _QuestDetailScreenState();
}

class _QuestDetailScreenState extends State<QuestDetailScreen> {
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 2));
  bool? _wasDone;

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _celebrateIfJustCompleted(Quest quest, QuestService service) {
    final done = quest.isCompletedToday;
    if (_wasDone == false && done) {
      _confetti.play();
      final levelUp = service.takeLevelUp();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          builder: (_) => _RewardDialog(quest: quest, levelUp: levelUp),
        );
      });
    }
    _wasDone = done;
  }

  @override
  Widget build(BuildContext context) {
    final questService = context.watch<QuestService>();
    final quest = questService.questById(widget.questId);

    if (quest == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(leading: const BackButton()),
        body: const Center(
          child: Text('Quest not found', style: TextStyle(color: AppColors.textMuted)),
        ),
      );
    }
    _celebrateIfJustCompleted(quest, questService);

    final done = quest.isCompletedToday;
    final sticker = stickerFor(
      progress: quest.todayProgress,
      allDone: done,
      hour: AppClock.now().hour,
      type: quest.type,
    );

    return Scaffold(
      backgroundColor: SysColors.bg,
      appBar: AppBar(
        backgroundColor: SysColors.bg,
        iconTheme: const IconThemeData(color: SysColors.cyanSoft),
        leading: const BackButton(),
        title: const Text('Quest'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddQuestScreen(existingQuest: quest)),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'widget') pinQuestWidgetWithFeedback(context, quest);
              if (v == 'share') {
                await SharePlus.instance.share(ShareParams(
                    text: QuestShare.shareText(quest), subject: 'TrackMe quest'));
              }
              if (v == 'reminder') await _pickReminder(context, quest, questService);
              if (v == 'reminder_off') await questService.setReminder(quest.id, null);
              if (v == 'delete') await _confirmDelete(context, quest, questService);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'reminder',
                  child: Text(quest.reminderTime == null
                      ? 'Set daily reminder'
                      : 'Reminder: ${quest.reminderTime} (change)')),
              if (quest.reminderTime != null)
                const PopupMenuItem(value: 'reminder_off', child: Text('Turn off reminder')),
              const PopupMenuItem(value: 'share', child: Text('Share with a friend')),
              const PopupMenuItem(value: 'widget', child: Text('Add widget to home screen')),
              const PopupMenuItem(value: 'delete', child: Text('Delete quest')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          SysBackground(
            child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 120),
            children: [
              _Hero(quest: quest, sticker: sticker),
              const SizedBox(height: 16),
              _StatsRow(quest: quest),
              const SizedBox(height: 16),
              if (quest.items.isNotEmpty) ...[
                SysPanel(
                  tag: 'Goals',
                  child: Column(children: [
                    for (final item in quest.items)
                      _TaskRow(
                        name: item.name,
                        target: item.progressLabel,
                        unit: item.unit,
                        done: done || item.isDone,
                        isNext: quest.nextItem?.id == item.id,
                        onTap: () => questService.toggleQuestItem(quest.id, item.id),
                      ),
                    const SizedBox(height: 12),
                    Text(
                        done
                            ? 'QUEST CLEARED. The streak is safe today.'
                            : 'WARNING: Leave this quest unfinished today and the streak resets to 0.',
                        textAlign: TextAlign.center,
                        style: SysText.label.copyWith(
                            color: done ? SysColors.ok : SysColors.warn, letterSpacing: 0.8, fontSize: 12)),
                  ]),
                ),
                const SizedBox(height: 16),
              ],
              _RewardStrip(quest: quest),
            ],
          ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 30,
              colors: const [
                AppColors.flameYellow,
                AppColors.success,
                AppColors.purpleLight,
                AppColors.flameOrange,
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, AppSpacing.md),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => FocusTimerScreen(questId: quest.id)),
                ),
                icon: const Icon(Icons.timer_outlined),
                label: const Text('Focus'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.purpleLight,
                  side: const BorderSide(color: AppColors.purpleMid),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: done ? null : () => questService.completeToday(quest.id),
                icon: Icon(done ? Icons.check_circle : Icons.bolt),
                label: Text(done ? 'Completed today' : 'Complete quest'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  disabledBackgroundColor: AppColors.success.withValues(alpha: 0.25),
                  foregroundColor: const Color(0xFF052E16),
                  disabledForegroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w800, fontSize: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _pickReminder(BuildContext context, Quest quest, QuestService service) async {
    final current = ReminderService.parseTime(quest.reminderTime ?? quest.startTime);
    final picked = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 8, minute: 0)
          : TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: 'Daily reminder for ${quest.title}',
    );
    if (picked == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final granted = await ReminderService.requestPermission();
    final time =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await service.setReminder(quest.id, time);
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(granted
          ? 'Reminder set for $time on ${quest.daysLabel}.'
          : 'Reminder saved for $time, but notifications are off. Allow them in Android settings.'),
    ));
  }

  Future<void> _confirmDelete(BuildContext context, Quest quest, QuestService service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete quest?'),
        content: Text('"${quest.title}" and its streak will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await service.deleteQuest(quest.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class _Hero extends StatelessWidget {
  final Quest quest;
  final SlothSticker sticker;
  const _Hero({required this.quest, required this.sticker});

  @override
  Widget build(BuildContext context) {
    final done = quest.isCompletedToday;
    final message = done
        ? 'Quest complete. See you tomorrow!'
        : quest.nextItem != null
            ? 'Next up: ${quest.nextItem!.name}'
            : quest.isScheduledForToday
                ? 'Ready when you are.'
                : 'Not scheduled today (${quest.daysLabel}).';
    final accent = done ? SysColors.ok : SysColors.cyan;
    return SysPanel(
      tag: done ? 'Quest Cleared' : 'Quest Info',
      accent: accent,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${quest.emoji}  ${quest.title.toUpperCase()}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SysText.header.copyWith(fontSize: 18, letterSpacing: 1.5)),
              const SizedBox(height: 10),
              Text('TYPE      ${quest.type.toUpperCase()}', style: SysText.label),
              const SizedBox(height: 4),
              Text('DIFFICULTY  ${quest.difficulty.toUpperCase()}', style: SysText.label),
              const SizedBox(height: 4),
              Text('SCHEDULE  ${quest.timeRange ?? 'ANY TIME'} · ${quest.daysLabel.toUpperCase()}',
                  style: SysText.label),
            ]),
          ),
          SlothStickerView(sticker: sticker, size: 84, glow: false),
        ]),
        const SizedBox(height: 12),
        SysBar(value: quest.todayProgress, color: accent),
        const SizedBox(height: 10),
        Text(message, style: SysText.body.copyWith(color: SysColors.cyanSoft)),
      ]),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Quest quest;
  const _StatsRow({required this.quest});

  @override
  Widget build(BuildContext context) {
    Widget tile(String value, String label, IconData icon, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: SysColors.panelBottom,
              border: Border.all(color: SysColors.cyan.withValues(alpha: 0.45)),
            ),
            child: Column(children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(value, style: SysText.mono.copyWith(fontSize: 18)),
              Text(label.toUpperCase(), style: SysText.label.copyWith(fontSize: 9, letterSpacing: 1.2)),
            ]),
          ),
        );
    return Row(children: [
      tile('${quest.streak}', 'streak', Icons.local_fire_department, AppColors.flameOrange),
      const SizedBox(width: 8),
      tile('${quest.longestStreak}', 'best', Icons.emoji_events_outlined, AppColors.flameYellow),
      const SizedBox(width: 8),
      tile('${quest.completionHistory.length}', 'completions', Icons.check_circle_outline,
          AppColors.success),
      const SizedBox(width: 8),
      tile('${quest.focusMinutes}', 'focus min', Icons.timer_outlined, AppColors.purpleLight),
    ]);
  }
}

class _TaskRow extends StatelessWidget {
  final String name;
  final String target;
  final String unit;
  final bool done;
  final bool isNext;
  final VoidCallback onTap;
  const _TaskRow({
    required this.name,
    required this.target,
    required this.unit,
    required this.done,
    required this.isNext,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          if (isNext && !done)
            const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.play_arrow, size: 14, color: SysColors.cyan)),
          Expanded(
            child: Text(name,
                style: SysText.body.copyWith(
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done ? SysColors.muted : SysColors.text,
                )),
          ),
          Text('[$target $unit]'.replaceAll(' ]', ']'),
              style: SysText.mono.copyWith(color: done ? SysColors.ok : SysColors.cyanSoft)),
          const SizedBox(width: 12),
          SysCheck(checked: done),
        ]),
      ),
    );
  }
}

class _RewardStrip extends StatelessWidget {
  final Quest quest;
  const _RewardStrip({required this.quest});

  @override
  Widget build(BuildContext context) {
    return SysPanel(
      tag: 'Reward',
      accent: SysColors.gold,
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Text('+${quest.xp} XP', style: SysText.mono.copyWith(fontSize: 18, color: SysColors.gold)),
          Text('+${quest.gold} GOLD', style: SysText.mono.copyWith(fontSize: 18, color: SysColors.gold)),
        ]),
        const SizedBox(height: 8),
        Text('STAT BOOST: ${quest.focusStats.toUpperCase()}',
            textAlign: TextAlign.center, style: SysText.label),
      ]),
    );
  }
}

class _RewardDialog extends StatelessWidget {
  final Quest quest;
  final bool levelUp;
  const _RewardDialog({required this.quest, required this.levelUp});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SlothStickerView(
              sticker: levelUp ? SlothSticker.levelUp : SlothSticker.cheering, size: 150),
          const SizedBox(height: AppSpacing.sm),
          Text(levelUp ? 'Level up!' : 'Quest complete!',
              style: AppTextStyles.headline, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('+${quest.xp} XP  ·  +${quest.gold} gold  ·  🔥 ${quest.streak} day streak',
              style: AppTextStyles.bodyMuted, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(backgroundColor: AppColors.purpleMid),
              child: const Text('Nice!'),
            ),
          ),
        ]),
      ),
    );
  }
}
