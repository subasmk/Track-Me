import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quest.dart';
import '../screens/quests/quest_detail_screen.dart';
import '../services/quest_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

Color difficultyColor(String d) {
  switch (d) {
    case 'Easy':
      return AppColors.success;
    case 'Hard':
      return AppColors.flameRed;
    default:
      return AppColors.flameYellow;
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                fontSize: 11)),
      );
}

class ProgressRing extends StatelessWidget {
  final double progress;
  final double size;
  final double stroke;
  final Color color;
  final Widget? child;
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 64,
    this.stroke = 8,
    this.color = AppColors.success,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0, 1)),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (_, value, __) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(value, stroke, color),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final double stroke;
  final Color color;
  _RingPainter(this.value, this.stroke, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final deflated = rect.deflate(stroke / 2);
    canvas.drawArc(deflated, 0, math.pi * 2, false,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);
    if (value <= 0) return;
    canvas.drawArc(
        deflated,
        -math.pi / 2,
        math.pi * 2 * value,
        false,
        Paint()
          ..shader = SweepGradient(
            startAngle: -math.pi / 2,
            endAngle: math.pi * 1.5,
            colors: [color.withValues(alpha: 0.7), color],
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color;
}

class LevelBadge extends StatelessWidget {
  final int level;
  const LevelBadge({super.key, required this.level});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: AppColors.flameGradient,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text('LV $level',
            style: AppTextStyles.caption.copyWith(
                color: const Color(0xFF3A1A00), fontWeight: FontWeight.w900, fontSize: 12)),
      );
}

class MetaChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const MetaChip({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 11, color: color), const SizedBox(width: 3)],
        Text(label, style: AppTextStyles.caption.copyWith(color: color, fontSize: 11)),
      ]),
    );
  }
}

/// Quest list card: emoji, title, wrapped metadata, progress bar and a
/// tappable sub-task checklist.
class QuestCard extends StatelessWidget {
  final Quest quest;
  const QuestCard({super.key, required this.quest});

  @override
  Widget build(BuildContext context) {
    final done = quest.isCompletedToday;
    final questService = context.read<QuestService>();
    final progress = quest.todayProgress;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => QuestDetailScreen(questId: quest.id)),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: done ? AppColors.success.withValues(alpha: 0.45) : AppColors.surfaceBorder,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProgressRing(
                    progress: progress,
                    size: 52,
                    stroke: 4,
                    child: Text(quest.emoji, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(quest.title,
                                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (done)
                            const Icon(Icons.check_circle, color: AppColors.success, size: 20)
                          else
                            Text('+${quest.xp} XP',
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.purpleLight, fontWeight: FontWeight.w800)),
                        ]),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            MetaChip(
                                label: quest.difficulty,
                                color: difficultyColor(quest.difficulty)),
                            if (quest.streak > 0)
                              MetaChip(
                                  label: '${quest.streak}',
                                  icon: Icons.local_fire_department,
                                  color: AppColors.flameOrange),
                            if (quest.timeRange != null)
                              MetaChip(
                                  label: quest.timeRange!,
                                  icon: Icons.schedule,
                                  color: AppColors.textSecondary),
                            if (!quest.isAllDays)
                              MetaChip(label: quest.daysLabel, color: AppColors.purpleLight),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (quest.items.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...quest.items.map((item) {
                  final itemDone = done || item.isDone;
                  return InkWell(
                    onTap: () => questService.toggleQuestItem(quest.id, item.id),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
                      child: Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: itemDone ? AppColors.success : Colors.transparent,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                                color: itemDone ? AppColors.success : AppColors.textMuted,
                                width: 1.5),
                          ),
                          child: itemDone
                              ? const Icon(Icons.check, size: 15, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(item.name,
                              style: AppTextStyles.body.copyWith(
                                fontSize: 14,
                                decoration: itemDone ? TextDecoration.lineThrough : null,
                                color: itemDone ? AppColors.textMuted : AppColors.textPrimary,
                              )),
                        ),
                        Text(item.targetLabel,
                            style: AppTextStyles.caption.copyWith(fontSize: 12)),
                      ]),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
