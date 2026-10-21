package com.example.app_quitar

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * AtajosWidgetProvider - Widget «Atajos» (4x1)
 * Tres accesos directos: Biblia, Estudio bíblico y Apuntes.
 * Cada uno abre MainActivity con la ruta /atajo/<id>, que Flutter
 * resuelve en abrirAtajo() (lib/widgets/home/atajos_inicio.dart).
 */
class AtajosWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        // Key compartida con widget_sync_service.dart (claro/oscuro)
        private const val KEY_IS_LIGHT = "widget_is_light"

        // Casilla del layout, texto de la casilla e id del atajo en Flutter
        private val ATAJOS = listOf(
            Triple(R.id.atajo_biblia, R.id.atajo_biblia_texto, "biblia"),
            Triple(R.id.atajo_estudio, R.id.atajo_estudio_texto, "estudio"),
            Triple(R.id.atajo_apuntes, R.id.atajo_apuntes_texto, "apuntes")
        )

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            try {
                val isLight = HomeWidgetPlugin.getData(context).getBoolean(KEY_IS_LIGHT, true)
                val views = RemoteViews(context.packageName, R.layout.widget_atajos)

                views.setInt(
                    R.id.atajos_raiz,
                    "setBackgroundResource",
                    if (isLight) R.drawable.widget_atajos_bg_light else R.drawable.widget_atajos_bg_dark
                )
                val boton = if (isLight) R.drawable.widget_atajos_boton_light else R.drawable.widget_atajos_boton_dark
                val textColor = if (isLight) Color.parseColor("#2B2622") else Color.WHITE

                for ((casilla, texto, id) in ATAJOS) {
                    views.setInt(casilla, "setBackgroundResource", boton)
                    views.setTextColor(texto, textColor)
                    views.setOnClickPendingIntent(casilla, intentAtajo(context, id))
                }

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                // Log error but don't crash
                e.printStackTrace()
            }
        }

        /**
         * Intent propio por atajo: la acción distinta evita que Android
         * reutilice (y sobrescriba) el PendingIntent de otro widget.
         */
        private fun intentAtajo(context: Context, id: String): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "${context.packageName}.ATAJO_$id"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("initial_route", "/atajo/$id")
            }
            return PendingIntent.getActivity(
                context,
                id.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
    }
}
