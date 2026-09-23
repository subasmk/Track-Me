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
            val views = RemoteViews(context.packageName, R.layout.widget_quest)

            val quest = if (binding != QuestWidgetConfig.TODAY) {
                findQuest(widgetData.getString(KEY_ALL_JSON, null), binding)
            } else null

            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val widthDp = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0
            val wide = widthDp >= WIDE_WIDTH_DP
            views.setViewVisibility(R.id.quest_next, if (wide) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.quest_difficulty, if (wide) View.VISIBLE else View.GONE)

            // setChip may hide empty chips; show them again before rendering.
            views.setViewVisibility(R.id.quest_streak, View.VISIBLE)
            if (!wide) views.setViewVisibility(R.id.quest_difficulty, View.GONE)
            else views.setViewVisibility(R.id.quest_difficulty, View.VISIBLE)

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
            views.setTextViewText(R.id.quest_header, "⚔️  TODAY'S QUESTS")
            views.setInt(R.id.quest_widget_root, "setBackgroundResource", R.drawable.bg_widget_quest)

            if (total == 0) {
                views.setTextViewText(R.id.quest_summary, "Rest day")
                views.setProgressBar(R.id.quest_progress, 100, 0, false)
                views.setTextViewText(R.id.quest_title, "No quests today. Tap to plan one.")
                views.setTextViewText(R.id.quest_next, "")
                setChip(views, R.id.quest_streak, "")
                setChip(views, R.id.quest_difficulty, "")
                views.setImageViewResource(R.id.quest_mascot, if (hour() >= 22 || hour() < 5) R.drawable.sloth_sleepy else R.drawable.sloth_calm)
                return
            }
            val percent = completed * 100 / total
            val allDone = completed >= total
            views.setTextViewText(R.id.quest_summary, "$completed / $total")
            views.setProgressBar(R.id.quest_progress, 100, percent, false)
            val next = (0 until today.length()).map { today.getJSONObject(it) }
                .firstOrNull { !it.optBoolean("completedToday", false) }
            val best = widgetData.getInt("quest_best_streak", 0)
            if (next == null || allDone) {
                views.setInt(R.id.quest_widget_root, "setBackgroundResource", R.drawable.bg_widget_quest_done)
                views.setTextViewText(R.id.quest_title, "All quests done! 🎉")
                views.setTextViewText(R.id.quest_next, "Streaks are safe for today")
                setChip(views, R.id.quest_streak, if (best > 0) "🔥 $best best" else "")
                setChip(views, R.id.quest_difficulty, "")
                views.setImageViewResource(R.id.quest_mascot, R.drawable.sloth_cheering)
            } else {
                val time = next.optString("timeRange", "")
                views.setTextViewText(R.id.quest_title, "${next.optString("emoji", "⚔️")} ${next.optString("title", "Quest")}")
                val task = next.optString("nextTask", "")
                views.setTextViewText(R.id.quest_next, listOf(if (task.isNotEmpty()) "Next: $task" else "", time).filter { it.isNotEmpty() }.joinToString("  ·  "))
                val streak = next.optInt("streak", 0)
                setChip(views, R.id.quest_streak, if (streak > 0) "🔥 $streak" else "")
                setChip(views, R.id.quest_difficulty, "+${next.optInt("xp", 0)} XP")
                views.setImageViewResource(R.id.quest_mascot, mascotFor(percent, false, hour(), next.optString("type")))
            }
        }

        private fun renderSingleQuest(views: RemoteViews, quest: JSONObject) {
            val done = quest.optBoolean("completedToday", false)
            val scheduled = quest.optBoolean("scheduledToday", true)
            val count = quest.optInt("itemCount", 0)
            val itemsDone = quest.optInt("itemsDone", 0)
            val progress = quest.optInt("progress", 0)
            views.setTextViewText(R.id.quest_header, "${quest.optString("emoji", "⚔️")}  ${quest.optString("title", "Quest").uppercase()}")
            views.setInt(R.id.quest_widget_root, "setBackgroundResource", if (done) R.drawable.bg_widget_quest_done else R.drawable.bg_widget_quest)
            views.setTextViewText(
                R.id.quest_summary,
                when {
                    done -> "Done ✓"
                    !scheduled -> "Rest day"
                    count > 0 -> "$itemsDone / $count"
                    else -> "To do"
                }
            )
            views.setProgressBar(R.id.quest_progress, 100, progress, false)
            val task = quest.optString("nextTask", "")
            views.setTextViewText(
                R.id.quest_title,
                when {
                    done -> "Nice work! See you tomorrow."
                    !scheduled -> "Scheduled ${quest.optString("days", "")}"
                    task.isNotEmpty() -> "Next: $task"
                    else -> "Tap to start"
                }
            )
            views.setTextViewText(R.id.quest_next, quest.optString("timeRange", ""))
            val streak = quest.optInt("streak", 0)
            setChip(views, R.id.quest_streak, if (streak > 0) "🔥 $streak" else "")
            setChip(views, R.id.quest_difficulty, quest.optString("difficulty", ""))
            views.setImageViewResource(R.id.quest_mascot, mascotFor(progress, done, hour(), quest.optString("type")))
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
