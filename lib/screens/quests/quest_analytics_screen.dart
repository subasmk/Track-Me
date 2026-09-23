import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/quest.dart';
import '../../services/progression_service.dart';
import '../../services/quest_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_clock.dart';
import '../../widgets/quest_ui.dart';

/// Completion stats computed from each quest's completionHistory.
class QuestStats {
  /// Completions per day for the last [days] days (oldest first).
  static List<int> dailyCompletions(List<Quest> quests, int days, DateTime now) {
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final counts = List<int>.filled(days, 0);
    for (final q in quests) {
      for (final d in q.completionHistory) {
        final day = DateTime(d.year, d.month, d.day);
        final i = day.difference(start).inDays;
        if (i >= 0 && i < days) counts[i]++;
      }
    }
    return counts;
  }

  /// Share of scheduled days in the last [days] days the quest was done.
  static double completionRate(Quest q, int days, DateTime now) {
    var scheduled = 0;
    var done = 0;
    final today = DateTime(now.year, now.month, now.day);
    final created = DateTime(q.createdAt.year, q.createdAt.month, q.createdAt.day);
    for (var i = 0; i < days; i++) {
      final day = today.subtract(Duration(days: i));
      if (day.isBefore(created)) break;
      if (!q.isScheduledForDay(day.weekday)) continue;
      scheduled++;
      if (q.completionHistory.any((d) => AppClock.isSameDay(d, day))) done++;
    }
    return scheduled == 0 ? 0 : done / scheduled;
  }
}

class QuestAnalyticsScreen extends StatelessWidget {
  const QuestAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final quests = context.watch<QuestService>().quests;
    final progression = context.watch<ProgressionService>();
    final now = AppClock.now();
    final week = QuestStats.dailyCompletions(quests, 7, now);
    final month = QuestStats.dailyCompletions(quests, 28, now);
    final maxWeek = week.fold<int>(1, (m, v) => v > m ? v : m);
    final totalFocus = quests.fold<int>(0, (s, q) => s + q.focusMinutes);
    final best = quests.fold<int>(0, (m, q) => q.longestStreak > m ? q.longestStreak : m);
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    Widget stat(String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(children: [
              Text(value, style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w900)),
              Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
            ]),
          ),
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(leading: const BackButton(), title: const Text('Quest stats')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(children: [
            stat('LV ${progression.level}', '${progression.totalXp} XP'),
            const SizedBox(width: 8),
            stat('${month.fold<int>(0, (a, b) => a + b)}', 'done in 28 days'),
            const SizedBox(width: 8),
            stat('$best', 'best streak'),
            const SizedBox(width: 8),
            stat('${(totalFocus / 60).toStringAsFixed(1)}h', 'focus'),
          ]),
          const SizedBox(height: AppSpacing.lg),
          const SectionLabel('Last 7 days'),
          Container(
            height: 172,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text('${week[i]}', style: AppTextStyles.caption.copyWith(fontSize: 11)),
                      const SizedBox(height: 4),
                      Container(
                        height: 80 * week[i] / maxWeek + 4,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [AppColors.purpleMid, AppColors.success],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(labels[now.subtract(Duration(days: 6 - i)).weekday - 1],
                          style: AppTextStyles.caption.copyWith(
                              fontWeight: i == 6 ? FontWeight.w900 : FontWeight.w500)),
                    ]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionLabel('Last 28 days'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in month)
                Container(
                  width: 38,
                  height: 22,
                  decoration: BoxDecoration(
                    color: c == 0
                        ? AppColors.surfaceLight
                        : AppColors.success.withValues(alpha: (0.3 + 0.2 * c).clamp(0.3, 1.0)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionLabel('Completion rate (30 days)'),
          for (final q in quests)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Text(q.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(q.title, style: AppTextStyles.body.copyWith(fontSize: 14)),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: QuestStats.completionRate(q, 30, now),
                        minHeight: 7,
                        backgroundColor: AppColors.surfaceLight,
                        valueColor: const AlwaysStoppedAnimation(AppColors.success),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 10),
                Text('${(QuestStats.completionRate(q, 30, now) * 100).round()}%',
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800)),
              ]),
            ),
        ],
      ),
    );
  }
}
