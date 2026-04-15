package com.example.app_quitar

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent
import android.graphics.Color
import android.view.View
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * VictoryWidgetProvider - Widget de pantalla de inicio
 * Lee datos desde SharedPreferences (sincronizados desde Flutter via home_widget)
 * Soporta modo discreto para privacidad
 */
class VictoryWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        // Widget agregado por primera vez
    }

    override fun onDisabled(context: Context) {
        // Último widget eliminado
    }

    companion object {
        // Keys que deben coincidir con widget_sync_service.dart
        private const val KEY_TITLE = "widget_title"
        private const val KEY_LINE1 = "widget_line1"
        private const val KEY_LINE2 = "widget_line2"
        private const val KEY_STREAK = "widget_streak"
        private const val KEY_SHOW_STREAK = "widget_show_streak"
        private const val KEY_SHOW_VERSE = "widget_show_verse"
        private const val KEY_SHOW_CTA = "widget_show_cta"
        private const val KEY_IS_LIGHT = "widget_is_light"
        private const val KEY_IS_DISCREET = "widget_is_discreet"

        // Defaults (fallback neutral)
        private const val DEFAULT_TITLE = "Rutina diaria"
        private const val DEFAULT_LINE1 = "Respira. Sigue hoy."
        private const val DEFAULT_LINE2 = "Abre la app cuando puedas."

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            // Obtener preferencias usando HomeWidgetPlugin
            val prefs = HomeWidgetPlugin.getData(context)

            // Leer datos con fallbacks
            val title = prefs.getString(KEY_TITLE, DEFAULT_TITLE) ?: DEFAULT_TITLE
            val rawLine1 = prefs.getString(KEY_LINE1, DEFAULT_LINE1) ?: DEFAULT_LINE1
            val line2 = prefs.getString(KEY_LINE2, DEFAULT_LINE2) ?: DEFAULT_LINE2
            val streak = prefs.getInt(KEY_STREAK, 0)
            val showStreak = prefs.getBoolean(KEY_SHOW_STREAK, false)
            val showVerse = prefs.getBoolean(KEY_SHOW_VERSE, false)
            val showCTA = prefs.getBoolean(KEY_SHOW_CTA, true)
            val isLight = prefs.getBoolean(KEY_IS_LIGHT, true)
            val isDiscreet = prefs.getBoolean(KEY_IS_DISCREET, true)

            // Mensaje por hora del día si es el default
            val hour = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)
            val line1 = if (rawLine1 == DEFAULT_LINE1) {
                when {
                    hour < 6  -> "Descansa bien."
                    hour < 12 -> "Nuevo día, nuevo inicio."
                    hour < 18 -> "Sigue firme."
                    else      -> "Hora de cerrar el día."
                }
            } else rawLine1

            // Crear RemoteViews
            val views = RemoteViews(context.packageName, R.layout.widget_victory)

            // Configurar colores según tema
            val bgColor = if (isLight) Color.WHITE else Color.parseColor("#1E1E2E")
            val textColor = if (isLight) Color.parseColor("#212121") else Color.WHITE
            val subtitleColor = if (isLight) Color.parseColor("#757575") else Color.parseColor("#B0B0B0")
            val accentColor = if (isLight) Color.parseColor("#6B4EE6") else Color.parseColor("#FFD54F")

            // Aplicar fondo
            views.setInt(R.id.widget_container, "setBackgroundColor", bgColor)

            // Configurar textos
            views.setTextViewText(R.id.widget_title, title)
            views.setTextColor(R.id.widget_title, textColor)

            views.setTextViewText(R.id.widget_line1, line1)
            views.setTextColor(R.id.widget_line1, subtitleColor)

            views.setTextViewText(R.id.widget_line2, line2)
            views.setTextColor(R.id.widget_line2, subtitleColor)

            // Mostrar/ocultar líneas
            views.setViewVisibility(R.id.widget_line1, if (line1.isNotEmpty()) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.widget_line2, if (line2.isNotEmpty()) View.VISIBLE else View.GONE)

            // Configurar ícono según modo
            val iconRes = if (isDiscreet) R.drawable.ic_widget_discreet else R.drawable.ic_widget_trophy
            views.setImageViewResource(R.id.widget_icon, iconRes)

            // Botón CTA
            views.setViewVisibility(R.id.widget_cta, if (showCTA) View.VISIBLE else View.GONE)
            views.setTextViewText(R.id.widget_cta, if (isDiscreet) "Abrir" else "Ver más")
            views.setTextColor(R.id.widget_cta, accentColor)

            // Intent para abrir la app al hacer tap
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Aplicar click listener al contenedor completo
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

            // Actualizar widget
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
