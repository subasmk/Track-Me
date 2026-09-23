import 'package:flutter/material.dart';

/// Illustrated sloth moods (same character as the home-screen widgets).
enum SlothSticker {
  ready('ready'),
  focused('focused'),
  cheering('cheering'),
  levelUp('levelup'),
  fitness('fitness'),
  calm('calm'),
  happy('happy'),
  playful('playful'),
  sleepy('sleepy'),
  worried('worried');

  const SlothSticker(this.file);
  final String file;
  String get asset => 'assets/mascot/sloth_$file.png';
}

/// Picks the sticker that fits a quest moment.
SlothSticker stickerFor({
  required double progress,
  required bool allDone,
  required int hour,
  String? type,
}) {
  if (allDone) return SlothSticker.cheering;
  if (hour >= 22 || hour < 5) return SlothSticker.sleepy;
  if (progress > 0) {
    if (type == 'Fitness') return SlothSticker.fitness;
    if (type == 'Mindfulness') return SlothSticker.calm;
    return SlothSticker.focused;
  }
  if (hour >= 19) return SlothSticker.worried;
  return SlothSticker.ready;
}

class SlothStickerView extends StatelessWidget {
  final SlothSticker sticker;
  final double size;
  final bool glow;
  const SlothStickerView({super.key, required this.sticker, this.size = 96, this.glow = true});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      sticker.asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => SizedBox(width: size, height: size),
    );
    if (!glow) return image;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          width: size * 0.9,
          height: size * 0.9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              const Color(0xFF7EC8FF).withValues(alpha: 0.28),
              const Color(0xFF7EC8FF).withValues(alpha: 0),
            ]),
          ),
        ),
        image,
      ]),
    );
  }
}
