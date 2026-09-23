package com.trackme.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Handles the widget's check button without opening the app. It marks the
 * goal/quest done in the widget data right away (so the widget flips to
 * its "done" look) and queues the check-off in `pending_checkoffs`; the app
 * applies the queue to its real database the next time it starts or
 * resumes (HomeWidgetService.applyPendingCheckOffs).
 */
class WidgetCheckOffReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION = "com.trackme.app.WIDGET_CHECK_OFF"
        const val EXTRA_KIND = "kind"
        const val EXTRA_ID = "id"
        const val KEY_PENDING = "pending_checkoffs"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION) return
        val kind = intent.getStringExtra(EXTRA_KIND) ?: return
        val id = intent.getStringExtra(EXTRA_ID) ?: return
        val prefs = es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

        val pending = try {
            JSONArray(prefs.getString(KEY_PENDING, "[]"))
        } catch (e: Exception) {
            JSONArray()
        }
        val entry = "$kind|$id|$today"
        var already = false
        for (i in 0 until pending.length()) if (pending.optString(i) == entry) already = true
        if (!already) pending.put(entry)

        val editor = prefs.edit().putString(KEY_PENDING, pending.toString())
        val keys = if (kind == "goal") listOf("goals_json") else listOf("quest_all_json", "quests_json")
        var newlyDone = false
        for (key in keys) {
            val arr = try { JSONArray(prefs.getString(key, "[]")) } catch (e: Exception) { JSONArray() }
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                if (o.optString("id") != id || o.optBoolean("completedToday", false)) continue
                o.put("completedToday", true)
                o.put("streak", o.optInt("streak", 0) + 1)
                val last5 = o.optJSONArray("last5")
                if (last5 != null && last5.length() == 5) last5.put(4, true)
                if (kind == "quest") o.put("progress", 100)
                newlyDone = true
            }
            editor.putString(key, arr.toString())
        }
        if (kind == "quest" && newlyDone) {
            editor.putInt("quest_completed_today_count", prefs.getInt("quest_completed_today_count", 0) + 1)
        }
        editor.apply()
        DuoWidget.refreshAll(context)
    }
}
