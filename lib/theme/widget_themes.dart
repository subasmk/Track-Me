import 'package:flutter/material.dart';
import 'app_colors.dart';

/// One selectable color theme for a goal. The three stops mirror what's
/// needed on both sides of the app: [light]→[dark] make a Flutter
/// [LinearGradient], and the same three hex values are duplicated as
/// Android color resources (see android colors.xml, `theme_<id>_light/
/// mid/dark`) so a goal's widget matches its in-app card exactly.
class WidgetTheme {
  final String id;
  final String label;
  final Color light;
  final Color mid;
  final Color dark;

  const WidgetTheme({
    required this.id,
    required this.label,
    required this.light,
    required this.mid,
    required this.dark,
  });

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [light, mid, dark],
      );
}

/// The curated palette a goal can be assigned to — deliberately a small,
/// hand-picked set (like Duolingo's own course colors) rather than an
/// open-ended color wheel, so every combination still looks intentional.
class WidgetThemes {
  WidgetThemes._();

  // Reuses AppColors' existing purple ramp directly (rather than
  // duplicating its hex values here) so a goal left on the default
  // "Purple" theme matches the app's own signature purple — e.g. the home
  // screen's overall streak card — exactly, with no drift possible between
  // the two.
  static const purple = WidgetTheme(
    id: 'purple',
    label: 'Purple',
    light: AppColors.purpleLight,
    mid: AppColors.purpleMid,
    dark: AppColors.purpleDeep,
  );

  static const mint = WidgetTheme(
    id: 'mint',
    label: 'Mint',
    light: Color(0xFF6EE7B7),
    mid: Color(0xFF10B981),
    dark: Color(0xFF047857),
  );

  static const flame = WidgetTheme(
    id: 'flame',
    label: 'Flame',
    light: Color(0xFFFFB74D),
    mid: Color(0xFFFF9500),
    dark: Color(0xFFC2410C),
  );

  static const sky = WidgetTheme(
    id: 'sky',
    label: 'Sky',
    light: Color(0xFF7DD3FC),
    mid: Color(0xFF0EA5E9),
    dark: Color(0xFF0369A1),
  );

  static const berry = WidgetTheme(
    id: 'berry',
    label: 'Berry',
    light: Color(0xFFF9A8D4),
    mid: Color(0xFFEC4899),
    dark: Color(0xFF9D174D),
  );

  static const coral = WidgetTheme(
    id: 'coral',
    label: 'Coral',
    light: Color(0xFFFCA5A5),
    mid: Color(0xFFEF4444),
    dark: Color(0xFF991B1B),
  );

  static const gold = WidgetTheme(
    id: 'gold',
    label: 'Gold',
    light: Color(0xFFFDE68A),
    mid: Color(0xFFF59E0B),
    dark: Color(0xFFB45309),
  );

  static const sunset = WidgetTheme(
    id: 'sunset',
    label: 'Sunset',
    light: Color(0xFFFFB88C),
    mid: Color(0xFFFF6A88),
    dark: Color(0xFFB33771),
  );

  static const ocean = WidgetTheme(
    id: 'ocean',
    label: 'Ocean',
    light: Color(0xFF1BFFFF),
    mid: Color(0xFF2E86DE),
    dark: Color(0xFF2E3192),
  );

  static const aurora = WidgetTheme(
    id: 'aurora',
    label: 'Aurora',
    light: Color(0xFF00F5A0),
    mid: Color(0xFF00C9A7),
    dark: Color(0xFF845EC2),
  );

  static const grape = WidgetTheme(
    id: 'grape',
    label: 'Grape',
    light: Color(0xFFC471F5),
    mid: Color(0xFF8E2DE2),
    dark: Color(0xFF4A00E0),
  );

  static const rose = WidgetTheme(
    id: 'rose',
    label: 'Rose',
    light: Color(0xFFFF9A9E),
    mid: Color(0xFFF857A6),
    dark: Color(0xFFC2185B),
  );

  static const lime = WidgetTheme(
    id: 'lime',
    label: 'Lime',
    light: Color(0xFFD4FC79),
    mid: Color(0xFF89E219),
    dark: Color(0xFF3C9A00),
  );

  static const midnight = WidgetTheme(
    id: 'midnight',
    label: 'Midnight',
    light: Color(0xFF4B6CB7),
    mid: Color(0xFF243B55),
    dark: Color(0xFF141E30),
  );

  static const peach = WidgetTheme(
    id: 'peach',
    label: 'Peach',
    light: Color(0xFFFFE29F),
    mid: Color(0xFFFFA99F),
    dark: Color(0xFFFF719A),
  );

  static const List<WidgetTheme> all = [
    purple,
    mint,
    flame,
    sky,
    berry,
    coral,
    gold,
    sunset,
    ocean,
    aurora,
    grape,
    rose,
    lime,
    midnight,
    peach,
  ];

  static WidgetTheme byId(String? id) =>
      all.firstWhere((t) => t.id == id, orElse: () => purple);
}
