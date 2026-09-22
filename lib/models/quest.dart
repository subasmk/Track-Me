import 'package:hive/hive.dart';
import 'quest_item.dart';

part 'quest.g.dart';

/// A Quest is a structured daily challenge with multiple goal items,
/// a time window, difficulty, type, XP/gold rewards, and a streak tracker.
/// Unlike Goals (which track a single habit), a Quest bundles several
/// sub-goals into one completable session (e.g., a Fitness workout).
@HiveType(typeId: 2)
class Quest extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String emoji;

  /// Category type: 'Fitness', 'Study', 'Mindfulness', 'Skill', 'Custom'
  @HiveField(3)
  String type;

  /// Difficulty: 'Easy', 'Medium', 'Hard'
  @HiveField(4)
  String difficulty;

  /// Optional start time in "HH:mm" format (e.g., "07:30")
  @HiveField(5)
  String? startTime;

  /// Optional end time in "HH:mm" format (e.g., "08:10")
  @HiveField(6)
  String? endTime;

  @HiveField(7)
  int streak;

  @HiveField(8)
  int longestStreak;

  /// Sub-goals that make up this quest (e.g., pushups, pull-ups, etc.)
  @HiveField(9)
  List<QuestItem> items;

  /// XP awarded on completion
  @HiveField(10)
  int xp;

  /// Gold awarded on completion
  @HiveField(11)
  int gold;

  /// Focus stat labels (e.g., "STR/AGI", "INT", "END")
  @HiveField(12)
  String focusStats;

  /// Last time this quest was completed (date only, time ignored)
  @HiveField(13)
  DateTime? lastCompleted;

  @HiveField(14)
  DateTime createdAt;

  /// Days of the week this quest repeats on (1 = Mon, 7 = Sun).
  @HiveField(15)
  List<int>? targetDays;

  /// Last date a sub-item was toggled
  @HiveField(16)
  DateTime? lastItemToggleDate;

  Quest({
    required this.id,
    required this.title,
    required this.emoji,
    this.type = 'Fitness',
    this.difficulty = 'Medium',
    this.startTime,
    this.endTime,
    this.streak = 0,
    this.longestStreak = 0,
    List<QuestItem>? items,
    this.xp = 100,
    this.gold = 50,
    this.focusStats = 'STR',
    this.lastCompleted,
    DateTime? createdAt,
    List<int>? targetDays,
    this.lastItemToggleDate,
  })  : items = items ?? <QuestItem>[],
        createdAt = createdAt ?? DateTime.now(),
        targetDays = targetDays ?? const [1, 2, 3, 4, 5, 6, 7];

  /// Days of the week this quest repeats on (1 = Mon, 7 = Sun).
  List<int> get days =>
      (targetDays == null || targetDays!.isEmpty) ? const [1, 2, 3, 4, 5, 6, 7] : targetDays!;

  /// True if scheduled on all 7 days of the week.
  bool get isAllDays => days.length >= 7;

  /// True if scheduled on a given weekday (1 = Mon, 7 = Sun).
  bool isScheduledForDay(int weekday) {
    if (targetDays == null || targetDays!.isEmpty) return true;
    return targetDays!.contains(weekday);
  }

  /// True if scheduled for today.
  bool get isScheduledForToday => isScheduledForDay(DateTime.now().weekday);

  /// Human-readable label for active days, e.g. "Everyday" or "Mon, Wed, Fri".
  String get daysLabel {
    if (isAllDays) return 'Everyday';
    const dayMap = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    final sorted = List<int>.from(days)..sort();
    return sorted.map((d) => dayMap[d] ?? '').where((s) => s.isNotEmpty).join(', ');
  }

  /// True if the quest was completed today.
  bool get isCompletedToday {
    if (lastCompleted == null) return false;
    final now = DateTime.now();
    return lastCompleted!.year == now.year &&
        lastCompleted!.month == now.month &&
        lastCompleted!.day == now.day;
  }

  /// Returns a human-readable time range string, e.g., "07:30 - 08:10".
  String? get timeRange {
    if (startTime == null && endTime == null) return null;
    final s = startTime ?? '';
    final e = endTime ?? '';
    if (s.isEmpty && e.isEmpty) return null;
    if (e.isEmpty) return s;
    if (s.isEmpty) return e;
    return '$s - $e';
  }

  /// XP computed from difficulty for display purposes.
  static int xpForDifficulty(String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return 75;
      case 'Hard':
        return 187;
      default:
        return 120;
    }
  }

  /// Gold computed from difficulty for display purposes.
  static int goldForDifficulty(String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return 30;
      case 'Hard':
        return 75;
      default:
        return 50;
    }
  }
}
