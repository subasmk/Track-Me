package com.trackme.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject

/**
 * Renders one goal's streak as a home-screen widget. Each placed instance
 * is bound to a single goal id (chosen once via [WidgetConfigureActivity]
 * when the widget is added), so a user can place several of these — one
 * per goal — exactly like separate Duolingo streak widgets.
 *
 * Data flow:
 * - Flutter writes the full goal list as JSON into the shared HomeWidget
 *   SharedPreferences after every add/edit/delete/complete
 *   (see lib/services/home_widget_service.dart, key [KEY_GOALS_JSON]).
 * - This provider looks up *its own* configured goal id out of that array
 *   and renders just that one goal.
 * - Resizing between the mockup's "Small" and "Medium" sizes is handled by
 *   toggling view visibility based on the measured width in
 *   [onAppWidgetOptionsChanged], rather than swapping layout files.
 */
class TrackMeGoalWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId, widgetData)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle
    ) {
        // The user is resizing this widget instance between "Small" and
        // "Medium" — re-render immediately so the extra content (title,
        // week strip) appears/disappears live as they drag, rather than
        // waiting for the next data change.
        val widgetData = es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
        updateAppWidget(context, appWidgetManager, appWidgetId, widgetData)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        // Forget which goal each removed widget instance was tracking, so
        // WidgetConfig doesn't accumulate stale entries for widgets that no
        // longer exist.
        for (appWidgetId in appWidgetIds) {
            WidgetConfig.clearGoalId(context, appWidgetId)
        }
    }

    companion object {
        private const val KEY_GOALS_JSON = "goals_json"

        /** Width, in dp, above which the "Medium" content (title + week
         * strip) is shown instead of the compact "Small" view. */
        private const val MEDIUM_WIDTH_THRESHOLD_DP = 110

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            widgetData: SharedPreferences
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_goal)
            val goalId = WidgetConfig.getGoalId(context, appWidgetId)
            val goal = goalId?.let { findGoal(widgetData, it) }

            if (goalId == null || goal == null) {
                showEmptyState(context, views)
                appWidgetManager.updateAppWidget(appWidgetId, views)
                return
            }

            views.setViewVisibility(R.id.content_container, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.empty_state, android.view.View.GONE)

            views.setInt(
                R.id.widget_root,
                "setBackgroundResource",
                themeDrawableFor(goal.optString("theme", "purple"))
            )

            val streak = goal.optInt("streak", 0)
            val unit = if (streak == 1) "day" else "days"
            val completedToday = goal.optBoolean("completedToday", false)
            val hour = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)
            val mood = mascotStateFor(completedToday, streak, hour)

            views.setTextViewText(R.id.streak_number, "$streak $unit")
            views.setTextViewText(R.id.goal_title, goal.optString("title", "Goal"))
            views.setTextViewText(R.id.subtitle_text, subtitleFor(context, mood, streak, hour))
            views.setImageViewResource(R.id.sloth_image, mascotDrawableFor(mood))

            // Reveal the title + week strip only once the widget has been
            // resized wide enough to comfortably fit them.
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidthDp = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0
            val isMedium = minWidthDp >= MEDIUM_WIDTH_THRESHOLD_DP
            views.setViewVisibility(
                R.id.goal_title,
                if (isMedium) android.view.View.VISIBLE else android.view.View.GONE
            )
            views.setViewVisibility(
                R.id.week_row,
                if (isMedium) android.view.View.VISIBLE else android.view.View.GONE
            )

            if (isMedium) {
                applyWeekRow(views, goal.optJSONArray("week"))
            }

            val uri = Uri.parse("trackme://goal?id=$goalId")
            val pendingIntent =
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri)
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun showEmptyState(context: Context, views: RemoteViews) {
            views.setViewVisibility(R.id.content_container, android.view.View.GONE)
            views.setViewVisibility(R.id.empty_state, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.goal_title, android.view.View.GONE)
            views.setViewVisibility(R.id.week_row, android.view.View.GONE)
            // No goal bound (or it was deleted) — just open the app. Uses a
            // non-"goal" host so main.dart's widget-tap handler no-ops on
            // navigation and simply lands on the home screen.
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context, MainActivity::class.java, Uri.parse("trackme://open")
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
        }

        private val dayCircleIds = intArrayOf(
            R.id.day_0_circle, R.id.day_1_circle, R.id.day_2_circle,
            R.id.day_3_circle, R.id.day_4_circle, R.id.day_5_circle, R.id.day_6_circle
        )

        /** Maps a goal's `theme` id (set in the Add Goal screen, one of the
         * curated WidgetThemes in lib/theme/widget_themes.dart) to its
         * matching pre-built gradient drawable. Falls back to purple for
         * any goal saved before this feature existed (its JSON simply won't
         * have a "theme" field) or an unrecognized id. */
        private fun themeDrawableFor(themeId: String?): Int = GoalThemeColors.drawableFor(themeId)

        /** The three moods this widget's mascot (and its message) can be
         * in — mirrors how Duolingo's own mascot expression shifts with
         * its nudge text rather than staying static. */
        private enum class MascotState { HAPPY, PLAYFUL, SLEEPY, WORRIED, NEUTRAL }

        private fun mascotStateFor(completedToday: Boolean, streak: Int, hour: Int): MascotState {
            if (completedToday) return MascotState.HAPPY
            if (hour >= 22 || hour < 6) return MascotState.SLEEPY
            if (streak > 3) return MascotState.PLAYFUL
            return if (hour >= 18) MascotState.WORRIED else MascotState.NEUTRAL
        }

        private fun subtitleFor(context: Context, state: MascotState, streak: Int, hour: Int): String =
            when (state) {
                MascotState.HAPPY -> context.getString(R.string.widget_nice_work)
                MascotState.PLAYFUL -> "Streak on fire! 🔥"
                MascotState.SLEEPY -> "Rest up & stay consistent 💤"
                MascotState.WORRIED ->
                    if (hour >= 21) context.getString(R.string.widget_dont_lose_streak)
                    else context.getString(R.string.widget_getting_late)
                MascotState.NEUTRAL ->
                    if (streak == 0) context.getString(R.string.widget_start_streak)
                    else context.getString(R.string.widget_keep_it_up)
            }

        private fun mascotDrawableFor(state: MascotState): Int = when (state) {
            MascotState.HAPPY -> R.drawable.sloth_happy
            MascotState.PLAYFUL -> R.drawable.sloth_playful
            MascotState.SLEEPY -> R.drawable.sloth_sleepy
            MascotState.WORRIED -> R.drawable.sloth_worried
            MascotState.NEUTRAL -> R.drawable.sloth_playful
        }

        /** Colors + dims each of the 7 day-circles as done / today / pending.
         * The flame emoji itself is static (in widget_goal.xml); only its
         * background "slot" and opacity change here — bright and solid
         * for done, medium on an outlined ring for today, faint for
         * pending — mirroring a lit-vs-unlit flame rather than a checkmark.
         * [week] is the Sunday-first array of 7 booleans Flutter serialized. */
        private fun applyWeekRow(views: RemoteViews, week: JSONArray?) {
            val todayIndex = java.util.Calendar.getInstance()
                .get(java.util.Calendar.DAY_OF_WEEK) - 1 // Calendar.SUNDAY == 1 -> 0-indexed

            for (i in 0 until 7) {
                val done = week?.optBoolean(i, false) ?: false
                val isToday = i == todayIndex
                val drawable = when {
                    done -> R.drawable.bg_day_pill_done
                    isToday -> R.drawable.bg_day_pill_today
                    else -> R.drawable.bg_day_pill_pending
                }
                val alpha = when {
                    done -> 1.0f
                    isToday -> 0.6f
                    else -> 0.25f
                }
                views.setInt(dayCircleIds[i], "setBackgroundResource", drawable)
                views.setFloat(dayCircleIds[i], "setAlpha", alpha)
            }
        }

        private fun findGoal(widgetData: SharedPreferences, goalId: String): JSONObject? {
            val raw = widgetData.getString(KEY_GOALS_JSON, null)
            if (raw.isNullOrEmpty()) {
                return JSONObject().apply {
                    put("id", "default")
                    put("title", "Daily Habit")
                    put("emoji", "🎯")
                    put("streak", 1)
                    put("completedToday", false)
                }
            }
            return try {
                val array = JSONArray(raw)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    if (obj.optString("id") == goalId) return obj
                }
                if (array.length() > 0) array.getJSONObject(0) else JSONObject().apply {
                    put("id", "default")
                    put("title", "Daily Habit")
                    put("emoji", "🎯")
                    put("streak", 1)
                    put("completedToday", false)
                }
            } catch (e: Exception) {
                JSONObject().apply {
                    put("id", "default")
                    put("title", "Daily Habit")
                    put("emoji", "🎯")
                    put("streak", 1)
                    put("completedToday", false)
                }
            }
        }
    }
}

/**
 * Persists which goal each individual widget instance is bound to. This is
 * separate from the shared HomeWidget data (which holds all goals) because
 * it's per-widget-instance, not per-app-install — two TrackMeGoalWidgetProvider
 * placements on the same home screen track two different goals.
 */
object WidgetConfig {
    private const val PREFS_NAME = "trackme_widget_goal_config"
    private fun key(appWidgetId: Int) = "widget_goal_$appWidgetId"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun getGoalId(context: Context, appWidgetId: Int): String? =
        prefs(context).getString(key(appWidgetId), null)

    fun setGoalId(context: Context, appWidgetId: Int, goalId: String) {
        prefs(context).edit().putString(key(appWidgetId), goalId).apply()
    }

    fun clearGoalId(context: Context, appWidgetId: Int) {
        prefs(context).edit().remove(key(appWidgetId)).apply()
    }
}

/**
 * Maps a goal's `theme` id — one of the curated WidgetThemes defined in
 * lib/theme/widget_themes.dart ('purple', 'mint', 'flame', 'sky', 'berry',
 * 'coral', 'gold') — to its Android-side gradient drawable or "mid" color
 * resource. Shared by [TrackMeGoalWidgetProvider] (the widget itself) and
 * [WidgetConfigureActivity] (the goal-picker row previews) so both always
 * agree on what each theme id looks like.
 */
object GoalThemeColors {
    fun drawableFor(themeId: String?): Int = when (themeId) {
        "mint" -> R.drawable.bg_widget_theme_mint
        "flame" -> R.drawable.bg_widget_theme_flame
        "sky" -> R.drawable.bg_widget_theme_sky
        "berry" -> R.drawable.bg_widget_theme_berry
        "coral" -> R.drawable.bg_widget_theme_coral
        "gold" -> R.drawable.bg_widget_theme_gold
        // Reuses the pre-existing drawable (also the layouts' own static
        // XML background) rather than a separate near-duplicate file.
        else -> R.drawable.bg_widget_purple_gradient
    }

    fun midColorRes(themeId: String?): Int = when (themeId) {
        "mint" -> R.color.theme_mint_mid
        "flame" -> R.color.theme_flame_mid
        "sky" -> R.color.theme_sky_mid
        "berry" -> R.color.theme_berry_mid
        "coral" -> R.color.theme_coral_mid
        "gold" -> R.color.theme_gold_mid
        else -> R.color.purple
    }
}
