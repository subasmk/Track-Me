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
        var existing = -1
        for (i in 0 until pending.length()) if (pending.optString(i) == entry) existing = i
        if (kind == "quest_item") {
            // A sub-task box is a toggle: tapping twice cancels out.
            if (existing >= 0) pending.remove(existing) else pending.put(entry)
        } else if (existing < 0) {
            pending.put(entry)
        }

        val editor = prefs.edit().putString(KEY_PENDING, pending.toString())
        if (kind == "quest_item") {
            toggleItem(prefs, editor, id)
            editor.apply()
            DuoWidget.refreshAll(context)
            return
        }
        val keys = if (kind == "goal") listOf("goals_json") else listOf("quest_all_json", "quests_json")
        var newlyDone = false
        for (key in keys) {
            val arr = try { JSONArray(prefs.getString(key, "[]")) } catch (e: Exception) { JSONArray() }
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                if (o.optString("id") != id || o.optBoolean("completedToday", false)) continue
                markQuestDone(o, kind)
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

    private fun markQuestDone(o: org.json.JSONObject, kind: String) {
        o.put("completedToday", true)
        o.put("streak", o.optInt("streak", 0) + 1)
        val last5 = o.optJSONArray("last5")
        if (last5 != null && last5.length() == 5) last5.put(4, true)
        if (kind != "goal") o.put("progress", 100)
    }

    /** Flips one sub-task in the widget data; all ticked = quest done. */
    private fun toggleItem(
        prefs: android.content.SharedPreferences,
        editor: android.content.SharedPreferences.Editor,
        key: String,
    ) {
        val questId = key.substringBefore(':')
        val itemId = key.substringAfter(':')
        var newlyDone = false
        for (k in listOf("quest_all_json", "quests_json")) {
            val arr = try { JSONArray(prefs.getString(k, "[]")) } catch (e: Exception) { JSONArray() }
            for (i in 0 until arr.length()) {
                val q = arr.optJSONObject(i) ?: continue
                if (q.optString("id") != questId || q.optBoolean("completedToday", false)) continue
                val items = q.optJSONArray("items") ?: continue
                var all = items.length() > 0
                for (j in 0 until items.length()) {
                    val sub = items.optJSONObject(j) ?: continue
                    if (sub.optString("id") == itemId) sub.put("done", !sub.optBoolean("done", false))
                    if (!sub.optBoolean("done", false)) all = false
                }
                if (all) {
                    markQuestDone(q, "quest")
                    if (k == "quests_json") newlyDone = true
                }
            }
            editor.putString(k, arr.toString())
        }
        if (newlyDone) {
            editor.putInt("quest_completed_today_count", prefs.getInt("quest_completed_today_count", 0) + 1)
        }
    }
}
