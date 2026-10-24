package com.example.app_quitar

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent
import android.view.View

/**
 * VictoryWidget2x2Provider - Widget compacto 2x2 (recordatorio).
 *
 * Estilo «Papel recortado» como la app. «Tarjeta clara» usa el papel claro;
 * «oscura», el papel oscuro activo de la app (kraft si la app está en claro).
 * Con la plantilla de versículo muestra el versículo completo y su cita, y
 * cambia a medianoche con la lista que guarda la app.
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
        WidgetDia.programarMedianoche(context)
    }

    override fun onDisabled(context: Context) {
    }

    companion object {
        private const val KEY_TITLE = "widget_title"
        private const val KEY_LINE1 = "widget_line1"
        private const val KEY_LINE2 = "widget_line2"
        private const val KEY_TEMPLATE = "widget_template"
        private const val KEY_IS_LIGHT = "widget_is_light"
        private const val KEY_IS_DISCREET = "widget_is_discreet"

        private const val DEFAULT_TITLE = "Rutina diaria"
        private const val DEFAULT_LINE1 = "Respira. Sigue hoy."

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            try {
                val prefs = WidgetDia.prefs(context)

                val title = prefs.getString(KEY_TITLE, DEFAULT_TITLE) ?: DEFAULT_TITLE
                val rawLine1 = prefs.getString(KEY_LINE1, DEFAULT_LINE1) ?: DEFAULT_LINE1
                var line2 = prefs.getString(KEY_LINE2, "") ?: ""
                val isLight = prefs.getBoolean(KEY_IS_LIGHT, true)
                val isDiscreet = prefs.getBoolean(KEY_IS_DISCREET, true)

                val hour = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)
                var line1 = if (rawLine1 == DEFAULT_LINE1) {
                    when {
                        hour < 6  -> "Descansa bien."
                        hour < 12 -> "Nuevo día, nuevo inicio."
                        hour < 18 -> "Sigue firme."
                        else      -> "Hora de cerrar el día."
                    }
                } else rawLine1

                // Plantilla de versículo: el del día de hoy, completo.
                if (prefs.getString(KEY_TEMPLATE, null) == "verse") {
                    val verso = WidgetDia.versiculoDeHoy(prefs)
                    line1 = verso.texto
                    line2 = verso.cita
                }

                val app = PaletaPapel.leer(prefs)
                val paleta = when {
                    isLight -> PaletaPapel.CLARO
                    app.oscuro -> app
                    else -> PaletaPapel.KRAFT
                }

                val views = RemoteViews(context.packageName, R.layout.widget_victory_2x2)

                views.setInt(R.id.widget_papel, "setColorFilter", paleta.papel)
                views.setInt(R.id.widget_sombra, "setColorFilter", paleta.sombra)

                views.setTextViewText(R.id.widget_title, title)
                views.setTextColor(R.id.widget_title, paleta.tinta)

                views.setTextViewText(R.id.widget_line1, line1)
                views.setTextColor(R.id.widget_line1, paleta.tinta)

                if (line2.isBlank()) {
                    views.setViewVisibility(R.id.widget_line2, View.GONE)
                } else {
                    views.setViewVisibility(R.id.widget_line2, View.VISIBLE)
                    views.setTextViewText(R.id.widget_line2, line2)
                    views.setTextColor(R.id.widget_line2, paleta.terracota)
                }

                val iconRes = if (isDiscreet) R.drawable.ic_widget_discreet else R.drawable.ic_widget_trophy
                views.setImageViewResource(R.id.widget_icon, iconRes)
                views.setInt(R.id.widget_icon, "setColorFilter", paleta.terracota)

                views.setContentDescription(
                    R.id.widget_container,
                    listOf(title, line1, line2).filter { it.isNotBlank() }.joinToString(". ")
                )

                val intent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("initial_route", "/emergency")
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
