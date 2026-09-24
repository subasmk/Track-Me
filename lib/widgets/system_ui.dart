import 'package:flutter/material.dart';

/// "System window" look for quests: dark translucent holographic panels
/// with a glowing cyan frame, bracket corners and spaced caps headers.
/// All shapes are drawn in code (no third-party artwork).
class SysColors {
  SysColors._();
  static const cyan = Color(0xFF3FD4FF);
  static const cyanSoft = Color(0xFF8BE6FF);
  static const blue = Color(0xFF1E6BFF);
  static const bg = Color(0xFF03060F);
  static const panelTop = Color(0xE60A1A33);
  static const panelBottom = Color(0xE6050D1C);
  static const text = Color(0xFFE6F7FF);
  static const muted = Color(0xFF7FA9C7);
  static const warn = Color(0xFFFF4D5E);
  static const gold = Color(0xFFFFD166);
  static const ok = Color(0xFF4DFFB8);
}

class SysText {
  SysText._();
  static const header = TextStyle(
      color: SysColors.text,
      fontSize: 15,
      fontWeight: FontWeight.w800,
      letterSpacing: 3,
      shadows: [Shadow(color: SysColors.cyan, blurRadius: 10)]);
  static const label = TextStyle(
      color: SysColors.cyanSoft, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.2);
  static const body = TextStyle(color: SysColors.text, fontSize: 14, fontWeight: FontWeight.w600);
  static const mono = TextStyle(
      color: SysColors.text,
      fontSize: 13,
      fontWeight: FontWeight.w700,
      fontFeatures: [FontFeature.tabularFigures()]);
}

/// Screen background: near-black with a faint blue glow and scanlines.
class SysBackground extends StatelessWidget {
  final Widget child;
  const SysBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.8),
            radius: 1.3,
            colors: [Color(0xFF0B2448), SysColors.bg],
          ),
        ),
        child: CustomPaint(painter: _ScanlinePainter(), child: child),
      );
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x0A3FD4FF);
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A glowing system window. [tag] shows a boxed "!" + title header such as
/// "DAILY QUEST".
class SysPanel extends StatelessWidget {
  final Widget child;
  final String? tag;
  final Color accent;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const SysPanel({
    super.key,
    required this.child,
    this.tag,
    this.accent = SysColors.cyan,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [SysColors.panelTop, SysColors.panelBottom],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.85), width: 1.2),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 18, spreadRadius: -2),
        ],
      ),
      child: CustomPaint(
        foregroundPainter: _BracketPainter(accent),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tag != null) ...[SysTag(tag!, accent: accent), const SizedBox(height: 14)],
              child,
            ],
          ),
        ),
      ),
    );
    if (onTap == null) return panel;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: panel);
  }
}

class SysTag extends StatelessWidget {
  final String text;
  final Color accent;
  const SysTag(this.text, {super.key, this.accent = SysColors.cyan});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: accent.withValues(alpha: 0.9)),
            color: accent.withValues(alpha: 0.08),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(border: Border.all(color: accent), shape: BoxShape.circle),
              child: Text('!',
                  style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 10),
            Text(text.toUpperCase(), style: SysText.header),
          ]),
        ),
      );
}

class _BracketPainter extends CustomPainter {
  final Color color;
  _BracketPainter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    const l = 14.0;
    for (final c in [
      [Offset.zero, const Offset(l, 0), const Offset(0, l)],
      [Offset(s.width, 0), Offset(s.width - l, 0), Offset(s.width, l)],
      [Offset(0, s.height), Offset(l, s.height), Offset(0, s.height - l)],
      [Offset(s.width, s.height), Offset(s.width - l, s.height), Offset(s.width, s.height - l)],
    ]) {
      canvas.drawLine(c[0], c[1], p);
      canvas.drawLine(c[0], c[2], p);
    }
  }

  @override
  bool shouldRepaint(covariant _BracketPainter old) => old.color != color;
}

/// Thin glowing bar used for XP and quest progress.
class SysBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  const SysBar({super.key, required this.value, this.color = SysColors.cyan, this.height = 6});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [SysColors.blue, color]),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 8)],
            ),
          ),
        ),
      );
}

/// Square checkbox with a glow, used in goal checklists.
class SysCheck extends StatelessWidget {
  final bool checked;
  final double size;
  const SysCheck({super.key, required this.checked, this.size = 20});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: checked ? SysColors.ok.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(color: checked ? SysColors.ok : SysColors.muted, width: 1.4),
          boxShadow: checked
              ? [BoxShadow(color: SysColors.ok.withValues(alpha: 0.6), blurRadius: 8)]
              : null,
        ),
        child: checked ? Icon(Icons.check, size: size - 5, color: SysColors.ok) : null,
      );
}

/// One stat cell: "STR  24".
class SysStat extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  const SysStat({super.key, required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: SysColors.cyanSoft),
        const SizedBox(width: 6),
        Text(label, style: SysText.label),
        const Spacer(),
        Text('$value', style: SysText.mono.copyWith(fontSize: 16)),
      ]);
}

/// Pop-up "system message" (e.g. quest complete, level up).
Future<void> showSystemMessage(BuildContext context,
    {required String tag, required String message, List<String> lines = const []}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'dismiss',
    barrierColor: const Color(0xAA000000),
    transitionDuration: const Duration(milliseconds: 260),
    transitionBuilder: (_, a, __, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(a), child: child),
    ),
    pageBuilder: (ctx, _, __) => Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Material(
          type: MaterialType.transparency,
          child: SysPanel(
            tag: tag,
            onTap: () => Navigator.pop(ctx),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(message, textAlign: TextAlign.center, style: SysText.body.copyWith(fontSize: 16)),
              for (final l in lines) ...[
                const SizedBox(height: 8),
                Text(l, textAlign: TextAlign.center, style: SysText.mono.copyWith(color: SysColors.gold)),
              ],
              const SizedBox(height: 14),
              Text('TAP TO CLOSE', style: SysText.label.copyWith(color: SysColors.muted)),
            ]),
          ),
        ),
      ),
    ),
  );
}

/// Hunter rank and title for a player level. Shared by the quest log and profile.
class SysRank {
  SysRank._();
  static String rank(int level) => level >= 50
      ? 'S'
      : level >= 35
          ? 'A'
          : level >= 20
              ? 'B'
              : level >= 10
                  ? 'C'
                  : level >= 5
                      ? 'D'
                      : 'E';

  static String title(int level) => level >= 20
      ? 'UNSTOPPABLE'
      : level >= 10
          ? 'IRON WILL'
          : level >= 5
              ? 'RISING HUNTER'
              : 'THE AWAKENED';
}
