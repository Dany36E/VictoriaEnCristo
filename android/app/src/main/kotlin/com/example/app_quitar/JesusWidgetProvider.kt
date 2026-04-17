package com.example.app_quitar

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Bundle
import android.util.TypedValue
import android.view.View
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

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        // Re-render when widget is resized
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onEnabled(context: Context) {}
    override fun onDisabled(context: Context) {}

    companion object {
        private const val KEY_STREAK = "jesus_streak_days"
        private const val KEY_COMPLETED = "jesus_completed_today"
        private const val KEY_MESSAGE = "jesus_widget_message"
        private const val KEY_SPRITE_PATH = "jesus_sprite_path"
        private const val KEY_BG_PATH = "jesus_bg_path"
        private const val KEY_BADGE_TEXT = "jesus_badge_text"
        private const val KEY_BADGE_COLOR = "jesus_badge_color"
        private const val KEY_STREAK_COLOR = "jesus_streak_color"
        private const val KEY_CHECKIN_DONE = "jesus_checkin_done"

        // Size breakpoints (dp)
        private const val COMPACT_WIDTH = 200   // 3×2 small
        private const val MEDIUM_WIDTH = 280    // 4×2
        private const val COMPACT_HEIGHT = 120  // 2-row

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.jesus_widget)

            // ─── Get widget dimensions for responsive sizing ───
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val widthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 180)
            val heightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 130)
            val isCompactW = widthDp < MEDIUM_WIDTH
            val isCompactH = heightDp < COMPACT_HEIGHT

            try {
                val prefs = HomeWidgetPlugin.getData(context)

                val streakDays = prefs.getInt(KEY_STREAK, 0)
                val completedToday = prefs.getBoolean(KEY_COMPLETED, false)
                val message = prefs.getString(KEY_MESSAGE, "¡Empieza hoy!") ?: "¡Empieza hoy!"

                // ─── Cargar sprite de Jesús ───
                // Resolución generosa: el widget puede escalar hasta 4x2 / 5x2
                // en launchers grandes. Con 300–400 px el sprite se ve borroso
                // (la paloma y detalles finos pierden nitidez). 720 px de lado
                // mantiene el sprite ntido en cualquier breakpoint.
                val spritePath = prefs.getString(KEY_SPRITE_PATH, null)
                if (spritePath != null) {
                    val spriteFile = File(spritePath)
                    if (spriteFile.exists()) {
                        val spriteSize = when {
                            isCompactH && isCompactW -> 480
                            isCompactW -> 560
                            else -> 720
                        }
                        val bitmap = decodeSampledBitmap(spritePath, spriteSize, spriteSize)
                        if (bitmap != null) {
                            views.setImageViewBitmap(R.id.widget_jesus_image, bitmap)
                        }
                    }
                }

                // ─── Cargar fondo dinámico ───
                // Subimos la resolución para evitar bordes borrosos.
                val bgPath = prefs.getString(KEY_BG_PATH, null)
                if (bgPath != null) {
                    val bgFile = File(bgPath)
                    if (bgFile.exists()) {
                        val bgW = if (isCompactW) 960 else 1280
                        val bgH = if (isCompactH) 480 else 640
                        val bitmap = decodeSampledBitmap(bgPath, bgW, bgH)
                        if (bitmap != null) {
                            views.setImageViewBitmap(R.id.widget_bg_image, bitmap)
                        }
                    }
                }

                // ─── Streak color (synced from Flutter) ───
                val streakColor = prefs.getLong(KEY_STREAK_COLOR, 0xFFFFFFFF).toInt()

                // ─── Número de racha — responsive font size ───
                views.setTextViewText(R.id.widget_streak_number, streakDays.toString())
                val numberSize = when {
                    isCompactH -> if (streakDays >= 100) 30f else 36f
                    isCompactW -> if (streakDays >= 100) 34f else 40f
                    else -> if (streakDays >= 100) 38f else 46f
                }
                views.setTextViewTextSize(R.id.widget_streak_number,
                    TypedValue.COMPLEX_UNIT_SP, numberSize)

                // Color del número: use streakColor but with shadow for contrast
                views.setTextColor(R.id.widget_streak_number, 0xFFFFFFFF.toInt())

                // ─── Icono fuego — tinted with streakColor ───
                views.setInt(R.id.widget_fire_icon, "setColorFilter", streakColor)
                val fireSize = if (isCompactH) 18f else 22f
                // Fire icon size via layout params isn't possible in RemoteViews,
                // but the vector drawable auto-scales

                // ─── DÍAS / DE VICTORIA labels ───
                views.setTextViewText(
                    R.id.widget_streak_label,
                    if (streakDays == 1) "DÍA" else "DÍAS"
                )
                views.setTextColor(R.id.widget_streak_label, streakColor)

                val labelSize = if (isCompactW) 10f else 11f
                views.setTextViewTextSize(R.id.widget_streak_label,
                    TypedValue.COMPLEX_UNIT_SP, labelSize)

                views.setTextViewText(R.id.widget_streak_sublabel, "DE VICTORIA")
                views.setTextColor(R.id.widget_streak_sublabel, 0x99FFFFFF.toInt())

                val sublabelSize = if (isCompactW) 7f else 8f
                views.setTextViewTextSize(R.id.widget_streak_sublabel,
                    TypedValue.COMPLEX_UNIT_SP, sublabelSize)

                // Hide DE VICTORIA when very compact
                if (isCompactH) {
                    views.setViewVisibility(R.id.widget_streak_sublabel, View.GONE)
                } else {
                    views.setViewVisibility(R.id.widget_streak_sublabel, View.VISIBLE)
                }

                // ─── Badge "✓ Hoy" ───
                if (completedToday) {
                    views.setViewVisibility(R.id.widget_hoy_badge, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_hoy_badge, View.GONE)
                }

                // ─── Mensaje motivacional ───
                views.setTextViewText(R.id.widget_message, message)
                val msgSize = if (isCompactW) 11f else 12f
                views.setTextViewTextSize(R.id.widget_message,
                    TypedValue.COMPLEX_UNIT_SP, msgSize)

                // ─── Botón de acción (siempre dorado) ───
                val badgeText = prefs.getString(KEY_BADGE_TEXT, null)
                val checkinDone = prefs.getBoolean(KEY_CHECKIN_DONE, false)
                val finalBadgeText = if (badgeText != null) {
                    badgeText
                } else {
                    val hour = java.util.Calendar.getInstance()
                        .get(java.util.Calendar.HOUR_OF_DAY)
                    when {
                        completedToday -> "✨ Ver mi progreso"
                        !completedToday && hour >= 18 -> "⚔️ Registrar victoria"
                        checkinDone && hour < 18 -> "🙏 Devocional hecho"
                        hour >= 15 -> "⏰ Casi es hora"
                        hour >= 12 -> "🛡️ En batalla"
                        hour >= 8  -> "💪 Sigue firme"
                        hour >= 5  -> "☀️ Buenos días"
                        else -> "🌙 Descansa en paz"
                    }
                }
                views.setTextViewText(R.id.widget_badge, finalBadgeText)
                views.setTextColor(R.id.widget_badge, 0xFFD4AF37.toInt())
                val badgeSize = if (isCompactW) 11f else 12f
                views.setTextViewTextSize(R.id.widget_badge,
                    TypedValue.COMPLEX_UNIT_SP, badgeSize)

                // Hide button when very compact height
                if (isCompactH) {
                    views.setViewVisibility(R.id.widget_badge, View.GONE)
                } else {
                    views.setViewVisibility(R.id.widget_badge, View.VISIBLE)
                }

                // ─── Tap → abre la app ───
                val intent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context, 1, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.jesus_widget_container, pendingIntent)

            } catch (e: Exception) {
                views.setTextViewText(R.id.widget_streak_number, "0")
                views.setTextViewText(R.id.widget_message, "Abre la app")
                views.setTextViewText(R.id.widget_badge, "Empieza hoy")
            }

            try {
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
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
            // Mejor calidad + sin pre-escalado automático: el ImageView
            // se encarga del scaling final con filtrado bilineal.
            options.inPreferredConfig = Bitmap.Config.ARGB_8888
            options.inScaled = false
            return BitmapFactory.decodeFile(path, options)
        }

        private fun calculateInSampleSize(
            options: BitmapFactory.Options,
            reqWidth: Int,
            reqHeight: Int
        ): Int {
            val (height, width) = options.outHeight to options.outWidth
            var inSampleSize = 1
            if (height > reqHeight || width > reqWidth) {
                val halfHeight = height / 2
                val halfWidth = width / 2
                while (halfHeight / inSampleSize >= reqHeight &&
                       halfWidth / inSampleSize >= reqWidth) {
                    inSampleSize *= 2
                }
            }
            return inSampleSize
        }
    }
}
