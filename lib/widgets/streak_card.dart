import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../utils/app_clock.dart';
import '../utils/date_utils_x.dart';
import 'sloth_sticker.dart';
import 'system_ui.dart';

/// How the sloth feels about the current streak. Drives the sticker and the
/// one-line status on the home streak card.
class SlothStreakMood {
  final SlothSticker sticker;
  final String line;
  final Color color;
  const SlothStreakMood(this.sticker, this.line, this.color);

  static SlothStreakMood of({required int streak, required bool doneToday, required bool hadHistory}) {
    if (doneToday && streak >= 30) {
      return const SlothStreakMood(SlothSticker.cheering, 'Legend status. Your sloth is throwing a party.', SysColors.gold);
    }
    if (doneToday && streak >= 7) {
      return const SlothStreakMood(SlothSticker.fitness, 'On fire. Your sloth is flexing.', SysColors.ok);
    }
    if (doneToday) {
      return const SlothStreakMood(SlothSticker.happy, 'Done for today. Your sloth is happy.', SysColors.ok);
    }
    if (streak > 0) {
      final h = AppClock.now().hour;
      return h >= 18
          ? SlothStreakMood(SlothSticker.worried, 'Your $streak-day streak ends at midnight. Finish one today.', SysColors.warn)
          : SlothStreakMood(SlothSticker.ready, 'Your sloth is ready. Keep the $streak-day streak going.', SysColors.cyanSoft);
    }
    if (hadHistory) {
      return const SlothStreakMood(SlothSticker.worried, 'Streak lost. Your sloth misses you - start again today.', SysColors.warn);
    }
    return const SlothStreakMood(SlothSticker.sleepy, 'Your sloth is still asleep. Finish one goal to wake it up.', SysColors.muted);
  }
}

/// Home hero: current streak, best, next milestone, the week strip and a
/// sloth whose mood follows the streak. Drawn as a System window.
class StreakCard extends StatelessWidget {
  final int streakDays;
  final int bestStreak;
  final bool doneToday;
  final bool hadHistory;
  final Set<int> completedWeekdayIndices; // 0=Sun .. 6=Sat
  final VoidCallback? onTap;

  const StreakCard({
    super.key,
    required this.streakDays,
    required this.completedWeekdayIndices,
    this.bestStreak = 0,
    this.doneToday = false,
    this.hadHistory = false,
    this.onTap,
  });

  static const _milestones = [3, 7, 14, 30, 60, 100, 365];

  @override
  Widget build(BuildContext context) {
    final now = AppClock.now();
    final week = DateUtilsX.weekDates(now);
    final todayIndex = now.weekday % 7;
    final mood = SlothStreakMood.of(streak: streakDays, doneToday: doneToday, hadHistory: hadHistory);
    final next = _milestones.firstWhere((m) => m > streakDays, orElse: () => streakDays + 1);
    final prev = _milestones.lastWhere((m) => m <= streakDays, orElse: () => 0);
    final progress = (streakDays - prev) / (next - prev);

    return SysPanel(
      tag: 'Streak',
      accent: doneToday ? SysColors.ok : SysColors.cyan,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('$streakDays',
                        style: SysText.header.copyWith(fontSize: 46, letterSpacing: 0, height: 1))
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('DAY STREAK',
                      style: SysText.label.copyWith(fontSize: 12)),
                ),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 16, runSpacing: 2, children: [
                Text('BEST  $bestStreak', style: SysText.label),
                Text('NEXT BADGE  $next', style: SysText.label),
              ]),
              const SizedBox(height: 8),
              SysBar(value: progress.clamp(0, 1).toDouble(), color: SysColors.gold),
              const SizedBox(height: 4),
              Text('${next - streakDays} ${next - streakDays == 1 ? 'day' : 'days'} to the $next-day badge',
                  style: SysText.label.copyWith(fontSize: 10, letterSpacing: 0.8)),
            ]),
          ),
          const SizedBox(width: 8),
          if (Provider.of<SettingsService?>(context)?.reduceMotion ?? false)
            SlothStickerView(sticker: mood.sticker, size: 96, glow: false)
          else
            SlothStickerView(sticker: mood.sticker, size: 96, glow: false)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: 0, end: -4, duration: 1400.ms, curve: Curves.easeInOut),
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: mood.color.withValues(alpha: 0.08),
            border: Border.all(color: mood.color.withValues(alpha: 0.5)),
          ),
          child: Text(mood.line, style: SysText.body.copyWith(color: mood.color, fontSize: 13)),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final isDone = completedWeekdayIndices.contains(i);
            final isToday = i == todayIndex;
            final isFuture = week[i].isAfter(now) && !DateUtilsX.isSameDay(week[i], now);
            return _DayBox(
                letter: DateUtilsX.weekdayLetters[i], isDone: isDone, isToday: isToday, isFuture: isFuture);
          }),
        ),
      ]),
    );
  }
}

class _DayBox extends StatelessWidget {
  final String letter;
  final bool isDone;
  final bool isToday;
  final bool isFuture;
  const _DayBox({required this.letter, required this.isDone, required this.isToday, required this.isFuture});

  @override
  Widget build(BuildContext context) {
    final border = isDone
        ? SysColors.ok
        : isToday
            ? SysColors.cyan
            : SysColors.muted.withValues(alpha: isFuture ? 0.25 : 0.5);
    return Column(children: [
      Text(letter,
          style: SysText.label.copyWith(
              color: isToday ? SysColors.cyan : SysColors.muted, fontSize: 11, letterSpacing: 0)),
      const SizedBox(height: 6),
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isDone ? SysColors.ok.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(color: border, width: isToday ? 2 : 1),
          boxShadow: isToday
              ? [BoxShadow(color: SysColors.cyan.withValues(alpha: 0.4), blurRadius: 8)]
              : null,
        ),
        child: isDone ? const Icon(Icons.check, size: 18, color: SysColors.ok) : null,
      ),
    ]);
  }
}
