import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Persisted XP / gold / level earned from quests. Previously XP and gold
/// were only display labels on each quest and were never accumulated.
class ProgressionService extends ChangeNotifier {
  ProgressionService(this._box);

  final Box _box;
  static const _kXp = 'progress_total_xp';
  static const _kGold = 'progress_total_gold';

  /// After the settings box was swapped to another account's data.
  void reload() => notifyListeners();

  int get totalXp => (_box.get(_kXp) as int?) ?? 0;
  int get gold => (_box.get(_kGold) as int?) ?? 0;

  /// XP needed to go from [level] to [level] + 1.
  static int xpForLevel(int level) => 200 + (level - 1) * 100;

  int get level => levelFor(totalXp).level;
  int get xpIntoLevel => levelFor(totalXp).into;
  int get xpForNextLevel => xpForLevel(level);
  double get levelProgress => xpIntoLevel / xpForNextLevel;

  static ({int level, int into}) levelFor(int xp) {
    var level = 1;
    var remaining = xp;
    while (remaining >= xpForLevel(level)) {
      remaining -= xpForLevel(level);
      level++;
    }
    return (level: level, into: remaining);
  }

  /// Adds a reward; returns true if this crossed into a new level.
  Future<bool> award({required int xp, required int gold}) async {
    final before = level;
    await _box.put(_kXp, totalXp + xp);
    await _box.put(_kGold, this.gold + gold);
    notifyListeners();
    return level > before;
  }
}
