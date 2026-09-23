package com.trackme.app

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Lets the user choose what a quest widget shows: today's quests or one
 * specific quest. Declared with `configuration_optional|reconfigurable`, so
 * on Android 12+ the widget is placed immediately (as the today overview,
 * or the quest pinned from the app) and this screen is reachable later by
 * long-pressing the widget and choosing its settings.
 */
class QuestWidgetConfigureActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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
        findViewById<TextView>(R.id.configure_title)?.text = getString(R.string.quest_widget_configure_title)
        findViewById<TextView>(R.id.configure_subtitle)?.text = getString(R.string.quest_widget_configure_subtitle)

        val listContainer = findViewById<LinearLayout>(R.id.goal_list_container)
        findViewById<LinearLayout>(R.id.empty_container).visibility = android.view.View.GONE
        findViewById<Button>(R.id.open_app_button).setOnClickListener {
            packageManager.getLaunchIntentForPackage(packageName)?.let { startActivity(it) }
            finish()
        }

        val inflater = LayoutInflater.from(this)
        fun addRow(emoji: String, title: String, subtitle: String, binding: String) {
            val row = inflater.inflate(R.layout.item_widget_configure_goal, listContainer, false)
            row.findViewById<TextView>(R.id.item_emoji).text = emoji
            row.findViewById<TextView>(R.id.item_title).text = title
            row.findViewById<TextView>(R.id.item_streak).text = subtitle
            row.setOnClickListener { select(binding) }
            listContainer.addView(row)
        }

        addRow("🗓️", getString(R.string.quest_widget_today_option), getString(R.string.quest_widget_today_hint), QuestWidgetConfig.TODAY)

        val quests = TrackMeQuestWidgetProvider.parse(HomeWidgetPlugin.getData(this).getString("quest_all_json", null))
        for (i in 0 until quests.length()) {
            val q = quests.optJSONObject(i) ?: continue
            val id = q.optString("id", "")
            if (id.isEmpty()) continue
            val streak = q.optInt("streak", 0)
            addRow(q.optString("emoji", "⚔️"), q.optString("title", "Quest"), "🔥 $streak · ${q.optString("days", "")}", id)
        }
    }

    private fun select(binding: String) {
        QuestWidgetConfig.set(this, appWidgetId, binding)
        val manager = AppWidgetManager.getInstance(this)
        TrackMeQuestWidgetProvider.updateQuestWidget(this, manager, appWidgetId, HomeWidgetPlugin.getData(this))
        setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId))
        finish()
    }
}
