import 'dart:convert';
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

  /// Serializes quest data for the quest home-screen widget.
  static Future<void> syncQuests(List<Quest> quests) async {
    try {
      final payload = quests
          .map((q) => {
                'id': q.id,
                'title': q.title,
                'emoji': q.emoji,
                'streak': q.streak,
                'longestStreak': q.longestStreak,
                'completedToday': q.isCompletedToday,
                'type': q.type,
                'difficulty': q.difficulty,
                'xp': q.xp,
                'gold': q.gold,
                'itemCount': q.items.length,
              })
          .toList();

      final completedToday = quests.where((q) => q.isCompletedToday).length;

      await Future.wait([
        HomeWidget.saveWidgetData<String>(keyQuestsJson, jsonEncode(payload)),
        HomeWidget.saveWidgetData<int>(keyQuestCompletedCount, completedToday),
        HomeWidget.saveWidgetData<int>(keyQuestTotalCount, quests.length),
      ]);

      await HomeWidget.updateWidget(androidName: androidQuestWidgetProvider);
    } catch (e) {
      // Safe to ignore.
    }
  }

  /// Requests pinning the Quest widget to the device's home screen.
  static Future<void> pinQuestWidget(Quest quest) async {
    try {
      await HomeWidget.requestPinWidget(
        androidName: androidQuestWidgetProvider,
      );
    } catch (_) {}
  }
}
