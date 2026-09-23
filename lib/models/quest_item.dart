import 'package:hive/hive.dart';

part 'quest_item.g.dart';

/// A single goal item within a Quest (e.g., "15 Pushups × 3 sets").
@HiveType(typeId: 3)
class QuestItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  /// The target count per set (e.g., 15 for 15 pushups).
  @HiveField(2)
  int target;

  /// Number of sets (e.g., 3).
  @HiveField(3)
  int sets;

  /// Optional unit label (e.g., "reps", "steps", "m").
  @HiveField(4)
  String unit;

  @HiveField(5)
  bool isDone;

  QuestItem({
    required this.id,
    required this.name,
    required this.target,
    this.sets = 1,
    this.unit = 'reps',
    this.isDone = false,
  });

  /// Human-readable target, e.g. "15 reps × 3" or "5 km".
  String get targetLabel {
    final base = '$target $unit'.trim();
    return sets > 1 ? '$base × $sets' : base;
  }

  /// Progress for today, e.g. "0/15 × 3" before and "15/15 × 3" after.
  /// (Previously always rendered as done: "[15/15 3]".)
  String get progressLabel {
    final done = isDone ? target : 0;
    return sets > 1 ? '$done/$target × $sets' : '$done/$target';
  }
}
