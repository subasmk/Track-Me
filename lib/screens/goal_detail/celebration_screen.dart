import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/achievement.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/sloth_sticker.dart';

/// Full-screen celebration shown right after a successful "Complete Today".
/// Mirrors the reference design: sloth + confetti burst, "Great work!",
/// the new streak number, the note the user just wrote, and any badges
/// unlocked in this completion.
class CelebrationScreen extends StatefulWidget {
  final int newStreak;
  final bool isNewLongest;
  final bool leveledUp;
  final int newLevel;
  final String noteText;
  final List<Achievement> newBadges;

  const CelebrationScreen({
    super.key,
    required this.newStreak,
    required this.isNewLongest,
    required this.leveledUp,
    required this.newLevel,
    required this.noteText,
    this.newBadges = const [],
  });

  @override
  State<CelebrationScreen> createState() => _CelebrationScreenState();
}

class _CelebrationScreenState extends State<CelebrationScreen> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  numberOfParticles: 24,
                  maxBlastForce: 22,
                  minBlastForce: 8,
                  gravity: 0.25,
                  colors: const [
                    AppColors.purpleLight,
                    AppColors.purpleMid,
                    AppColors.flameOrange,
                    AppColors.flameYellow,
                    Colors.white,
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SlothStickerView(sticker: SlothSticker.levelUp, size: 150)
                        .animate()
                        .scale(
                          begin: const Offset(0.6, 0.6),
                          end: const Offset(1, 1),
                          duration: 450.ms,
                          curve: Curves.elasticOut,
                        ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Great work!',
                      style: AppTextStyles.display.copyWith(fontSize: 30),
                    ).animate().fadeIn(delay: 150.ms),
                    const SizedBox(height: 6),
                    Text(
                      'Your streak is now',
                      style: AppTextStyles.bodyMuted,
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 30)),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.newStreak} ${widget.newStreak == 1 ? 'day' : 'days'}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: AppColors.flameOrange,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 250.ms).scale(
                        begin: const Offset(0.85, 0.85),
                        end: const Offset(1, 1),
                        curve: Curves.easeOutBack),
                    if (widget.isNewLongest) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.flameOrange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: const Text(
                          '🏆 New personal best!',
                          style: TextStyle(
                            color: AppColors.flameOrange,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ).animate().fadeIn(delay: 350.ms),
                    ],
                    if (widget.leveledUp) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.purpleMid.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          '⭐ Level up! Now Level ${widget.newLevel}',
                          style: const TextStyle(
                            color: AppColors.purpleLight,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ).animate().fadeIn(delay: 400.ms),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    if (widget.noteText.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Today's Note", style: AppTextStyles.caption),
                            const SizedBox(height: 8),
                            Text(widget.noteText, style: AppTextStyles.body),
                          ],
                        ),
                      ).animate().fadeIn(delay: 450.ms),
                    if (widget.newBadges.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: widget.newBadges
                            .map((b) => Chip(
                                  avatar: Icon(b.icon,
                                      color: b.color, size: 18),
                                  label: Text(b.title),
                                  backgroundColor: AppColors.surface,
                                  side: BorderSide(
                                      color: b.color.withOpacity(0.4)),
                                ))
                            .toList(),
                      ).animate().fadeIn(delay: 500.ms),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('OK'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
