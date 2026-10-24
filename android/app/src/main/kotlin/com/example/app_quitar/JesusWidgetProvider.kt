package com.example.app_quitar

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent
import java.io.File
import kotlin.math.sqrt

/**
 * Widget Jesús (racha). Muestra la MISMA tarjeta de racha de Inicio
 * («Papel recortado»): la app la dibuja con Flutter en dos formas (ancha
 * 4×2 y alta 3×3) para hoy y para mañana (día sin registrar). Aquí se
 * elige la que toca según la fecha y la proporción del widget, así a
 * medianoche cambia aunque la app no se abra.
 *
 * Si todavía no hay imagen (widget recién puesto), se ve una versión
 * nativa de la misma tarjeta.
 */
class JesusWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
        WidgetDia.programarMedianoche(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        // Al cambiar de tamaño puede tocar la otra forma de la tarjeta.
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onEnabled(context: Context) {
        WidgetDia.programarMedianoche(context)
    }

    override fun onDisabled(context: Context) {}

    companion object {
        private const val KEY_STREAK = "jesus_streak_days"
        private const val KEY_COMPLETED = "jesus_completed_today"
        private const val KEY_MESSAGE = "jesus_widget_message"
        private const val KEY_SPRITE_PATH = "jesus_sprite_path"
        private const val KEY_BADGE_TEXT = "jesus_badge_text"
        private const val KEY_IMG_FECHA = "jesus_img_fecha"

        /**
         * Píxeles máximos del bitmap: RemoteViews lo manda por IPC y un
         * bitmap muy grande hace fallar la actualización (~1 MB en ARGB).
         */
        private const val MAX_PIXELES = 280_000

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = WidgetDia.prefs(context)
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val anchoDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250)
            val altoDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 130)
            val densidad = context.resources.displayMetrics.density

            val dia = WidgetDia.diaImagenJesus(prefs.getString(KEY_IMG_FECHA, null), WidgetDia.iso())
            val forma = WidgetDia.formaImagen(anchoDp, altoDp)
            val ruta = prefs.getString("jesus_img_${dia}_$forma", null)
            val descripcion = prefs.getString(
                if (dia == "hoy") "jesus_a11y_hoy" else "jesus_a11y_manana", null
            )

            for (maxPixeles in intArrayOf(MAX_PIXELES, MAX_PIXELES / 2)) {
                try {
                    val views = RemoteViews(context.packageName, R.layout.jesus_widget)
                    val bitmap = ruta?.takeIf { File(it).exists() }?.let {
                        decodificar(it, (anchoDp * densidad).toInt(), (altoDp * densidad).toInt(), maxPixeles)
                    }
                    if (bitmap != null) {
                        views.setImageViewBitmap(R.id.widget_snapshot, bitmap)
                        views.setViewVisibility(R.id.widget_snapshot, View.VISIBLE)
                        views.setViewVisibility(R.id.widget_fallback, View.GONE)
                    } else {
                        views.setViewVisibility(R.id.widget_snapshot, View.GONE)
                        views.setViewVisibility(R.id.widget_fallback, View.VISIBLE)
                        respaldo(context, views, prefs, dia, maxPixeles / 3)
                    }
                    views.setContentDescription(
                        R.id.jesus_widget_container,
                        descripcion ?: "Racha de victoria. Toca para registrar tu día."
                    )

                    // Tap → registrar / ver el día en la app
                    val intent = Intent(context, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra("initial_route", "/daily-outcome")
                    }
                    val pendingIntent = PendingIntent.getActivity(
                        context, 1, intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.jesus_widget_container, pendingIntent)

                    appWidgetManager.updateAppWidget(appWidgetId, views)
                    return
                } catch (e: Exception) {
                    // Bitmap demasiado grande para el IPC: se intenta más chico.
                    e.printStackTrace()
                }
            }
        }

        /** Tarjeta nativa con el mismo estilo, mientras no hay imagen. */
        private fun respaldo(
            context: Context,
            views: RemoteViews,
            prefs: android.content.SharedPreferences,
            dia: String,
            maxPixeles: Int
        ) {
            val paleta = PaletaPapel.leer(prefs)
            views.setInt(R.id.widget_papel, "setColorFilter", paleta.papel)
            views.setInt(R.id.widget_sombra, "setColorFilter", paleta.sombra)

            val racha = prefs.getInt(KEY_STREAK, 0)
            views.setTextViewText(R.id.widget_streak_number, racha.toString())
            views.setTextColor(R.id.widget_streak_number, paleta.terracota)
            views.setTextViewText(
                R.id.widget_streak_label,
                if (racha == 1) "día de\nvictoria" else "días de\nvictoria"
            )
            views.setTextColor(R.id.widget_streak_label, paleta.tinta)

            val hoy = dia == "hoy"
            val completado = hoy && prefs.getBoolean(KEY_COMPLETED, false)
            val mensaje = if (hoy) prefs.getString(KEY_MESSAGE, null) else null
            views.setTextViewText(R.id.widget_message, mensaje ?: "¡Empieza hoy!")
            views.setTextColor(R.id.widget_message, paleta.tinta)

            val boton = if (hoy) prefs.getString(KEY_BADGE_TEXT, null) else null
            views.setTextViewText(R.id.widget_badge, boton ?: "Registrar día")
            val colorBoton = if (completado) paleta.azul else paleta.terracota
            views.setTextColor(R.id.widget_badge, paleta.papel)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                views.setColorStateList(
                    R.id.widget_badge, "setBackgroundTintList", ColorStateList.valueOf(colorBoton)
                )
            }

            prefs.getString(KEY_SPRITE_PATH, null)?.takeIf { File(it).exists() }?.let { ruta ->
                decodificar(ruta, 300, 400, maxPixeles)?.let {
                    views.setImageViewBitmap(R.id.widget_jesus_image, it)
                }
            }
        }

        /**
         * Decodifica [ruta] al tamaño del widget (sin pasar de [maxPixeles]),
         * con filtrado bilineal para que se vea nítido.
         */
        private fun decodificar(ruta: String, anchoPx: Int, altoPx: Int, maxPixeles: Int): Bitmap? {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(ruta, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

            // Encajar la imagen (fitCenter) en el widget y respetar el tope.
            val proporcion = bounds.outWidth.toFloat() / bounds.outHeight
            var w = anchoPx.coerceAtLeast(1).toFloat()
            var h = w / proporcion
            if (h > altoPx.coerceAtLeast(1)) {
                h = altoPx.coerceAtLeast(1).toFloat()
                w = h * proporcion
            }
            if (w * h > maxPixeles) {
                val f = sqrt(maxPixeles / (w * h))
                w *= f
                h *= f
            }
            val finalW = w.toInt().coerceIn(1, bounds.outWidth)
            val finalH = h.toInt().coerceIn(1, bounds.outHeight)

            var sample = 1
            while (bounds.outWidth / (sample * 2) >= finalW * 2 &&
                bounds.outHeight / (sample * 2) >= finalH * 2) {
                sample *= 2
            }
            val opts = BitmapFactory.Options().apply {
                inSampleSize = sample
                inPreferredConfig = Bitmap.Config.ARGB_8888
                inScaled = false
            }
            val raw = BitmapFactory.decodeFile(ruta, opts) ?: return null
            if (raw.width == finalW && raw.height == finalH) return raw
            val scaled = Bitmap.createScaledBitmap(raw, finalW, finalH, true)
            if (scaled !== raw) raw.recycle()
            return scaled
        }
    }
}
