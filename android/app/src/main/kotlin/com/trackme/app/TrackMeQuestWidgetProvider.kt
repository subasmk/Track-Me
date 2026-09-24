package com.trackme.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject

/**
 * Quest home-screen widget. Each placed instance is either:
 * - bound to one quest (chosen in [QuestWidgetConfigureActivity], or
 *   automatically when pinned from a quest's "Add to Home Screen"), or
 * - the "today's quests" overview ([QuestWidgetConfig.TODAY]).
 *
 * Data flow: Flutter writes today's quests to `quests_json` and every quest
 * to `quest_all_json` (HomeWidgetService.syncQuests) on startup, resume and
 * every quest change, then asks Android to redraw.
 */
class TrackMeQuestWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            updateQuestWidget(context, appWidgetManager, appWidgetId, widgetData)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        val widgetData = es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
        updateQuestWidget(context, appWidgetManager, appWidgetId, widgetData)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) QuestWidgetConfig.clear(context, appWidgetId)
    }

    companion object {
        private const val KEY_TODAY_JSON = "quests_json"
        private const val KEY_ALL_JSON = "quest_all_json"
        private const val KEY_COMPLETED_COUNT = "quest_completed_today_count"
        private const val KEY_TOTAL_COUNT = "quest_total_count"
        private const val KEY_PENDING_PIN_ID = "quest_pending_pin_id"
        private const val KEY_PENDING_PIN_AT = "quest_pending_pin_at"
        private const val PENDING_PIN_TTL_MS = 5 * 60 * 1000L
        /** Width (dp) from which the 4x2 layout extras are shown. */
        private const val WIDE_WIDTH_DP = 220

        private fun hour() = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)

        /** Sloth mood for the widget, mirroring stickerFor() in the app. */
        internal fun mascotFor(progress: Int, allDone: Boolean, hour: Int, type: String?): Int = when {
            allDone -> R.drawable.sloth_cheering
            hour >= 22 || hour < 5 -> R.drawable.sloth_sleepy
            progress > 0 && type == "Fitness" -> R.drawable.sloth_fitness
            progress > 0 && type == "Mindfulness" -> R.drawable.sloth_calm
            progress > 0 -> R.drawable.sloth_focused
            hour >= 19 -> R.drawable.sloth_worried
            else -> R.drawable.sloth_ready
        }

        private fun setChip(views: RemoteViews, id: Int, text: String) {
            views.setTextViewText(id, text)
            if (text.isEmpty()) views.setViewVisibility(id, View.GONE)
        }

        fun updateQuestWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            widgetData: SharedPreferences
        ) {
            val binding = resolveBinding(context, appWidgetId, widgetData)
            val quest = if (binding != QuestWidgetConfig.TODAY) {
                findQuest(widgetData.getString(KEY_ALL_JSON, null), binding)
            } else null

            val views = if (binding != QuestWidgetConfig.TODAY && quest != null) {
                QuestSysWidget.render(
                    context, appWidgetManager, appWidgetId, quest, null,
                    "", "", QuestSysWidget.openUriFor(quest.optString("id"))
                )
            } else {
                // Today's quests: show the next open quest, or the day's result.
                val today = parse(widgetData.getString(KEY_TODAY_JSON, null))
                val list = (0 until today.length()).mapNotNull { today.optJSONObject(it) }
                val next = list.firstOrNull { !it.optBoolean("completedToday", false) }
                val completed = list.count { it.optBoolean("completedToday", false) }
                val label = if (list.isEmpty()) null else "$completed/${list.size} TODAY"
                QuestSysWidget.render(
                    context, appWidgetManager, appWidgetId,
                    next, label,
                    if (list.isEmpty()) "NO QUESTS TODAY" else "ALL QUESTS CLEAR",
                    if (list.isEmpty()) "Rest day. Tap to plan a quest." else "Every quest is done. Streaks are safe.",
                    if (next != null) QuestSysWidget.openUriFor(next.optString("id")) else "trackme://quests"
                )
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun resolveBinding(context: Context, appWidgetId: Int, widgetData: SharedPreferences): String {
            QuestWidgetConfig.get(context, appWidgetId)?.let { return it }
            val pendingId = widgetData.getString(KEY_PENDING_PIN_ID, null)
            val pendingAt = widgetData.getString(KEY_PENDING_PIN_AT, null)?.toLongOrNull() ?: 0L
            val fresh = System.currentTimeMillis() - pendingAt in 0..PENDING_PIN_TTL_MS
            val binding = if (!pendingId.isNullOrEmpty() && fresh) pendingId else QuestWidgetConfig.TODAY
            QuestWidgetConfig.set(context, appWidgetId, binding)
            if (!pendingId.isNullOrEmpty()) {
                widgetData.edit().remove(KEY_PENDING_PIN_ID).remove(KEY_PENDING_PIN_AT).apply()
            }
            return binding
        }

        private fun launch(context: Context, uri: String) =
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))

        internal fun parse(json: String?): JSONArray = try {
            if (json.isNullOrEmpty()) JSONArray() else JSONArray(json)
        } catch (e: Exception) {
            JSONArray()
        }

        private fun findQuest(json: String?, id: String): JSONObject? {
            val arr = parse(json)
            for (i in 0 until arr.length()) {
                val q = arr.optJSONObject(i) ?: continue
                if (q.optString("id") == id) return q
            }
            return null
        }
    }
}

/** Per-instance quest binding, separate from the shared widget data. */
object QuestWidgetConfig {
    const val TODAY = "__today__"
    private const val PREFS_NAME = "trackme_widget_quest_config"
    private fun key(appWidgetId: Int) = "widget_quest_$appWidgetId"
    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun get(context: Context, appWidgetId: Int): String? = prefs(context).getString(key(appWidgetId), null)
    fun set(context: Context, appWidgetId: Int, questId: String) {
        prefs(context).edit().putString(key(appWidgetId), questId).apply()
    }
    fun clear(context: Context, appWidgetId: Int) {
        prefs(context).edit().remove(key(appWidgetId)).apply()
    }
}
