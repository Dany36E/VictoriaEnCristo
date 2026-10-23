package com.example.app_quitar

import java.nio.ByteBuffer

/**
 * Mensajes DNS del Escudo de Pureza (formato de red, RFC 1035). Sin Android
 * ni red: [PurityVpnService] los usa y se prueban en `PurityDnsTest`.
 */
object PurityDns {
    const val TYPE_A = 1
    const val TYPE_CNAME = 5
    const val TYPE_AAAA = 28

    /** Extrae el nombre de dominio (QNAME) de una consulta DNS. */
    fun parseDomain(dns: ByteArray): String? {
        if (dns.size < 13) return null
        var pos = 12 // saltar header (12 bytes)
        val sb = StringBuilder()
        while (pos < dns.size) {
            val len = dns[pos].toInt() and 0xFF
            if (len == 0) break
            if (len and 0xC0 != 0) return null // compresión no esperada en query
            pos++
            if (pos + len > dns.size) return null
            if (sb.isNotEmpty()) sb.append('.')
            for (i in 0 until len) {
                sb.append((dns[pos + i].toInt() and 0xFF).toChar())
            }
            pos += len
        }
        return if (sb.isEmpty()) null else sb.toString().lowercase()
    }

    /** Posición siguiente a un nombre DNS (etiquetas o puntero comprimido). */
    fun skipName(msg: ByteArray, start: Int): Int {
        var pos = start
        while (pos < msg.size) {
            val len = msg[pos].toInt() and 0xFF
            if (len == 0) return pos + 1
            if (len and 0xC0 == 0xC0) return pos + 2
            pos += len + 1
        }
        return -1
    }

    /** Tipo de la pregunta (QTYPE) de una consulta, o null si está mal formada. */
    fun questionType(query: ByteArray): Int? {
        val qEnd = skipName(query, 12)
        if (qEnd < 0 || qEnd + 4 > query.size) return null
        return ((query[qEnd].toInt() and 0xFF) shl 8) or (query[qEnd + 1].toInt() and 0xFF)
    }

    /** Respuesta DNS con A → 0.0.0.0 para consultas A; NOERROR sin respuesta si no. */
    fun buildBlockedResponse(query: ByteArray): ByteArray? {
        if (query.size < 12) return null
        val qEnd = skipName(query, 12)
        if (qEnd < 0 || qEnd + 4 > query.size) return null
        val qtype = questionType(query) ?: return null
        val questionEnd = qEnd + 4

        val isA = qtype == TYPE_A
        val out = ByteBuffer.allocate(questionEnd + if (isA) 16 else 0)
        out.put(query[0]); out.put(query[1])            // ID
        out.put(0x81.toByte()); out.put(0x80.toByte())  // flags: response + RA
        out.putShort(1)                                 // QDCOUNT
        out.putShort((if (isA) 1 else 0).toShort())     // ANCOUNT
        out.putShort(0); out.putShort(0)                // NS/AR
        out.put(query, 12, questionEnd - 12)            // question
        if (isA) {
            out.put(0xC0.toByte()); out.put(0x0C.toByte()) // name pointer -> 0x0C
            out.putShort(TYPE_A.toShort()); out.putShort(1)
            out.putInt(60)                              // TTL
            out.putShort(4)
            out.putInt(0)                               // 0.0.0.0
        }
        return out.array()
    }

    /** Codifica un dominio a formato DNS (labels con prefijo de longitud + 0). */
    fun encodeDomain(domain: String): ByteArray {
        val buf = ByteBuffer.allocate(domain.length + 2)
        for (label in domain.split('.')) {
            if (label.isEmpty()) continue
            buf.put(label.length.toByte())
            buf.put(label.toByteArray(Charsets.US_ASCII))
        }
        buf.put(0)
        val arr = ByteArray(buf.position())
        buf.flip()
        buf.get(arr)
        return arr
    }

    /** Consulta propia por [target] con el mismo ID y tipo que [query]. */
    fun buildTargetQuery(query: ByteArray, target: String): ByteArray? {
        val qtype = questionType(query) ?: return null
        val targetName = encodeDomain(target)
        val sub = ByteBuffer.allocate(12 + targetName.size + 4)
        sub.put(query[0]); sub.put(query[1])            // ID
        sub.put(0x01); sub.put(0x00)                    // flags: RD
        sub.putShort(1)                                 // QDCOUNT
        sub.put(ByteArray(6))                           // AN/NS/AR = 0
        sub.put(targetName)
        sub.putShort(qtype.toShort()); sub.putShort(1)  // class IN
        return sub.array()
    }

    /**
     * SafeSearch: responde a [query] con un CNAME a [target] seguido de las
     * direcciones de [target] tomadas de [targetReply] (la respuesta a
     * [buildTargetQuery]). Android no sigue un CNAME suelto: sin las
     * direcciones, Google y YouTube no cargaban. Null si no hay direcciones.
     */
    fun buildSafeSearchResponse(
        query: ByteArray,
        target: String,
        targetReply: ByteArray,
    ): ByteArray? {
        val qEnd = skipName(query, 12)
        if (qEnd < 0 || qEnd + 4 > query.size || targetReply.size < 12) return null
        val qtype = questionType(query) ?: return null
        val questionEnd = qEnd + 4

        // Direcciones (A o AAAA) de la respuesta.
        val records = mutableListOf<Pair<Int, ByteArray>>() // TTL, RDATA
        val anCount = ((targetReply[6].toInt() and 0xFF) shl 8) or
            (targetReply[7].toInt() and 0xFF)
        var pos = skipName(targetReply, 12)
        if (pos < 0) return null
        pos += 4
        for (i in 0 until anCount) {
            pos = skipName(targetReply, pos)
            if (pos < 0 || pos + 10 > targetReply.size) break
            val type = ((targetReply[pos].toInt() and 0xFF) shl 8) or
                (targetReply[pos + 1].toInt() and 0xFF)
            val ttl = ByteBuffer.wrap(targetReply, pos + 4, 4).int
            val rdLen = ((targetReply[pos + 8].toInt() and 0xFF) shl 8) or
                (targetReply[pos + 9].toInt() and 0xFF)
            pos += 10
            if (pos + rdLen > targetReply.size) break
            if (type == qtype && (rdLen == 4 || rdLen == 16)) {
                records.add(ttl to targetReply.copyOfRange(pos, pos + rdLen))
            }
            pos += rdLen
        }
        if (records.isEmpty()) return null

        val targetName = encodeDomain(target)
        val size = questionEnd + 12 + targetName.size + records.sumOf { 12 + it.second.size }
        val out = ByteBuffer.allocate(size)
        out.put(query[0]); out.put(query[1])            // ID
        out.put(0x81.toByte()); out.put(0x80.toByte())  // flags: response + RA
        out.putShort(1)                                 // QDCOUNT
        out.putShort((1 + records.size).toShort())      // ANCOUNT
        out.putShort(0); out.putShort(0)                // NS/AR
        out.put(query, 12, questionEnd - 12)            // question
        // CNAME pregunta → host seguro.
        out.put(0xC0.toByte()); out.put(0x0C.toByte())
        out.putShort(TYPE_CNAME.toShort()); out.putShort(1); out.putInt(60)
        out.putShort(targetName.size.toShort())
        val targetOffset = out.position()
        out.put(targetName)
        // Direcciones del host seguro (nombre: puntero al destino del CNAME).
        for ((ttl, rdata) in records) {
            out.putShort((0xC000 or targetOffset).toShort())
            out.putShort(qtype.toShort()); out.putShort(1)
            out.putInt(ttl.coerceIn(30, 3600))
            out.putShort(rdata.size.toShort())
            out.put(rdata)
        }
        return out.array()
    }
}
