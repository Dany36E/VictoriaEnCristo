package com.example.app_quitar

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.util.Calendar

class WidgetDiaTest {

    private fun v(fecha: String) = VersiculoDia(fecha, "texto $fecha", "Juan 3:16", "RVR1960")

    private val lista = listOf(v("2026-10-24"), v("2026-10-25"), v("2026-10-26"))

    @Test
    fun eligeElVersiculoDeLaFecha() {
        assertEquals("2026-10-25", WidgetDia.elegirVersiculo(lista, "2026-10-25")?.fecha)
    }

    @Test
    fun siLaListaSeAcaboUsaElUltimoAnterior() {
        assertEquals("2026-10-26", WidgetDia.elegirVersiculo(lista, "2026-11-30")?.fecha)
    }

    @Test
    fun sinVersiculoAnteriorDevuelveNull() {
        assertNull(WidgetDia.elegirVersiculo(lista, "2026-10-01"))
        assertNull(WidgetDia.elegirVersiculo(emptyList(), "2026-10-24"))
    }

    @Test
    fun imagenDeHoyOMananaSegunLaFecha() {
        assertEquals("hoy", WidgetDia.diaImagenJesus("2026-10-24", "2026-10-24"))
        assertEquals("manana", WidgetDia.diaImagenJesus("2026-10-24", "2026-10-25"))
        // Reloj hacia atrás o sin fecha: la de hoy.
        assertEquals("hoy", WidgetDia.diaImagenJesus("2026-10-24", "2026-10-23"))
        assertEquals("hoy", WidgetDia.diaImagenJesus(null, "2026-10-24"))
    }

    @Test
    fun formaSegunProporcion() {
        assertEquals("ancha", WidgetDia.formaImagen(320, 140))
        assertEquals("alta", WidgetDia.formaImagen(250, 250))
        assertEquals("ancha", WidgetDia.formaImagen(250, 0))
    }

    @Test
    fun isoConCeros() {
        val c = Calendar.getInstance().apply { set(2026, Calendar.MARCH, 5) }
        assertEquals("2026-03-05", WidgetDia.iso(c))
    }

    @Test
    fun medianocheEsElPrimerMinutoDeManana() {
        val ahora = Calendar.getInstance().apply { set(2026, Calendar.DECEMBER, 31, 23, 59, 0) }
        val c = Calendar.getInstance().apply { timeInMillis = WidgetDia.siguienteMedianoche(ahora) }
        assertEquals(2027, c.get(Calendar.YEAR))
        assertEquals(Calendar.JANUARY, c.get(Calendar.MONTH))
        assertEquals(1, c.get(Calendar.DAY_OF_MONTH))
        assertEquals(0, c.get(Calendar.HOUR_OF_DAY))
        assertEquals(1, c.get(Calendar.MINUTE))
    }
}
