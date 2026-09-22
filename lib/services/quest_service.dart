import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/quest.dart';
import '../models/quest_item.dart';
import '../services/hive_service.dart';
import '../services/home_widget_service.dart';

class QuestService extends ChangeNotifier {
  final Box<Quest> _box = HiveService.questsBox;
  static const _uuid = Uuid();

  List<Quest> get quests {
    final list = _box.values.toList();
    for (final q in list) {
      checkAndResetDailyItems(q);
    }
    return list..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Quests that are scheduled for today and not completed today.
  List<Quest> get activeQuestsToday =>
      quests.where((q) => q.isScheduledForToday && !q.isCompletedToday).toList();

  /// Quests that are scheduled for today and completed today.
  List<Quest> get completedQuestsToday =>
      quests.where((q) => q.isScheduledForToday && q.isCompletedToday).toList();

  /// Quests scheduled for days other than today.
  List<Quest> get otherDaysQuests =>
      quests.where((q) => !q.isScheduledForToday).toList();

  int get completedTodayCount =>
      quests.where((q) => q.isScheduledForToday && q.isCompletedToday).length;

  int get totalTodayCount =>
      quests.where((q) => q.isScheduledForToday).length;

  int get totalQuestsCount => quests.length;

  Quest? questById(String id) {
    try {
      final q = _box.values.firstWhere((q) => q.id == id);
      checkAndResetDailyItems(q);
      return q;
    } catch (_) {
      return null;
    }
  }

  void checkAndResetDailyItems(Quest quest) {
    final now = DateTime.now();
    bool needsSave = false;

    if (!quest.isCompletedToday) {
      if (quest.lastItemToggleDate != null) {
        final lastToggle = quest.lastItemToggleDate!;
        if (lastToggle.year != now.year ||
            lastToggle.month != now.month ||
            lastToggle.day != now.day) {
          for (final item in quest.items) {
            if (item.isDone) {
              item.isDone = false;
              needsSave = true;
            }
          }
        }
      } else if (quest.lastCompleted != null) {
        final lc = quest.lastCompleted!;
        if (lc.year != now.year || lc.month != now.month || lc.day != now.day) {
          for (final item in quest.items) {
            if (item.isDone) {
              item.isDone = false;
              needsSave = true;
            }
          }
        }
      }
    }

    if (needsSave) {
      quest.save();
    }
  }

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  Future<Quest> addQuest({
    required String title,
    required String emoji,
    required String type,
    required String difficulty,
    String? startTime,
    String? endTime,
    List<QuestItem>? items,
    String? focusStats,
    List<int>? targetDays,
  }) async {
    final quest = Quest(
      id: _uuid.v4(),
      title: title,
      emoji: emoji,
      type: type,
      difficulty: difficulty,
      startTime: startTime,
      endTime: endTime,
      items: items ?? [],
      xp: Quest.xpForDifficulty(difficulty),
      gold: Quest.goldForDifficulty(difficulty),
      focusStats: focusStats ?? _defaultFocusStats(type),
      targetDays: targetDays,
    );
    await _box.put(quest.id, quest);
    await _sync();
    notifyListeners();
    return quest;
  }

  Future<void> updateQuest(Quest quest) async {
    await quest.save();
    await _sync();
    notifyListeners();
  }

  Future<void> deleteQuest(String id) async {
    await _box.delete(id);
    await _sync();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Completion
  // ---------------------------------------------------------------------------

  Future<void> completeToday(String questId) async {
    final quest = questById(questId);
    if (quest == null || quest.isCompletedToday) return;

    final now = DateTime.now();

    // Streak logic: if last completed was yesterday, continue streak
    final isConsecutive = quest.lastCompleted != null &&
        _isYesterday(quest.lastCompleted!, now);

    quest.streak = isConsecutive ? quest.streak + 1 : 1;
    if (quest.streak > quest.longestStreak) {
      quest.longestStreak = quest.streak;
    }
    quest.lastCompleted = now;
    quest.lastItemToggleDate = now;
    for (final item in quest.items) {
      item.isDone = true;
    }

    await quest.save();
    await _sync();
    notifyListeners();
  }

  Future<void> toggleQuestItem(String questId, String itemId) async {
    final quest = questById(questId);
    if (quest == null) return;

    checkAndResetDailyItems(quest);

    final index = quest.items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;

    quest.items[index].isDone = !quest.items[index].isDone;
    quest.lastItemToggleDate = DateTime.now();

    // If all sub-tasks are done, auto-complete the quest today
    final allDone = quest.items.isNotEmpty && quest.items.every((i) => i.isDone);
    if (allDone && !quest.isCompletedToday) {
      await completeToday(questId);
    } else {
      await quest.save();
      await _sync();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  bool _isYesterday(DateTime date, DateTime reference) {
    final yesterday = DateTime(reference.year, reference.month, reference.day)
        .subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  String _defaultFocusStats(String type) {
    switch (type) {
      case 'Fitness':
        return 'STR/AGI';
      case 'Study':
        return 'INT';
      case 'Mindfulness':
        return 'WIS';
      case 'Skill':
        return 'DEX';
      default:
        return 'ALL';
    }
  }

  Future<void> _sync() async {
    await HomeWidgetService.syncQuests(quests);
  }
}
