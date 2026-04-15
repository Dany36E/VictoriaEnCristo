package com.example.app_quitar

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.File

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
        private const val KEY_SPRITE_PATH = "jesus_sprite_path"
        private const val KEY_BG_PATH = "jesus_bg_path"

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

                // ─── Cargar sprite de Jesús (escalado) ───
                val spritePath = prefs.getString(KEY_SPRITE_PATH, null)
                if (spritePath != null) {
                    val spriteFile = File(spritePath)
                    if (spriteFile.exists()) {
                        val bitmap = decodeSampledBitmap(spritePath, 400, 400)
                        if (bitmap != null) {
                            views.setImageViewBitmap(R.id.widget_jesus_image, bitmap)
                        }
                    }
                }

                // ─── Cargar fondo dinámico (escalado) ───
                val bgPath = prefs.getString(KEY_BG_PATH, null)
                if (bgPath != null) {
                    val bgFile = File(bgPath)
                    if (bgFile.exists()) {
                        val bitmap = decodeSampledBitmap(bgPath, 800, 800)
                        if (bitmap != null) {
                            views.setImageViewBitmap(R.id.widget_bg_image, bitmap)
                        }
                    }
                }

                // Número de racha
                views.setTextViewText(R.id.widget_streak_number, streakDays.toString())

                // Número siempre blanco — el color queda en el fondo/contexto
                views.setTextColor(R.id.widget_streak_number, 0xFFFFFFFF.toInt())

                // Mensaje
                views.setTextViewText(R.id.widget_message, message)

                // Badge de estado (con hora del día)
                val hour = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)
                val badgeText: String
                val badgeColor: Int
                when {
                    completedToday -> {
                        badgeText = "✓ Día de victoria"
                        badgeColor = 0xFF66BB6A.toInt()
                    }
                    hour >= 18 && streakDays > 0 -> {
                        badgeText = "⚔ Registra tu victoria"
                        badgeColor = 0xFFD4AF37.toInt()
                    }
                    streakDays > 0 -> {
                        badgeText = "⚔ En batalla"
                        badgeColor = 0xFFFFA726.toInt()
                    }
                    else -> {
                        badgeText = "Empieza hoy"
                        badgeColor = 0xFF9E9E9E.toInt()
                    }
                }

                // Mensaje con contexto de hora si Flutter no lo actualizó
                val timeMessage = when {
                    completedToday -> message
                    hour < 6  -> "Descansa en paz, Dios vela por ti"
                    hour < 12 -> "Buenos días. Hoy es un día de victoria"
                    hour < 18 -> "Sigue firme. Tu victoria se acerca"
                    else      -> "Es hora de registrar tu victoria"
                }
                views.setTextViewText(R.id.widget_message, timeMessage)

                views.setTextViewText(R.id.widget_badge, badgeText)
                views.setTextColor(R.id.widget_badge, badgeColor)

                // Label días — uppercase apilado
                views.setTextViewText(
                    R.id.widget_streak_label,
                    if (streakDays == 1) "DÍA" else "DÍAS"
                )
                views.setTextViewText(R.id.widget_streak_sublabel, "DE VICTORIA")

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

            try {
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                // Si aún excede memoria, enviar vista sin imágenes
                val fallback = RemoteViews(context.packageName, R.layout.jesus_widget)
                fallback.setTextViewText(R.id.widget_streak_number, "0")
                fallback.setTextViewText(R.id.widget_message, "Abre la app")
                fallback.setTextViewText(R.id.widget_badge, "Empieza hoy")
                appWidgetManager.updateAppWidget(appWidgetId, fallback)
            }
        }

        private fun decodeSampledBitmap(path: String, reqWidth: Int, reqHeight: Int): Bitmap? {
            val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, options)
            options.inSampleSize = calculateInSampleSize(options, reqWidth, reqHeight)
            options.inJustDecodeBounds = false
            return BitmapFactory.decodeFile(path, options)
        }

        private fun calculateInSampleSize(options: BitmapFactory.Options, reqWidth: Int, reqHeight: Int): Int {
            val (height, width) = options.outHeight to options.outWidth
            var inSampleSize = 1
            if (height > reqHeight || width > reqWidth) {
                val halfHeight = height / 2
                val halfWidth = width / 2
                while (halfHeight / inSampleSize >= reqHeight && halfWidth / inSampleSize >= reqWidth) {
                    inSampleSize *= 2
                }
            }
            return inSampleSize
        }
    }
}
