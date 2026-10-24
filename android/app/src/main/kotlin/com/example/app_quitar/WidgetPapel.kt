package com.example.app_quitar

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import java.util.Calendar
import java.util.Locale

/**
 * Colores del papel «Papel recortado» (VecPaleta en Flutter). La app guarda
 * los del papel activo en `vec_*` (ver WidgetSyncService.datosPaleta).
 */
data class PaletaPapel(
    val oscuro: Boolean,
    val papel: Int,
    val crema: Int,
    val tinta: Int,
    val gris: Int,
    val terracota: Int,
    val azul: Int,
) {
    /** Sombra sólida del papel grueso (VecSombras.papel). */
    val sombra: Int get() = if (oscuro) 0x59000000 else 0x2E2B2622

    companion object {
        val CLARO = PaletaPapel(
            oscuro = false,
            papel = 0xFFFBF7EE.toInt(),
            crema = 0xFFF3ECDF.toInt(),
            tinta = 0xFF2B2622.toInt(),
            gris = 0xFF6F6150.toInt(),
            terracota = 0xFFA8452F.toInt(),
            azul = 0xFF3D6890.toInt(),
        )
        val KRAFT = PaletaPapel(
            oscuro = true,
            papel = 0xFF3A2E24.toInt(),
            crema = 0xFF2A2119.toInt(),
            tinta = 0xFFF3ECDF.toInt(),
            gris = 0xFFD0BEA2.toInt(),
            terracota = 0xFFEF9274.toInt(),
            azul = 0xFF9CBDE0.toInt(),
        )

        /** El papel activo de la app; claro si la app aún no lo guardó. */
        fun leer(prefs: SharedPreferences): PaletaPapel {
            if (!prefs.contains("vec_papel")) return CLARO
            val base = if (prefs.getBoolean("vec_oscuro", false)) KRAFT else CLARO
            fun color(key: String, def: Int): Int = try {
                prefs.getString(key, null)?.let { Color.parseColor(it) } ?: def
            } catch (e: Exception) {
                def
            }
            return PaletaPapel(
                oscuro = prefs.getBoolean("vec_oscuro", false),
                papel = color("vec_papel", base.papel),
                crema = color("vec_crema", base.crema),
                tinta = color("vec_tinta", base.tinta),
                gris = color("vec_gris", base.gris),
                terracota = color("vec_terracota", base.terracota),
                azul = color("vec_azul", base.azul),
            )
        }
    }
}

/** Versículo de un día de la lista que guarda la app (`verse_widget_schedule`). */
data class VersiculoDia(
    val fecha: String,
    val texto: String,
    val cita: String,
    val version: String,
)

/**
 * Lógica de fechas de los widgets: elegir el versículo y la imagen del día
 * sin abrir la app, y volver a dibujarlos al cambiar el día.
 */
object WidgetDia {

    /** Fecha local en ISO (yyyy-MM-dd), igual que TimeUtils.dateToISO. */
    fun iso(cal: Calendar = Calendar.getInstance()): String = String.format(
        Locale.US, "%04d-%02d-%02d",
        cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1, cal.get(Calendar.DAY_OF_MONTH)
    )

    /**
     * El versículo de [hoy]: el de esa fecha, o si la lista ya se acabó (la
     * app lleva días sin abrirse) el último anterior. `null` si no hay
     * ninguno anterior o igual a [hoy].
     */
    fun elegirVersiculo(lista: List<VersiculoDia>, hoy: String): VersiculoDia? =
        lista.firstOrNull { it.fecha == hoy }
            ?: lista.filter { it.fecha < hoy }.maxByOrNull { it.fecha }

    fun parsearVersiculos(json: String?): List<VersiculoDia> {
        if (json.isNullOrBlank()) return emptyList()
        return try {
            val arr = JSONArray(json)
            (0 until arr.length()).mapNotNull { i ->
                val o = arr.optJSONObject(i) ?: return@mapNotNull null
                val texto = o.optString("t")
                if (texto.isBlank()) return@mapNotNull null
                VersiculoDia(o.optString("f"), texto, o.optString("r"), o.optString("v"))
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    /** Versículo de hoy según la lista guardada, o el último que mandó la app. */
    fun versiculoDeHoy(prefs: SharedPreferences): VersiculoDia {
        elegirVersiculo(parsearVersiculos(prefs.getString("verse_widget_schedule", null)), iso())
            ?.let { return it }
        return VersiculoDia(
            fecha = "",
            texto = prefs.getString("verse_widget_text", null)
                ?: "Todo lo puedo en Cristo que me fortalece.",
            cita = prefs.getString("verse_widget_reference", null) ?: "Filipenses 4:13",
            version = prefs.getString("verse_widget_version", null) ?: "",
        )
    }

    /**
     * Qué imagen de la tarjeta de racha usar: «hoy» si la dibujó la app hoy
     * (o el reloj va atrás), «manana» si ya cambió el día (día sin registrar).
     */
    fun diaImagenJesus(fechaImagen: String?, hoy: String): String =
        if (fechaImagen.isNullOrBlank() || hoy <= fechaImagen) "hoy" else "manana"

    /** «ancha» (4×2) o «alta» (3×3) según la proporción del widget. */
    fun formaImagen(anchoDp: Int, altoDp: Int): String =
        if (altoDp <= 0 || anchoDp.toFloat() / altoDp >= 1.45f) "ancha" else "alta"

    /** Primer minuto del día siguiente a [ahora] (milisegundos). */
    fun siguienteMedianoche(ahora: Calendar): Long {
        val c = ahora.clone() as Calendar
        c.add(Calendar.DAY_OF_MONTH, 1)
        c.set(Calendar.HOUR_OF_DAY, 0)
        c.set(Calendar.MINUTE, 1)
        c.set(Calendar.SECOND, 0)
        c.set(Calendar.MILLISECOND, 0)
        return c.timeInMillis
    }

    /** Vuelve a dibujar los widgets que dependen del día. */
    fun actualizarTodos(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        fun ids(cls: Class<*>) = manager.getAppWidgetIds(ComponentName(context, cls))
        ids(JesusWidgetProvider::class.java).forEach {
            JesusWidgetProvider.updateWidget(context, manager, it)
        }
        ids(VerseOfDayWidgetProvider::class.java).forEach {
            VerseOfDayWidgetProvider.updateAppWidget(context, manager, it)
        }
        ids(VictoryWidget2x2Provider::class.java).forEach {
            VictoryWidget2x2Provider.updateAppWidget(context, manager, it)
        }
    }

    /**
     * Alarma (no exacta, sin permisos especiales) para el primer minuto de
     * mañana: cambia el versículo y la tarjeta aunque la app no se abra.
     */
    fun programarMedianoche(context: Context) {
        try {
            val alarm = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, WidgetDiaReceiver::class.java)
                .setAction(WidgetDiaReceiver.ACCION_MEDIANOCHE)
            val pi = PendingIntent.getBroadcast(
                context, 7301, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarm.set(AlarmManager.RTC, siguienteMedianoche(Calendar.getInstance()), pi)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun prefs(context: Context): SharedPreferences = HomeWidgetPlugin.getData(context)
}

/**
 * Cambio de día, de hora o reinicio: vuelve a dibujar los widgets con el
 * versículo y la tarjeta del día.
 */
class WidgetDiaReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        WidgetDia.actualizarTodos(context)
        WidgetDia.programarMedianoche(context)
    }

    companion object {
        const val ACCION_MEDIANOCHE = "com.example.app_quitar.WIDGET_MEDIANOCHE"
    }
}
