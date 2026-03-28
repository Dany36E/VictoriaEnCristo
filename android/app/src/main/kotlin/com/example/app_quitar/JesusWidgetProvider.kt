package com.example.app_quitar

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetPlugin

class JesusWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {}
    override fun onDisabled(context: Context) {}

    companion object {
        private const val KEY_STREAK = "jesus_streak_days"
        private const val KEY_COMPLETED = "jesus_completed_today"
        private const val KEY_MESSAGE = "jesus_widget_message"

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.jesus_widget)

            try {
                val prefs = HomeWidgetPlugin.getData(context)

                val streakDays = prefs.getInt(KEY_STREAK, 0)
                val completedToday = prefs.getBoolean(KEY_COMPLETED, false)
                val message = prefs.getString(KEY_MESSAGE, "¡Empieza hoy!") ?: "¡Empieza hoy!"

                // Número de racha
                views.setTextViewText(R.id.widget_streak_number, streakDays.toString())

                // Color del número según racha
                val streakColor = when {
                    streakDays == 0   -> 0xFF888780.toInt()
                    streakDays <= 6   -> 0xFF3B6D11.toInt()
                    streakDays <= 13  -> 0xFF185FA5.toInt()
                    streakDays <= 29  -> 0xFFBA7517.toInt()
                    streakDays <= 59  -> 0xFF534AB7.toInt()
                    streakDays <= 99  -> 0xFFA32D2D.toInt()
                    else              -> 0xFFD4AF37.toInt()
                }
                views.setTextColor(R.id.widget_streak_number, streakColor)

                // Mensaje
                views.setTextViewText(R.id.widget_message, message)

                // Badge de estado
                val badgeText: String
                val badgeColor: Int
                when {
                    completedToday -> {
                        badgeText = "✓ Día de victoria"
                        badgeColor = 0xFF4CAF50.toInt()
                    }
                    streakDays > 0 -> {
                        badgeText = "⚔ En batalla"
                        badgeColor = 0xFFD4AF37.toInt()
                    }
                    else -> {
                        badgeText = "Empieza hoy"
                        badgeColor = 0xFF888780.toInt()
                    }
                }
                views.setTextViewText(R.id.widget_badge, badgeText)
                views.setTextColor(R.id.widget_badge, badgeColor)

                // Label días
                views.setTextViewText(
                    R.id.widget_streak_label,
                    if (streakDays == 1) "día de victoria" else "días de victoria"
                )

                // Tap abre la app
                val intent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context, 1, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.jesus_widget_container, pendingIntent)

            } catch (e: Exception) {
                // Fallback: mostrar datos por defecto
                views.setTextViewText(R.id.widget_streak_number, "0")
                views.setTextViewText(R.id.widget_message, "Abre la app")
                views.setTextViewText(R.id.widget_badge, "Empieza hoy")
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
