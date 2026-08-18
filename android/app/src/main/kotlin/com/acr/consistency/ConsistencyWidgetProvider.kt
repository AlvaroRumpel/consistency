package com.acr.consistency

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Shown wherever the Flutter side has written nothing yet. */
private const val EMPTY = "—"

private val WEEK_IDS =
    intArrayOf(R.id.w0, R.id.w1, R.id.w2, R.id.w3, R.id.w4, R.id.w5, R.id.w6)

/** Streak buckets 0 / 1-6 / 7-29 / 30-99 / 100+. */
private fun flameColor(streak: Int?): Int =
    when {
      streak == null || streak <= 0 -> R.color.widget_flame_0
      streak < 7 -> R.color.widget_flame_1
      streak < 30 -> R.color.widget_flame_2
      streak < 100 -> R.color.widget_flame_3
      else -> R.color.widget_flame_4
    }

/** One `week` character: `-` (or anything unexpected) means "no data". */
private fun qualityColor(tier: Char?): Int =
    when (tier) {
      '1' -> R.color.widget_quality_1
      '2' -> R.color.widget_quality_2
      '3' -> R.color.widget_quality_3
      '4' -> R.color.widget_quality_4
      else -> R.color.widget_quality_0
    }

/**
 * Renders one widget size from the `home_widget` SharedPreferences the Flutter
 * side writes (`streak`, `line1`, `line2`, `week`). Every value is optional:
 * missing or blank data renders as a neutral state, never a crash.
 */
private fun render(context: Context, prefs: SharedPreferences, layout: Int): RemoteViews {
  // Read through `all` rather than getInt: Flutter sends an int as either an
  // Int or a Long depending on its magnitude, and getInt would throw on a Long.
  val streak = (prefs.all["streak"] as? Number)?.toInt()
  val week = prefs.getString("week", null).orEmpty()
  val views = RemoteViews(context.packageName, layout)

  views.setInt(R.id.flame, "setColorFilter", ContextCompat.getColor(context, flameColor(streak)))
  if (layout == R.layout.widget_small) {
    views.setTextViewText(R.id.streak, streak?.toString() ?: EMPTY)
    views.setTextViewText(R.id.label, text(prefs, "line2"))
  } else {
    views.setTextViewText(R.id.line1, text(prefs, "line1"))
    views.setTextViewText(R.id.line2, text(prefs, "line2"))
    WEEK_IDS.forEachIndexed { i, id ->
      val color = ContextCompat.getColor(context, qualityColor(week.getOrNull(i)))
      views.setInt(id, "setColorFilter", color)
    }
  }
  views.setOnClickPendingIntent(
      R.id.root,
      HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
  )
  return views
}

private fun text(prefs: SharedPreferences, key: String): String =
    prefs.getString(key, null)?.takeIf { it.isNotBlank() } ?: EMPTY

private fun update(
    context: Context,
    manager: AppWidgetManager,
    ids: IntArray,
    prefs: SharedPreferences,
    layout: Int,
) {
  val views = render(context, prefs, layout)
  ids.forEach { manager.updateAppWidget(it, views) }
}

/** 2x1: flame + streak number + status label. */
class ConsistencyWidgetProviderSmall : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) = update(context, appWidgetManager, appWidgetIds, widgetData, R.layout.widget_small)
}

/** 2x2: flame + both lines + the 7-day strip. */
class ConsistencyWidgetProviderLarge : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) = update(context, appWidgetManager, appWidgetIds, widgetData, R.layout.widget_large)
}
