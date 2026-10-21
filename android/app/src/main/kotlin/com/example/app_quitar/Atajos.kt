package com.example.app_quitar

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.os.Build
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

/**
 * Atajos elegidos en la app (AtajosService en Flutter). Los usan el widget
 * «Atajos» y los accesos al mantener presionado el ícono. Cada uno abre
 * MainActivity con la ruta /atajo/<id>, que Flutter resuelve en abrirAtajo().
 */
object Atajos {
    data class Atajo(val id: String, val titulo: String)

    // Key compartida con widget_sync_service.dart
    const val KEY_WIDGET = "atajos_widget_json"
    const val MAXIMO = 4

    /** Dibujo de cada atajo; las claves son los ids de AtajosService. */
    val dibujos = mapOf(
        "biblia" to R.drawable.atajo_biblia,
        "estudio" to R.drawable.atajo_estudio,
        "apuntes" to R.drawable.atajo_apuntes,
        "guardados" to R.drawable.atajo_guardados,
        "mapas" to R.drawable.atajo_mapas,
        "mapa_oracion" to R.drawable.atajo_mapa_oracion,
        "versiculos" to R.drawable.atajo_versiculos,
        "frasco" to R.drawable.atajo_frasco,
        "devocional" to R.drawable.atajo_devocional,
        "oraciones" to R.drawable.atajo_oraciones,
        "progreso" to R.drawable.atajo_progreso,
        "favoritos" to R.drawable.atajo_favoritos,
        "escuela" to R.drawable.atajo_escuela,
        "juegos" to R.drawable.atajo_juegos,
        "carrera" to R.drawable.atajo_carrera,
        "duelo" to R.drawable.atajo_duelo,
        "quien_soy" to R.drawable.atajo_quien_soy,
        "preguntas" to R.drawable.atajo_preguntas,
        "orden_biblia" to R.drawable.atajo_orden_biblia,
        "companero" to R.drawable.atajo_companero,
        "muro" to R.drawable.atajo_muro,
        "sos" to R.drawable.atajo_sos,
        "campanas" to R.drawable.atajo_campanas,
    )

    private val predeterminados = listOf(
        Atajo("biblia", "Biblia"),
        Atajo("estudio", "Estudio"),
        Atajo("apuntes", "Apuntes")
    )

    /** Atajos guardados por Flutter, o los predeterminados si no hay. */
    fun leer(context: Context): List<Atajo> {
        val json = HomeWidgetPlugin.getData(context).getString(KEY_WIDGET, null)
        return desdeJson(json).ifEmpty { predeterminados }
    }

    fun desdeJson(json: String?): List<Atajo> {
        if (json.isNullOrEmpty()) return emptyList()
        return try {
            val arreglo = JSONArray(json)
            (0 until arreglo.length())
                .map { arreglo.getJSONObject(it) }
                .map { Atajo(it.optString("id"), it.optString("titulo")) }
                .filter { it.id in dibujos && it.titulo.isNotEmpty() }
                .take(MAXIMO)
        } catch (e: Exception) {
            emptyList()
        }
    }

    /**
     * Intent propio por atajo: la acción distinta evita que Android
     * reutilice (y sobrescriba) el PendingIntent de otro widget.
     */
    fun intent(context: Context, id: String): Intent =
        Intent(context, MainActivity::class.java).apply {
            action = "${context.packageName}.ATAJO_$id"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("initial_route", "/atajo/$id")
        }

    fun pendingIntent(context: Context, id: String): PendingIntent =
        PendingIntent.getActivity(
            context,
            id.hashCode(),
            intent(context, id),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

    /** Accesos al mantener presionado el ícono de la app (Android 7.1+). */
    fun publicarAccesos(context: Context, atajos: List<Atajo>) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return
        val manager = context.getSystemService(ShortcutManager::class.java) ?: return
        val accesos = atajos
            .filter { it.id in dibujos }
            .take(minOf(MAXIMO, manager.maxShortcutCountPerActivity))
            .mapIndexed { i, atajo ->
                ShortcutInfo.Builder(context, "atajo_${atajo.id}")
                    .setShortLabel(atajo.titulo)
                    .setLongLabel(atajo.titulo)
                    .setIcon(Icon.createWithResource(context, dibujos.getValue(atajo.id)))
                    .setIntent(intent(context, atajo.id))
                    .setRank(i)
                    .build()
            }
        try {
            manager.setDynamicShortcuts(accesos)
        } catch (e: Exception) {
            // Android limita las actualizaciones en segundo plano; se
            // reintenta la próxima vez que la app sincronice los atajos.
            e.printStackTrace()
        }
    }
}
