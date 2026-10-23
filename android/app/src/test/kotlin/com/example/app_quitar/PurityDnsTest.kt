package com.example.app_quitar

import java.io.ByteArrayOutputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class PurityDnsTest {

    // ── Utilidades: consultas como las de Android y un lector independiente ──

    private fun query(name: String, type: Int, id: Int = 0x1234): ByteArray {
        val out = ByteArrayOutputStream()
        out.write(id ushr 8); out.write(id and 0xFF)
        out.write(0x01); out.write(0x00)             // RD
        out.write(0); out.write(1)                   // QDCOUNT
        repeat(6) { out.write(0) }
        for (label in name.split('.')) {
            out.write(label.length); out.write(label.toByteArray())
        }
        out.write(0)
        out.write(type ushr 8); out.write(type and 0xFF)
        out.write(0); out.write(1)                   // IN
        return out.toByteArray()
    }

    /** Respuesta de un servidor real: nombres de respuesta comprimidos (C0 0C). */
    private fun upstreamReply(q: ByteArray, records: List<Pair<Int, ByteArray>>): ByteArray {
        val out = ByteArrayOutputStream()
        out.write(q, 0, 2)
        out.write(0x81); out.write(0x80)
        out.write(0); out.write(1)
        out.write(0); out.write(records.size)
        repeat(4) { out.write(0) }
        out.write(q, 12, q.size - 12)
        for ((type, rdata) in records) {
            out.write(0xC0); out.write(0x0C)
            out.write(type ushr 8); out.write(type and 0xFF)
            out.write(0); out.write(1)
            out.write(0); out.write(0); out.write(0x01); out.write(0x2C) // TTL 300
            out.write(rdata.size ushr 8); out.write(rdata.size and 0xFF)
            out.write(rdata)
        }
        return out.toByteArray()
    }

    private fun u16(m: ByteArray, p: Int) = ((m[p].toInt() and 0xFF) shl 8) or (m[p + 1].toInt() and 0xFF)

    /** Lee un nombre siguiendo punteros; devuelve (nombre, posición siguiente). */
    private fun readName(m: ByteArray, start: Int): Pair<String, Int> {
        val labels = mutableListOf<String>()
        var p = start
        var next = -1
        var jumps = 0
        while (true) {
            val len = m[p].toInt() and 0xFF
            if (len == 0) { if (next < 0) next = p + 1; break }
            if (len and 0xC0 == 0xC0) {
                if (next < 0) next = p + 2
                p = ((len and 0x3F) shl 8) or (m[p + 1].toInt() and 0xFF)
                check(++jumps < 10) { "bucle de punteros" }
                continue
            }
            labels.add(String(m, p + 1, len))
            p += len + 1
        }
        return labels.joinToString(".") to next
    }

    private data class Rr(val name: String, val type: Int, val ttl: Int, val rdata: ByteArray, val rdataPos: Int)

    /** Respuestas (sección answer) de un mensaje, validando los contadores. */
    private fun answers(m: ByteArray): List<Rr> {
        assertEquals("QDCOUNT", 1, u16(m, 4))
        var p = readName(m, 12).second + 4
        return (0 until u16(m, 6)).map {
            val (name, after) = readName(m, p)
            val type = u16(m, after)
            val ttl = java.nio.ByteBuffer.wrap(m, after + 4, 4).int
            val len = u16(m, after + 8)
            val rr = Rr(name, type, ttl, m.copyOfRange(after + 10, after + 10 + len), after + 10)
            p = after + 10 + len
            rr
        }.also { assertEquals("sin bytes sobrantes", m.size, p) }
    }

    private val safeIp = byteArrayOf(216.toByte(), 239.toByte(), 38, 120)
    private val safeIp6 = ByteArray(16) { (0x20 + it).toByte() }

    // ── Pruebas ──

    @Test
    fun parseDomain_leeElNombreEnMinusculas() {
        assertEquals("www.google.com", PurityDns.parseDomain(query("WWW.Google.com", 1)))
    }

    @Test
    fun bloqueoA_responde0000ConElMismoId() {
        val r = PurityDns.buildBlockedResponse(query("sitio.xxx", PurityDns.TYPE_A))!!
        assertEquals(0x1234, u16(r, 0))
        assertEquals(0x8180, u16(r, 2))
        val an = answers(r)
        assertEquals(1, an.size)
        assertEquals("sitio.xxx", an[0].name)
        assertArrayEquals(byteArrayOf(0, 0, 0, 0), an[0].rdata)
    }

    @Test
    fun bloqueoAAAA_respondeVacio() {
        val r = PurityDns.buildBlockedResponse(query("sitio.xxx", PurityDns.TYPE_AAAA))!!
        assertEquals(0, answers(r).size)
    }

    @Test
    fun consultaDelHostSeguro_mismoIdYTipo() {
        val sub = PurityDns.buildTargetQuery(query("www.google.com", 28, id = 0xBEEF), "forcesafesearch.google.com")!!
        assertEquals(0xBEEF, u16(sub, 0))
        assertEquals("forcesafesearch.google.com", PurityDns.parseDomain(sub))
        assertEquals(28, PurityDns.questionType(sub))
    }

    @Test
    fun safeSearchA_incluyeCnameYDireccion() {
        val q = query("www.google.com", PurityDns.TYPE_A)
        val target = "forcesafesearch.google.com"
        val reply = upstreamReply(PurityDns.buildTargetQuery(q, target)!!, listOf(PurityDns.TYPE_A to safeIp))
        val r = PurityDns.buildSafeSearchResponse(q, target, reply)!!

        assertEquals(0x1234, u16(r, 0))
        assertEquals("pregunta original", "www.google.com", readName(r, 12).first)
        val an = answers(r)
        assertEquals(2, an.size)
        assertEquals("www.google.com", an[0].name)
        assertEquals(PurityDns.TYPE_CNAME, an[0].type)
        assertEquals(target, readName(r, an[0].rdataPos).first)
        assertEquals(target, an[1].name)
        assertEquals(PurityDns.TYPE_A, an[1].type)
        assertEquals(300, an[1].ttl)
        assertArrayEquals(safeIp, an[1].rdata)
    }

    @Test
    fun safeSearchAAAA_ignoraOtrosTiposDeLaRespuesta() {
        val q = query("youtube.com", PurityDns.TYPE_AAAA)
        val target = "restrict.youtube.com"
        val reply = upstreamReply(
            PurityDns.buildTargetQuery(q, target)!!,
            listOf(PurityDns.TYPE_A to safeIp, PurityDns.TYPE_AAAA to safeIp6),
        )
        val an = answers(PurityDns.buildSafeSearchResponse(q, target, reply)!!)
        assertEquals(2, an.size)
        assertEquals(PurityDns.TYPE_AAAA, an[1].type)
        assertArrayEquals(safeIp6, an[1].rdata)
    }

    @Test
    fun safeSearchSinDirecciones_devuelveNull() {
        val q = query("www.bing.com", PurityDns.TYPE_A)
        val reply = upstreamReply(PurityDns.buildTargetQuery(q, "strict.bing.com")!!, emptyList())
        assertNull(PurityDns.buildSafeSearchResponse(q, "strict.bing.com", reply))
    }

    @Test
    fun mensajesTruncados_noRevientan() {
        assertNull(PurityDns.parseDomain(ByteArray(5)))
        assertNull(PurityDns.buildBlockedResponse(ByteArray(12)))
        assertNull(PurityDns.questionType(query("a.com", 1).copyOf(16)))
        val q = query("google.com", PurityDns.TYPE_A)
        assertNull(PurityDns.buildSafeSearchResponse(q, "forcesafesearch.google.com", ByteArray(8)))
        assertNotNull(PurityDns.buildTargetQuery(q, "forcesafesearch.google.com"))
    }
}
