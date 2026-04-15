package com.example.app_quitar

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent
import android.graphics.Color
import android.view.View
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * VictoryWidget2x2Provider - Widget compacto 2x2
 * Soporta modo claro/oscuro y modo discreto
 */
class VictoryWidget2x2Provider : AppWidgetProvider() {

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
        private const val KEY_IS_LIGHT = "widget_is_light"
        private const val KEY_IS_DISCREET = "widget_is_discreet"

        // Defaults (fallback neutral)
        private const val DEFAULT_TITLE = "Rutina diaria"
        private const val DEFAULT_LINE1 = "Respira. Sigue hoy."

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            try {
                // Obtener preferencias usando HomeWidgetPlugin
                val prefs = HomeWidgetPlugin.getData(context)

                // Leer datos con fallbacks
                val title = prefs.getString(KEY_TITLE, DEFAULT_TITLE) ?: DEFAULT_TITLE
                val rawLine1 = prefs.getString(KEY_LINE1, DEFAULT_LINE1) ?: DEFAULT_LINE1
                val isLight = prefs.getBoolean(KEY_IS_LIGHT, true)
                val isDiscreet = prefs.getBoolean(KEY_IS_DISCREET, true)

                // Si el texto es el default, usar mensaje por hora del día
                val hour = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)
                val line1 = if (rawLine1 == DEFAULT_LINE1) {
                    when {
                        hour < 6  -> "Descansa bien."
                        hour < 12 -> "Nuevo día, nuevo inicio."
                        hour < 18 -> "Sigue firme."
                        else      -> "Hora de cerrar el día."
                    }
                } else rawLine1

                // Crear RemoteViews para el layout 2x2
                val views = RemoteViews(context.packageName, R.layout.widget_victory_2x2)

                // === FIX 5: Aplicar tema claro/oscuro ===
                // Cambiar fondo según tema
                val bgDrawable = if (isLight) R.drawable.widget_bg_light else R.drawable.widget_bg_dark
                views.setInt(R.id.widget_inner, "setBackgroundResource", bgDrawable)

                // Configurar colores de texto según tema
                val textColor = if (isLight) Color.parseColor("#212121") else Color.WHITE
                val subtitleColor = if (isLight) Color.parseColor("#757575") else Color.parseColor("#B0B0B0")

                // Configurar textos
                views.setTextViewText(R.id.widget_title, title)
                views.setTextColor(R.id.widget_title, textColor)

                views.setTextViewText(R.id.widget_line1, line1)
                views.setTextColor(R.id.widget_line1, subtitleColor)

                // Configurar ícono según modo
                val iconRes = if (isDiscreet) R.drawable.ic_widget_discreet else R.drawable.ic_widget_trophy
                views.setImageViewResource(R.id.widget_icon, iconRes)

                // === DEEP LINK: Intent para abrir app en pantalla de emergencia ===
                val intent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    // Extra que indica que debe abrir /emergency
                    putExtra("initial_route", "/emergency")
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
            } catch (e: Exception) {
                // Log error but don't crash
                e.printStackTrace()
            }
        }
    }
}
