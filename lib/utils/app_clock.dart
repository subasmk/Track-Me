/// Single source of "now" for quest/day logic, so tests can move the clock
/// (e.g. across midnight) without waiting for real time to pass.
class AppClock {
  AppClock._();

  static DateTime Function() _now = DateTime.now;

  static DateTime now() => _now();

  /// Test hook: override the clock. Call [reset] in tearDown.
  static void set(DateTime Function() now) => _now = now;

  static void reset() => _now = DateTime.now;

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
