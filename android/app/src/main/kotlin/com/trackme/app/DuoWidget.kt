package com.trackme.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar

/**
 * Duolingo-style widget look shared by the goal and quest widgets:
 * urgency color + copy by time of day, a big sloth bleeding off the edge,
 * a streak count with a warning badge, a 5-day check strip, and a
 * tap-to-check-off button (broadcast to [WidgetCheckOffReceiver]).
 */
object DuoWidget {
    const val KEY_STYLE = "widget_style"          // "auto" or a theme id
    const val KEY_BG_PATH = "widget_bg_path"      // custom background photo
    const val KEY_USER_NAME = "user_name"

    enum class Urgency { DONE, READY, FORGOT, LATE, LAST_CALL }

    data class Model(
        val kind: String,          // "goal" or "quest"
        val id: String,            // goal/quest id ("" = nothing to check off)
        val title: String,
        val streak: Int,
        val done: Boolean,
        val themeId: String?,
        val last5: BooleanArray,   // oldest -> today
        val openUri: String,
    )

    fun urgencyFor(done: Boolean, hour: Int): Urgency = when {
        done -> Urgency.DONE
        hour >= 22 || hour < 4 -> Urgency.LAST_CALL
        hour >= 19 -> Urgency.LATE
        hour >= 15 -> Urgency.FORGOT
        else -> Urgency.READY
    }

    private fun firstName(raw: String?): String {
        val n = (raw ?: "").trim()
        if (n.isEmpty() || n.equals("learner", true)) return ""
        return n.split(" ", ".", "_").first().uppercase()
    }

    fun messageFor(u: Urgency, name: String, streak: Int, kind: String): String {
        val who = if (name.isEmpty()) "" else ", $name"
        val thing = if (kind == "quest") "quest" else "lesson"
        return when (u) {
            Urgency.DONE -> if (streak >= 7) "On fire$who! 🔥" else "Nice work$who!"
            Urgency.READY -> "You ready$who?"
            Urgency.FORGOT -> "Hmm, forgot your $thing?"
            Urgency.LATE -> "It's late!"
            Urgency.LAST_CALL -> "Don't forget me..."
        }
    }

    private fun mascotFor(u: Urgency, streak: Int): Int = when (u) {
        Urgency.DONE -> if (streak >= 7) R.drawable.sloth_levelup else R.drawable.sloth_cheering
        Urgency.READY -> R.drawable.sloth_ready
        Urgency.FORGOT -> R.drawable.sloth_worried
        Urgency.LATE -> R.drawable.sloth_worried
        Urgency.LAST_CALL -> R.drawable.sloth_sleepy
    }

    private fun urgencyBg(u: Urgency): Int = when (u) {
        Urgency.DONE, Urgency.READY -> R.drawable.bg_duo_ready
        Urgency.FORGOT -> R.drawable.bg_duo_forgot
        Urgency.LATE -> R.drawable.bg_duo_late
        Urgency.LAST_CALL -> R.drawable.bg_duo_lastcall
    }

    private val dayLabelIds = intArrayOf(
        R.id.duo_day_0_label, R.id.duo_day_1_label, R.id.duo_day_2_label,
        R.id.duo_day_3_label, R.id.duo_day_4_label
    )
    private val dayPillIds = intArrayOf(
        R.id.duo_day_0_pill, R.id.duo_day_1_pill, R.id.duo_day_2_pill,
        R.id.duo_day_3_pill, R.id.duo_day_4_pill
    )
    private val letters = arrayOf("S", "M", "T", "W", "T", "F", "S")

    fun render(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        widgetData: SharedPreferences,
        m: Model,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_duo)
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        val u = urgencyFor(m.done, hour)
        val name = firstName(widgetData.getString(KEY_USER_NAME, null))

        // Background: custom photo > chosen theme > urgency colors (auto).
        val style = widgetData.getString(KEY_STYLE, "auto") ?: "auto"
        val bg = when {
            style != "auto" -> GoalThemeColors.drawableFor(style)
            m.done && m.themeId != null -> GoalThemeColors.drawableFor(m.themeId)
            else -> urgencyBg(u)
        }
        views.setInt(R.id.duo_root, "setBackgroundResource", bg)
        val photo = loadBackground(widgetData.getString(KEY_BG_PATH, null))
        if (photo != null) {
            views.setImageViewBitmap(R.id.duo_bg_image, photo)
            views.setViewVisibility(R.id.duo_bg_image, View.VISIBLE)
            views.setViewVisibility(R.id.duo_bg_scrim, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.duo_bg_image, View.GONE)
            views.setViewVisibility(R.id.duo_bg_scrim, View.GONE)
        }

        views.setTextViewText(R.id.duo_streak, "${m.streak} ${if (m.streak == 1) "day" else "days"}")
        views.setTextViewText(R.id.duo_message, messageFor(u, name, m.streak, m.kind))
        views.setTextViewText(R.id.duo_title, m.title)
        views.setViewVisibility(
            R.id.duo_badge,
            if (!m.done && (u == Urgency.LATE || u == Urgency.LAST_CALL || u == Urgency.FORGOT)) View.VISIBLE else View.GONE
        )
        views.setImageViewResource(R.id.duo_mascot, mascotFor(u, m.streak))

        // 5-day strip ending today.
        val cal = Calendar.getInstance()
        val todayDow = cal.get(Calendar.DAY_OF_WEEK) - 1
        for (i in 0 until 5) {
            val dow = ((todayDow - (4 - i)) % 7 + 7) % 7
            views.setTextViewText(dayLabelIds[i], letters[dow])
            val done = m.last5.getOrElse(i) { false }
            val isToday = i == 4
            views.setInt(
                dayPillIds[i], "setBackgroundResource",
                when {
                    done -> R.drawable.bg_duo_pill_done
                    isToday -> R.drawable.bg_duo_pill_today
                    else -> R.drawable.bg_duo_pill_missed
                }
            )
            views.setTextViewText(dayPillIds[i], if (done) "✓" else "")
        }

        // Compact sizes hide the strip and title.
        val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val w = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0
        val h = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0
        val wide = w == 0 || w >= 220
        views.setViewVisibility(R.id.duo_week_row, if (wide && (h == 0 || h >= 100)) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.duo_title, if (wide) View.VISIBLE else View.GONE)

        // Tap-to-check-off.
        if (m.id.isNotEmpty() && !m.done) {
            views.setInt(R.id.duo_check, "setBackgroundResource", R.drawable.bg_duo_check)
            views.setTextColor(R.id.duo_check, 0xFFFFFFFF.toInt())
            views.setOnClickPendingIntent(R.id.duo_check, checkOffIntent(context, m.kind, m.id))
            views.setViewVisibility(R.id.duo_check, View.VISIBLE)
        } else if (m.done) {
            views.setInt(R.id.duo_check, "setBackgroundResource", R.drawable.bg_duo_check_done)
            views.setTextColor(R.id.duo_check, 0xFF58CC02.toInt())
            views.setOnClickPendingIntent(R.id.duo_check, launch(context, m.openUri))
            views.setViewVisibility(R.id.duo_check, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.duo_check, View.GONE)
        }
        views.setOnClickPendingIntent(R.id.duo_root, launch(context, m.openUri))
        return views
    }

    fun launch(context: Context, uri: String): PendingIntent =
        es.antonborri.home_widget.HomeWidgetLaunchIntent.getActivity(
            context, MainActivity::class.java, android.net.Uri.parse(uri)
        )

    private fun checkOffIntent(context: Context, kind: String, id: String): PendingIntent {
        val intent = Intent(context, WidgetCheckOffReceiver::class.java).apply {
            action = WidgetCheckOffReceiver.ACTION
            putExtra(WidgetCheckOffReceiver.EXTRA_KIND, kind)
            putExtra(WidgetCheckOffReceiver.EXTRA_ID, id)
            data = android.net.Uri.parse("trackme://checkoff/$kind/$id")
        }
        return PendingIntent.getBroadcast(
            context, "$kind:$id".hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /** Decodes the custom photo small enough for the RemoteViews size limit. */
    private fun loadBackground(path: String?): Bitmap? {
        if (path.isNullOrEmpty()) return null
        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, bounds)
            if (bounds.outWidth <= 0) return null
            var sample = 1
            while (bounds.outWidth / sample > 720 || bounds.outHeight / sample > 720) sample *= 2
            val opts = BitmapFactory.Options().apply {
                inSampleSize = sample
                inPreferredConfig = Bitmap.Config.RGB_565
            }
            BitmapFactory.decodeFile(path, opts)
        } catch (e: Exception) {
            null
        }
    }

    /** Redraws every goal and quest widget. */
    fun refreshAll(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)
        val data = es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
        for (id in mgr.getAppWidgetIds(ComponentName(context, TrackMeGoalWidgetProvider::class.java))) {
            TrackMeGoalWidgetProvider.updateAppWidget(context, mgr, id, data)
        }
        for (id in mgr.getAppWidgetIds(ComponentName(context, TrackMeQuestWidgetProvider::class.java))) {
            TrackMeQuestWidgetProvider.updateQuestWidget(context, mgr, id, data)
        }
    }

    fun last5From(arr: org.json.JSONArray?): BooleanArray =
        BooleanArray(5) { i -> arr?.optBoolean(i, false) ?: false }
}
