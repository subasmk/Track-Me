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

  /// Display string matching the screenshot format: [15/15 3]
  String get progressLabel => '[$target/$target $sets]';
}
