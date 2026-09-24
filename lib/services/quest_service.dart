import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/quest.dart';
import '../models/quest_item.dart';
import '../services/hive_service.dart';
import '../services/home_widget_service.dart';
import '../utils/app_clock.dart';
import 'progression_service.dart';
import 'reminder_service.dart';

class QuestService extends ChangeNotifier {
  QuestService({Box<Quest>? box, this.progression}) : _box = box ?? HiveService.questsBox {
    // Reset yesterday's ticked sub-tasks once up front, then push the
    // current state to the home-screen widget. Without this initial sync a
    // freshly pinned quest widget showed "0 / 0" (or stale data) until the
    // user happened to edit or complete a quest.
    reconcileDay();
    unawaited(_sync());
  }

  final Box<Quest> _box;
  final ProgressionService? progression;
  static const _uuid = Uuid();

  /// Set when the most recent completion crossed into a new level, so the
  /// UI can celebrate. Read and clear with [takeLevelUp].
  bool _pendingLevelUp = false;
  bool takeLevelUp() {
    final v = _pendingLevelUp;
    _pendingLevelUp = false;
    return v;
  }

  /// Pure read: no Hive writes happen here any more. Daily resets are done
  /// explicitly by [reconcileDay] (startup, app resume, before mutations).
  List<Quest> get quests {
    final list = _box.values.toList();
    return list..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Clears sub-task ticks left over from a previous day. Returns true if
  /// anything changed.
  bool reconcileDay() {
    var changed = false;
    for (final q in _box.values) {
      if (checkAndResetDailyItems(q)) changed = true;
    }
    return changed;
  }

  /// Call when the app returns to the foreground: handles the day rolling
  /// over while the app was in the background and refreshes the widget.
  Future<void> refreshForNewDay() async {
    final changed = reconcileDay();
    if (changed) notifyListeners();
    await _sync();
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
    for (final q in _box.values) {
      if (q.id == id) return q;
    }
    return null;
  }

  /// Returns true if the quest's sub-tasks were reset (and saved).
  bool checkAndResetDailyItems(Quest quest) {
    final now = AppClock.now();
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
      unawaited(quest.save());
    }
    return needsSave;
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
    // Days may have changed: keep reminders on the right weekdays.
    if (quest.reminderTime != null) unawaited(ReminderService.schedule(quest));
    await _sync();
    notifyListeners();
  }

  Future<void> deleteQuest(String id) async {
    final quest = questById(id);
    if (quest != null) await ReminderService.cancel(quest);
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

    final now = AppClock.now();

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
    quest.completionHistory = [
      ...quest.completionHistory.where((d) => !AppClock.isSameDay(d, now)),
      now,
    ];

    if (progression != null) {
      _pendingLevelUp = await progression!.award(xp: quest.xp, gold: quest.gold);
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
    quest.lastItemToggleDate = AppClock.now();

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

  /// Adds focus-timer minutes to a quest.
  Future<void> logFocusMinutes(String questId, int minutes) async {
    final quest = questById(questId);
    if (quest == null || minutes <= 0) return;
    quest.focusMinutes += minutes;
    await quest.save();
    notifyListeners();
  }

  Future<void> setReminder(String questId, String? time) async {
    final quest = questById(questId);
    if (quest == null) return;
    quest.reminderTime = time;
    await quest.save();
    await ReminderService.schedule(quest);
    notifyListeners();
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

  /// After the live box was swapped to another account's quests.
  Future<void> reloadFromDisk() async {
    reconcileDay();
    notifyListeners();
    await _sync();
  }

  /// Exposed for screens that want to force a widget refresh (e.g. right
  /// before asking the launcher to pin a new widget).
  Future<bool> syncWidget() => HomeWidgetService.syncQuests(quests);
}
