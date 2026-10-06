package com.setir.bloom

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Today's count, or 0 once the saved day has passed (the app may be closed). */
private fun doneToday(data: SharedPreferences): Int {
    val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date())
    return if (data.getString("day", today) == today) data.getInt("done", 0) else 0
}

/** Her pose: cheering once the ring is full, waiting after a missed day, else resting. */
private fun cloverDrawable(data: SharedPreferences, done: Int, goal: Int) = when {
    done >= goal -> R.drawable.widget_clover_cheer
    done == 0 && data.getBoolean("missed", false) -> R.drawable.widget_clover_wait
    else -> R.drawable.widget_clover_rest
}

private fun openApp(context: Context) = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)

/** Bloom · Today (4x2): Clover, her line, today's moves and paws. */
class BloomTodayWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val done = doneToday(widgetData)
        val goal = widgetData.getInt("goal", 3)
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_today).apply {
                setImageViewResource(R.id.clover, cloverDrawable(widgetData, done, goal))
                setTextViewText(
                    R.id.line,
                    if (done == 0 && !widgetData.getBoolean("missed", false)) context.getString(R.string.widget_line_default)
                    else widgetData.getString("line", null) ?: context.getString(R.string.widget_line_default),
                )
                setProgressBar(R.id.progress, goal, done.coerceAtMost(goal), false)
                setTextViewText(R.id.done, "$done of $goal today")
                setTextViewText(R.id.paws, "${widgetData.getInt("paws", 0)} paws")
                setOnClickPendingIntent(R.id.widget_root, openApp(context))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}

/** Bloom · Clover (2x2): just her, with today's count. */
class BloomCloverWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val done = doneToday(widgetData)
        val goal = widgetData.getInt("goal", 3)
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_clover).apply {
                setImageViewResource(R.id.clover, cloverDrawable(widgetData, done, goal))
                setTextViewText(R.id.done, if (done >= goal) "$goal/$goal done" else "$done/$goal")
                setOnClickPendingIntent(R.id.widget_root, openApp(context))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
