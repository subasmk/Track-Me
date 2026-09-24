package com.trackme.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

/**
 * Quest widget in the in-app Quests look (Solo Leveling system panel):
 * framed icon, quest name in caps, rank and time, +XP, then each sub-task
 * with its [0 / 15 reps × 3] target and a square check box. Tapping a box
 * ticks that sub-task through [WidgetCheckOffReceiver] without opening the app.
 */
object QuestSysWidget {
    private val rows = listOf(
        intArrayOf(R.id.sys_row0, R.id.sys_row0_name, R.id.sys_row0_target, R.id.sys_row0_check, R.id.sys_row0_tick),
        intArrayOf(R.id.sys_row1, R.id.sys_row1_name, R.id.sys_row1_target, R.id.sys_row1_check, R.id.sys_row1_tick),
        intArrayOf(R.id.sys_row2, R.id.sys_row2_name, R.id.sys_row2_target, R.id.sys_row2_check, R.id.sys_row2_tick),
        intArrayOf(R.id.sys_row3, R.id.sys_row3_name, R.id.sys_row3_target, R.id.sys_row3_check, R.id.sys_row3_tick),
    )
    private val brackets = intArrayOf(
        R.id.sys_br_tl_h, R.id.sys_br_tl_v, R.id.sys_br_tr_h, R.id.sys_br_tr_v,
        R.id.sys_br_bl_h, R.id.sys_br_bl_v, R.id.sys_br_br_h, R.id.sys_br_br_v,
    )

    fun rankFor(difficulty: String?): String = when (difficulty) {
        "Easy" -> "E"
        "Hard" -> "B"
        "Epic" -> "A"
        else -> "D"
    }

    /** How many sub-task rows fit the placed widget's height. */
    private fun maxRows(manager: AppWidgetManager, appWidgetId: Int): Int {
        val h = manager.getAppWidgetOptions(appWidgetId)
            .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110)
        return when {
            h >= 200 -> 4
            h >= 150 -> 3
            h >= 110 -> 2
            else -> 1
        }
    }

    /**
     * [quest] null = nothing to show. [todayLabel] e.g. "1/3 TODAY" for the
     * overview widget. [openUri] is where tapping the header goes.
     */
    fun render(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
        quest: JSONObject?,
        todayLabel: String?,
        emptyTitle: String,
        emptyText: String,
        openUri: String,
    ): RemoteViews {
        val v = RemoteViews(context.packageName, R.layout.widget_quest_sys)
        val done = quest?.optBoolean("completedToday", false) ?: false
        val scheduled = quest?.optBoolean("scheduledToday", true) ?: true
        v.setInt(R.id.sys_root, "setBackgroundResource", if (done) R.drawable.bg_sys_panel_done else R.drawable.bg_sys_panel)
        for (b in brackets) v.setImageViewResource(b, if (done) R.drawable.sys_bracket_ok else R.drawable.sys_bracket_cyan)
        v.setOnClickPendingIntent(R.id.sys_header, DuoWidget.launch(context, openUri))
        v.setOnClickPendingIntent(R.id.sys_root, DuoWidget.launch(context, openUri))

        if (quest == null) {
            v.setTextViewText(R.id.sys_icon, "⚔️")
            v.setTextViewText(R.id.sys_title, emptyTitle)
            v.setTextViewText(R.id.sys_meta, todayLabel ?: "")
            v.setTextViewText(R.id.sys_xp, "")
            v.setTextViewText(R.id.sys_empty, emptyText)
            v.setViewVisibility(R.id.sys_empty, View.VISIBLE)
            for (r in rows) v.setViewVisibility(r[0], View.GONE)
            return v
        }

        val id = quest.optString("id")
        v.setTextViewText(R.id.sys_icon, quest.optString("emoji", "⚔️"))
        v.setTextViewText(R.id.sys_title, quest.optString("title", "Quest").uppercase())
        val meta = listOfNotNull(
            "RANK ${rankFor(quest.optString("difficulty"))}",
            quest.optString("timeRange", "").ifEmpty { null },
            if (!scheduled) "REST DAY" else null,
            todayLabel,
        ).joinToString("  ·  ")
        v.setTextViewText(R.id.sys_meta, meta)
        v.setTextViewText(R.id.sys_xp, if (done) "CLEAR" else "+${quest.optInt("xp", 0)} XP")
        v.setTextColor(R.id.sys_xp, if (done) 0xFF4DFFB8.toInt() else 0xFFFFD166.toInt())
        v.setTextColor(R.id.sys_title, if (done) 0xFFB8FFE4.toInt() else 0xFFE6F7FF.toInt())

        val items = quest.optJSONArray("items")
        val limit = maxRows(manager, appWidgetId)
        v.setViewVisibility(R.id.sys_empty, View.GONE)
        if (items == null || items.length() == 0) {
            // No sub-tasks: one row that completes the whole quest.
            show(context, v, rows[0], "Complete quest", if (done) "[DONE]" else "[0 / 1]", done,
                if (scheduled && !done) DuoWidget.checkOffIntent(context, "quest", id) else null,
                openUri)
            for (i in 1 until rows.size) v.setViewVisibility(rows[i][0], View.GONE)
            return v
        }
        for (i in rows.indices) {
            val item = if (i < limit) items.optJSONObject(i) else null
            if (item == null) {
                v.setViewVisibility(rows[i][0], View.GONE)
                continue
            }
            val itemDone = done || item.optBoolean("done", false)
            val label = item.optString("label", "")
            val more = items.length() - limit
            val name = if (i == limit - 1 && more > 0) "${item.optString("name")}  (+$more)" else item.optString("name")
            show(context, v, rows[i], name, if (itemDone) "[$label]" else "[0 / $label]", itemDone,
                if (scheduled && !done) DuoWidget.checkOffIntent(context, "quest_item", "$id:${item.optString("id")}") else null,
                openUri)
        }
        return v
    }

    private fun show(
        context: Context, v: RemoteViews, r: IntArray, name: String, target: String,
        checked: Boolean, tap: android.app.PendingIntent?, openUri: String,
    ) {
        v.setViewVisibility(r[0], View.VISIBLE)
        v.setTextViewText(r[1], name)
        v.setTextColor(r[1], if (checked) 0xFF7FA9C7.toInt() else 0xFFE6F7FF.toInt())
        v.setTextViewText(r[2], target)
        v.setTextColor(r[2], if (checked) 0xFF4DFFB8.toInt() else 0xFF8BE6FF.toInt())
        v.setInt(r[3], "setBackgroundResource", if (checked) R.drawable.bg_sys_check_on else R.drawable.bg_sys_check)
        v.setViewVisibility(r[4], if (checked) View.VISIBLE else View.GONE)
        val intent = tap ?: DuoWidget.launch(context, openUri)
        v.setOnClickPendingIntent(r[3], intent)
        v.setOnClickPendingIntent(r[0], intent)
    }

    fun openUriFor(id: String) = "trackme://quest?id=${Uri.encode(id)}"
}
