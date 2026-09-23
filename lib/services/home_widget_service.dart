import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../models/goal.dart';
import '../models/quest.dart';
import '../utils/date_utils_x.dart';

/// Pushes goal and quest data into Android SharedPreferences (via the
/// `home_widget` plugin) so the native AppWidgetProviders can render it,
/// then asks Android to redraw the widgets.
///
/// Widget types that read this data:
/// - `TrackMeGoalWidgetProvider` — one goal per widget instance
/// - `TrackMeOverviewWidgetProvider` — top goals overview
/// - `TrackMeQuestWidgetProvider` — active quest summary
class HomeWidgetService {
  HomeWidgetService._();

  static const String androidGoalWidgetProvider = 'TrackMeGoalWidgetProvider';
  static const String androidOverviewWidgetProvider = 'TrackMeOverviewWidgetProvider';
  static const String androidQuestWidgetProvider = 'TrackMeQuestWidgetProvider';

  static const String keyGoalsJson = 'goals_json';
  static const String keyUserName = 'user_name';
  static const String keyCompletedTodayCount = 'completed_today_count';
  static const String keyTotalGoalsCount = 'total_goals_count';
  static const String keyQuestsJson = 'quests_json';
  static const String keyQuestCompletedCount = 'quest_completed_today_count';
  static const String keyQuestTotalCount = 'quest_total_count';

  /// Serializes every goal into a compact JSON blob the native side can
  /// parse without needing Hive, then triggers a redraw of both goal widget
  /// types. Safe to call often — failures (e.g. no widget placed yet) are
  /// swallowed since they're not user-facing errors.
  static Future<void> syncGoals(List<Goal> goals, {String userName = 'Learner'}) async {
    try {
      final today = DateTime.now();
      final week = DateUtilsX.weekDates(today);

      final payload = goals
          .map((g) => {
                'id': g.id,
                'title': g.title,
                'emoji': g.emoji,
                'streak': g.streak,
                'longestStreak': g.longestStreak,
                'dailyMinutes': g.dailyMinutes,
                'completedToday': g.isCompletedToday,
                'theme': g.themeId,
                'week': week
                    .map((d) => g.notes.any((n) => DateUtilsX.isSameDay(n.date, d)))
                    .toList(),
              })
          .toList();

      final completedToday = goals.where((g) => g.isCompletedToday).length;

      await Future.wait([
        HomeWidget.saveWidgetData<String>(keyGoalsJson, jsonEncode(payload)),
        HomeWidget.saveWidgetData<String>(keyUserName, userName),
        HomeWidget.saveWidgetData<int>(keyCompletedTodayCount, completedToday),
        HomeWidget.saveWidgetData<int>(keyTotalGoalsCount, goals.length),
      ]);

      await Future.wait([
        HomeWidget.updateWidget(androidName: androidGoalWidgetProvider),
        HomeWidget.updateWidget(androidName: androidOverviewWidgetProvider),
      ]);
    } catch (e) {
      // No home screen widget has been added yet, or the platform channel
      // isn't available (e.g. running in a test) — safe to ignore.
    }
  }

  static const String keyQuestAllJson = 'quest_all_json';
  static const String keyQuestBestStreak = 'quest_best_streak';
  static const String keyQuestPendingPinId = 'quest_pending_pin_id';
  static const String keyQuestPendingPinAt = 'quest_pending_pin_at';
  static const String keyQuestSyncedAt = 'quest_synced_at';

  /// Builds the quest widget payload. Pure so it can be unit tested.
  ///
  /// Only quests scheduled for today are counted, matching the Quests
  /// screen (previously every quest was counted, so "today" totals on the
  /// widget disagreed with the app). Open quests come first, ordered by
  /// start time, so the widget's headline is the next thing to do.
  static Map<String, dynamic> buildQuestWidgetData(List<Quest> quests) {
    final today = quests.where((q) => q.isScheduledForToday).toList()
      ..sort((a, b) {
        if (a.isCompletedToday != b.isCompletedToday) {
          return a.isCompletedToday ? 1 : -1;
        }
        final at = a.startTime ?? '99:99';
        final bt = b.startTime ?? '99:99';
        final byTime = at.compareTo(bt);
        if (byTime != 0) return byTime;
        return a.createdAt.compareTo(b.createdAt);
      });

    Map<String, dynamic> encode(Quest q) => {
          'id': q.id,
          'title': q.title,
          'emoji': q.emoji,
          'streak': q.streak,
          'longestStreak': q.longestStreak,
          'completedToday': q.isCompletedToday,
          'scheduledToday': q.isScheduledForToday,
          'type': q.type,
          'difficulty': q.difficulty,
          'xp': q.xp,
          'gold': q.gold,
          'itemCount': q.items.length,
          'itemsDone': q.doneItemCount,
          'progress': (q.todayProgress * 100).round(),
          'nextTask': q.nextItem?.name ?? '',
          'timeRange': q.timeRange ?? '',
          'days': q.daysLabel,
        };

    final bestStreak = quests.fold<int>(0, (m, q) => q.streak > m ? q.streak : m);

    return {
      'today': today.map(encode).toList(),
      'all': quests.map(encode).toList(),
      'completed': today.where((q) => q.isCompletedToday).length,
      'total': today.length,
      'bestStreak': bestStreak,
    };
  }

  /// Serializes quest data for the quest home-screen widget and redraws
  /// every placed quest widget. Returns false if the platform call failed
  /// (logged, not thrown: widget refresh must never break the app).
  static Future<bool> syncQuests(List<Quest> quests) async {
    final data = buildQuestWidgetData(quests);
    try {
      await Future.wait([
        HomeWidget.saveWidgetData<String>(keyQuestsJson, jsonEncode(data['today'])),
        HomeWidget.saveWidgetData<String>(keyQuestAllJson, jsonEncode(data['all'])),
        HomeWidget.saveWidgetData<int>(keyQuestCompletedCount, data['completed'] as int),
        HomeWidget.saveWidgetData<int>(keyQuestTotalCount, data['total'] as int),
        HomeWidget.saveWidgetData<int>(keyQuestBestStreak, data['bestStreak'] as int),
        HomeWidget.saveWidgetData<String>(
            keyQuestSyncedAt, DateTime.now().toIso8601String()),
      ]);
      await HomeWidget.updateWidget(androidName: androidQuestWidgetProvider);
      return true;
    } catch (e) {
      debugPrint('HomeWidgetService.syncQuests failed: $e');
      return false;
    }
  }

  /// Asks the launcher to pin a quest widget bound to [quest] (or the
  /// "today's quests" overview when [quest] is null).
  ///
  /// The native side binds the next newly placed quest widget to the id
  /// stored here (valid for a few minutes), so "Add to Home Screen" on a
  /// quest now really adds *that* quest. Returns what actually happened so
  /// the UI no longer claims success when pinning is unsupported or fails.
  static Future<PinWidgetResult> pinQuestWidget(Quest? quest) async {
    try {
      final supported = await HomeWidget.isRequestPinWidgetSupported();
      if (supported != true) return PinWidgetResult.unsupported;

      await Future.wait([
        HomeWidget.saveWidgetData<String>(keyQuestPendingPinId, quest?.id ?? '__today__'),
        HomeWidget.saveWidgetData<String>(
            keyQuestPendingPinAt, DateTime.now().millisecondsSinceEpoch.toString()),
      ]);
      await HomeWidget.requestPinWidget(androidName: androidQuestWidgetProvider);
      return PinWidgetResult.requested;
    } catch (e) {
      debugPrint('HomeWidgetService.pinQuestWidget failed: $e');
      return PinWidgetResult.failed;
    }
  }
}

enum PinWidgetResult { requested, unsupported, failed }
