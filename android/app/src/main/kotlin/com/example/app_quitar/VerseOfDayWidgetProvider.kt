package com.example.app_quitar

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent
import android.os.Bundle
import android.view.View

/**
 * VerseOfDayWidgetProvider - Widget 4x2 del versículo del día.
 *
 * Igual que la tarjeta de Inicio (TarjetaVersiculo, «Papel recortado»): cita
 * en terracota, versión en gris y el versículo COMPLETO con letra de mano,
 * en los colores del papel activo de la app. El versículo sale de la lista
 * de los próximos días que guarda la app, así cambia a medianoche aunque la
 * app no se abra.
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
        WidgetDia.programarMedianoche(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onEnabled(context: Context) {
        WidgetDia.programarMedianoche(context)
    }

    override fun onDisabled(context: Context) {}

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            try {
                val prefs = WidgetDia.prefs(context)
                val paleta = PaletaPapel.leer(prefs)
                val verso = WidgetDia.versiculoDeHoy(prefs)

                val views = RemoteViews(context.packageName, R.layout.widget_verse_of_day)

                views.setInt(R.id.verse_widget_papel, "setColorFilter", paleta.papel)
                views.setInt(R.id.verse_widget_sombra, "setColorFilter", paleta.sombra)

                views.setTextViewText(R.id.verse_widget_reference, verso.cita)
                views.setTextColor(R.id.verse_widget_reference, paleta.terracota)
                if (verso.version.isBlank()) {
                    views.setViewVisibility(R.id.verse_widget_version, View.GONE)
                } else {
                    views.setViewVisibility(R.id.verse_widget_version, View.VISIBLE)
                    views.setTextViewText(R.id.verse_widget_version, verso.version)
                    views.setTextColor(R.id.verse_widget_version, paleta.gris)
                }
                views.setTextViewText(R.id.verse_widget_text, verso.texto)
                views.setTextColor(R.id.verse_widget_text, paleta.tinta)

                views.setContentDescription(
                    R.id.verse_widget_container,
                    "Versículo del día, ${verso.cita}: ${verso.texto}"
                )

                // Abre la app en la Biblia
                val intent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("initial_route", "/bible")
                }
                val pendingIntent = PendingIntent.getActivity(
                    context, 11, intent,
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
