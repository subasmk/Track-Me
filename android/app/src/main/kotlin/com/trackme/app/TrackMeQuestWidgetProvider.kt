package com.trackme.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
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

        fun updateQuestWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            widgetData: SharedPreferences
        ) {
            val binding = resolveBinding(context, appWidgetId, widgetData)
            val views = RemoteViews(context.packageName, R.layout.widget_quest)

            val quest = if (binding != QuestWidgetConfig.TODAY) {
                findQuest(widgetData.getString(KEY_ALL_JSON, null), binding)
            } else null

            if (quest != null) {
                renderSingleQuest(views, quest)
                views.setOnClickPendingIntent(
                    R.id.quest_widget_root,
                    launch(context, "trackme://quest?id=${Uri.encode(quest.optString("id"))}")
                )
            } else {
                renderToday(views, widgetData)
                views.setOnClickPendingIntent(R.id.quest_widget_root, launch(context, "trackme://quests"))
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        /** Which quest this instance shows. A widget that has never been
         * configured adopts a pin request made from the app in the last few
         * minutes (so "Add to Home Screen" on a quest really adds that
         * quest); otherwise it falls back to the today overview. */
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

        private fun renderToday(views: RemoteViews, widgetData: SharedPreferences) {
            val completed = widgetData.getInt(KEY_COMPLETED_COUNT, 0)
            val total = widgetData.getInt(KEY_TOTAL_COUNT, 0)
            val today = parse(widgetData.getString(KEY_TODAY_JSON, null))

            if (total == 0) {
                views.setTextViewText(R.id.quest_summary, "No quests today")
                views.setTextViewText(R.id.quest_title, "Tap to plan a quest")
                views.setTextViewText(R.id.quest_streak, "")
                views.setTextViewText(R.id.quest_difficulty, "")
                return
            }
            views.setTextViewText(R.id.quest_summary, "$completed / $total done today")
            val next = (0 until today.length()).map { today.getJSONObject(it) }
                .firstOrNull { !it.optBoolean("completedToday", false) }
            if (next == null) {
                views.setTextViewText(R.id.quest_title, "All quests complete!")
                views.setTextViewText(R.id.quest_streak, "")
                views.setTextViewText(R.id.quest_difficulty, "")
            } else {
                views.setTextViewText(R.id.quest_title, "${next.optString("emoji", "⚔️")} ${next.optString("title", "Quest")}")
                val streak = next.optInt("streak", 0)
                views.setTextViewText(R.id.quest_streak, if (streak > 0) "🔥 $streak day streak" else "")
                views.setTextViewText(R.id.quest_difficulty, next.optString("difficulty", ""))
            }
        }

        private fun renderSingleQuest(views: RemoteViews, quest: JSONObject) {
            val done = quest.optBoolean("completedToday", false)
            val count = quest.optInt("itemCount", 0)
            val itemsDone = quest.optInt("itemsDone", 0)
            views.setTextViewText(
                R.id.quest_summary,
                when {
                    done -> "Done today ✓"
                    !quest.optBoolean("scheduledToday", true) -> "Rest day"
                    count > 0 -> "$itemsDone / $count tasks"
                    else -> "Not done yet"
                }
            )
            views.setTextViewText(R.id.quest_title, "${quest.optString("emoji", "⚔️")} ${quest.optString("title", "Quest")}")
            val streak = quest.optInt("streak", 0)
            views.setTextViewText(R.id.quest_streak, if (streak > 0) "🔥 $streak day streak" else "")
            views.setTextViewText(R.id.quest_difficulty, quest.optString("difficulty", ""))
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
