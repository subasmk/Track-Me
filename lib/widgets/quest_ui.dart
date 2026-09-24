import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'system_ui.dart';

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
    final accent = done ? SysColors.ok : SysColors.cyan;

    return SysPanel(
      accent: accent,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => QuestDetailScreen(questId: quest.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: accent.withValues(alpha: 0.7)),
                color: accent.withValues(alpha: 0.08),
              ),
              child: Text(quest.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(quest.title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SysText.header.copyWith(fontSize: 14, letterSpacing: 1.6)),
                const SizedBox(height: 4),
                Text(
                    [
                      'RANK ${_rankFor(quest.difficulty)}',
                      if (quest.timeRange != null) quest.timeRange!,
                      if (!quest.isAllDays) quest.daysLabel,
                    ].join('  ·  '),
                    style: SysText.label.copyWith(fontSize: 10, color: SysColors.muted)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (done)
                Text('CLEAR', style: SysText.label.copyWith(color: SysColors.ok))
              else
                Text('+${quest.xp} XP', style: SysText.label.copyWith(color: SysColors.gold)),
              if (quest.streak > 0) ...[
                const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.local_fire_department, size: 13, color: AppColors.flameOrange),
                  Text('${quest.streak}', style: SysText.mono.copyWith(fontSize: 12)),
                ]),
              ],
            ]),
          ]),
          const SizedBox(height: 10),
          SysBar(value: progress, color: accent, height: 4),
          if (quest.items.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...quest.items.map((item) {
              final itemDone = done || item.isDone;
              return InkWell(
                onTap: () => questService.toggleQuestItem(quest.id, item.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  child: Row(children: [
                    Expanded(
                      child: Text(item.name,
                          style: SysText.body.copyWith(
                            fontSize: 14,
                            decoration: itemDone ? TextDecoration.lineThrough : null,
                            color: itemDone ? SysColors.muted : SysColors.text,
                          )),
                    ),
                    Text('[${itemDone ? item.targetLabel : '0 / ${item.targetLabel}'}]',
                        style: SysText.mono.copyWith(
                            fontSize: 12, color: itemDone ? SysColors.ok : SysColors.cyanSoft)),
                    const SizedBox(width: 10),
                    SysCheck(checked: itemDone, size: 18),
                  ]),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  static String _rankFor(String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return 'E';
      case 'Hard':
        return 'B';
      case 'Epic':
        return 'A';
      default:
        return 'D';
    }
  }
}
