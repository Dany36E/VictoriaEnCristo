package com.example.app_quitar

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent
import android.graphics.Color
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * VerseOfDayWidgetProvider - Widget 4x2 para versículo del día
 * Muestra el versículo diario con referencia. Soporta claro/oscuro.
 */
class VerseOfDayWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {}
    override fun onDisabled(context: Context) {}

    companion object {
        private const val KEY_VERSE_TEXT = "verse_widget_text"
        private const val KEY_VERSE_REF = "verse_widget_reference"
        private const val KEY_IS_LIGHT = "verse_widget_is_light"

        private const val DEFAULT_TEXT = "Todo lo puedo en Cristo que me fortalece."
        private const val DEFAULT_REF = "Filipenses 4:13"

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            try {
                val prefs = HomeWidgetPlugin.getData(context)

                val verseText = prefs.getString(KEY_VERSE_TEXT, DEFAULT_TEXT) ?: DEFAULT_TEXT
                val verseRef = prefs.getString(KEY_VERSE_REF, DEFAULT_REF) ?: DEFAULT_REF
                val isLight = prefs.getBoolean(KEY_IS_LIGHT, false)

                val views = RemoteViews(context.packageName, R.layout.widget_verse_of_day)

                // Theme
                val bgDrawable = if (isLight) R.drawable.widget_bg_light else R.drawable.widget_bg_dark
                views.setInt(R.id.verse_widget_inner, "setBackgroundResource", bgDrawable)

                val textColor = if (isLight) Color.parseColor("#212121") else Color.WHITE
                val labelColor = if (isLight) Color.parseColor("#757575") else Color.parseColor("#B0B0B0")
                val accentColor = Color.parseColor("#D4AF37")

                views.setTextColor(R.id.verse_widget_label, labelColor)
                views.setTextViewText(R.id.verse_widget_text, verseText)
                views.setTextColor(R.id.verse_widget_text, textColor)
                views.setTextViewText(R.id.verse_widget_reference, verseRef)
                views.setTextColor(R.id.verse_widget_reference, accentColor)

                // Deep link to Bible reader
                val intent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("initial_route", "/bible")
                }
                val pendingIntent = PendingIntent.getActivity(
                    context, 1, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.verse_widget_container, pendingIntent)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
