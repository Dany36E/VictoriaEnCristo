package com.example.app_quitar

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.res.ColorStateList
import android.os.Build
import android.view.View
import android.widget.RemoteViews

/**
 * AtajosWidgetProvider - Widget «Atajos» (4x1)
 * Muestra los primeros atajos que el usuario eligió en la app (hasta 4);
 * sin elección, Biblia, Estudio bíblico y Apuntes.
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

        // Casilla, dibujo y texto de cada posición del layout
        private val CASILLAS = listOf(
            Triple(R.id.atajo_0, R.id.atajo_0_icono, R.id.atajo_0_texto),
            Triple(R.id.atajo_1, R.id.atajo_1_icono, R.id.atajo_1_texto),
            Triple(R.id.atajo_2, R.id.atajo_2_icono, R.id.atajo_2_texto),
            Triple(R.id.atajo_3, R.id.atajo_3_icono, R.id.atajo_3_texto)
        )

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            try {
                // Mismo papel que Inicio (claro, kraft o noche).
                val paleta = PaletaPapel.leer(WidgetDia.prefs(context))
                val isLight = !paleta.oscuro
                val tintar = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
                val atajos = Atajos.leer(context)
                val views = RemoteViews(context.packageName, R.layout.widget_atajos)

                views.setInt(
                    R.id.atajos_raiz,
                    "setBackgroundResource",
                    if (isLight) R.drawable.widget_atajos_bg_light else R.drawable.widget_atajos_bg_dark
                )
                val boton = if (isLight) R.drawable.widget_atajos_boton_light else R.drawable.widget_atajos_boton_dark
                val textColor = paleta.tinta
                if (tintar) {
                    views.setColorStateList(
                        R.id.atajos_raiz, "setBackgroundTintList", ColorStateList.valueOf(paleta.crema)
                    )
                }

                CASILLAS.forEachIndexed { i, (casilla, icono, texto) ->
                    val atajo = atajos.getOrNull(i)
                    if (atajo == null) {
                        views.setViewVisibility(casilla, View.GONE)
                        return@forEachIndexed
                    }
                    views.setViewVisibility(casilla, View.VISIBLE)
                    views.setInt(casilla, "setBackgroundResource", boton)
                    if (tintar) {
                        views.setColorStateList(
                            casilla, "setBackgroundTintList", ColorStateList.valueOf(paleta.papel)
                        )
                    }
                    views.setImageViewResource(icono, Atajos.dibujos.getValue(atajo.id))
                    views.setTextViewText(texto, atajo.titulo)
                    views.setTextColor(texto, textColor)
                    views.setContentDescription(casilla, context.getString(R.string.atajo_abrir, atajo.titulo))
                    views.setOnClickPendingIntent(casilla, Atajos.pendingIntent(context, atajo.id))
                }

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                // Log error but don't crash
                e.printStackTrace()
            }
        }
    }
}
