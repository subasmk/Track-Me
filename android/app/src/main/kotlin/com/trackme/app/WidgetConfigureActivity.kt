package com.trackme.app

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

/**
 * Shown by Android automatically the moment a user drags a
 * [TrackMeGoalWidgetProvider] instance onto their home screen (declared via
 * `android:configure` in trackme_goal_widget_info.xml). Lets them pick which
 * goal this particular widget instance should track, then finishes —
 * Android places the widget only if we finish with [RESULT_OK].
 *
 * Deliberately plain framework views (no Flutter engine, no AndroidX) so
 * this screen appears instantly rather than paying Flutter's cold-start
 * cost just to show a short list.
 */
class WidgetConfigureActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Default to CANCELED: if the user backs out without picking a
        // goal, Android must not place the widget. Only selectGoal()
        // upgrades this to RESULT_OK.
        setResult(RESULT_CANCELED)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.activity_widget_configure)

        val listContainer = findViewById<LinearLayout>(R.id.goal_list_container)
        val emptyContainer = findViewById<LinearLayout>(R.id.empty_container)
        val openAppButton = findViewById<Button>(R.id.open_app_button)

        openAppButton.setOnClickListener {
            packageManager.getLaunchIntentForPackage(packageName)?.let { startActivity(it) }
            finish()
        }

        val goals = loadGoals()

        if (goals.length() == 0) {
            // Auto-fallback so 2x2 widget never displays a blank screen
            selectGoal("default_goal")
            return
        }

        val inflater = LayoutInflater.from(this)
        for (i in 0 until goals.length()) {
            val goal = goals.getJSONObject(i)
            val goalId = goal.optString("id", "")
            if (goalId.isEmpty()) continue // Defensive: skip any malformed entry.

            val row = inflater.inflate(R.layout.item_widget_configure_goal, listContainer, false)
            val streak = goal.optInt("streak", 0)
            val unit = if (streak == 1) "day" else "days"

            row.findViewById<TextView>(R.id.item_emoji).apply {
                text = goal.optString("emoji", "🎯")
                background = tintedSquare(goal.optString("theme", "purple"))
            }
            row.findViewById<TextView>(R.id.item_title).text = goal.optString("title", "Goal")
            row.findViewById<TextView>(R.id.item_streak).text = "🔥 $streak $unit"

            row.setOnClickListener { selectGoal(goalId) }
            listContainer.addView(row)
        }
    }

    private fun loadGoals(): JSONArray {
        return try {
            val widgetData = HomeWidgetPlugin.getData(this)
            JSONArray(widgetData.getString("goals_json", null) ?: "[]")
        } catch (e: Exception) {
            JSONArray()
        }
    }

    /** A rounded square tinted with a translucent version of the goal's own
     * theme color, so this picker previews which color its widget will
     * use. Built at runtime rather than as a resource since the color
     * depends on data, not a fixed drawable. */
    private fun tintedSquare(themeId: String): GradientDrawable {
        val baseColor = getColor(GoalThemeColors.midColorRes(themeId))
        val tinted = (0x40 shl 24) or (baseColor and 0x00FFFFFF)
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = 24f * resources.displayMetrics.density
            setColor(tinted)
        }
    }

    private fun selectGoal(goalId: String) {
        WidgetConfig.setGoalId(this, appWidgetId, goalId)

        // Render once immediately so the widget shows real data the instant
        // it lands on the home screen, rather than its placeholder layout
        // for the brief moment before the system's own onUpdate call.
        val appWidgetManager = AppWidgetManager.getInstance(this)
        val widgetData = HomeWidgetPlugin.getData(this)
        TrackMeGoalWidgetProvider.updateAppWidget(this, appWidgetManager, appWidgetId, widgetData)

        val resultValue = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        setResult(RESULT_OK, resultValue)
        finish()
    }
}
