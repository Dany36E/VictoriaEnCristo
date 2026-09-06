package com.example.app_quitar

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.nio.ByteBuffer

/**
 * Escudo de Pureza — VPN local que filtra DNS para bloquear contenido adulto.
 *
 * Sólo captura tráfico DNS (enruta una IP virtual de DNS al túnel). Para cada
 * consulta:
 *   - Si el dominio está en la lista de bloqueo → responde 0.0.0.0 (la web no
 *     carga en ningún navegador) y lanza la app en "Necesito Ayuda".
 *   - Si no → la consulta viaja cifrada por DNS-over-HTTPS al filtro familiar
 *     de CleanBrowsing y se devuelve la respuesta.
 *
 * No envía tráfico del usuario a ningún servidor propio; todo el filtrado es
 * local en el dispositivo. Sólo IPv4/UDP (suficiente para la mayoría de redes).
 */
class PurityVpnService : VpnService() {

    companion object {
        const val ACTION_START = "com.example.app_quitar.PURITY_START"
        const val ACTION_STOP = "com.example.app_quitar.PURITY_STOP"

        private const val TAG = "PurityVpn"
        private const val CHANNEL_ID = "purity_guard"
        private const val NOTIF_ID = 7712

        // Subred privada del túnel. El dispositivo envía DNS a VIRTUAL_DNS.
        private const val TUN_ADDRESS = "10.111.222.1"
        private const val VIRTUAL_DNS = "10.111.222.2"
        // DNS familiar de CleanBrowsing por HTTPS: además de filtrar dominios
        // nuevos, cifra las consultas DNS que salen del dispositivo.
        private const val UPSTREAM_DOH =
            "https://doh.cleanbrowsing.org/doh/family-filter/"

        // Resolvedores DoH/DNS públicos conocidos. Se rutean al túnel: su DNS
        // clásico (UDP 53) se filtra y su DoH (TCP 443) se descarta, forzando al
        // navegador a caer en el DNS filtrado local.
        private val DOH_IPS = listOf(
            "1.1.1.1", "1.0.0.1", "1.1.1.2", "1.1.1.3",       // Cloudflare
            "8.8.8.8", "8.8.4.4",                               // Google
            "9.9.9.9", "149.112.112.112",                      // Quad9
            "208.67.222.222", "208.67.220.220",                // OpenDNS
            "94.140.14.14", "94.140.15.15",                    // AdGuard
            "76.76.2.0", "76.76.10.0",                         // Control D
            "185.228.168.9", "185.228.169.9",                  // CleanBrowsing
            "45.90.28.0", "45.90.30.0",                        // NextDNS
        )

        // Hostnames de arranque (bootstrap) de proveedores DoH. Al bloquear su
        // resolución, el navegador no puede activar DNS-over-HTTPS.
        private val DOH_HOSTNAMES = listOf(
            "dns.google", "dns64.dns.google",
            "cloudflare-dns.com", "mozilla.cloudflare-dns.com",
            "chrome.cloudflare-dns.com", "security.cloudflare-dns.com",
            "family.cloudflare-dns.com", "one.one.one.one",
            "dns.quad9.net", "dns9.quad9.net", "dns.quad9.net.",
            "doh.opendns.com", "doh.familyshield.opendns.com",
            "dns.adguard.com", "dns-family.adguard.com", "dns.adguard-dns.com",
            "family.adguard-dns.com", "dns.nextdns.io",
            "doh.cleanbrowsing.org", "doh.dns.sb", "dns.dns.sb",
            "doh.mullvad.net", "doh.controld.com", "freedns.controld.com",
        )

        // Fuerza SafeSearch: el dominio (clave) se responde con un CNAME al host
        // seguro (valor); el cliente re-resuelve y obtiene la versión filtrada.
        private val SAFE_SEARCH = mapOf(
            "www.google.com" to "forcesafesearch.google.com",
            "google.com" to "forcesafesearch.google.com",
            "www.bing.com" to "strict.bing.com",
            "bing.com" to "strict.bing.com",
            "www.youtube.com" to "restrict.youtube.com",
            "m.youtube.com" to "restrict.youtube.com",
            "youtube.com" to "restrict.youtube.com",
            "youtubei.googleapis.com" to "restrict.youtube.com",
            "youtube.googleapis.com" to "restrict.youtube.com",
            "www.youtube-nocookie.com" to "restrict.youtube.com",
            "duckduckgo.com" to "safe.duckduckgo.com",
            "www.duckduckgo.com" to "safe.duckduckgo.com",
        )

        @Volatile
        var isRunning: Boolean = false
            private set

        /** Estadísticas de bloqueos: total histórico y del día. */
        fun blockStats(context: Context): Map<String, Int> {
            return try {
                val prefs = context.getSharedPreferences("purity_stats", Context.MODE_PRIVATE)
                val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
                    .format(java.util.Date())
                val todayCount = if (prefs.getString("day", "") == today)
                    prefs.getInt("todayCount", 0) else 0
                mapOf("total" to prefs.getInt("total", 0), "today" to todayCount)
            } catch (e: Exception) {
                mapOf("total" to 0, "today" to 0)
            }
        }

        /** Cuenta los dominios en el asset de bloqueo (para la UI). */
        fun blocklistCount(context: Context): Int {
            return try {
                context.assets.open("purity_blocklist.txt").bufferedReader().use { r ->
                    var n = 0
                    while (r.readLine() != null) n++
                    n
                }
            } catch (e: Exception) {
                0
            }
        }
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var worker: Thread? = null
    @Volatile private var blocklist: HashSet<String> = HashSet()
    @Volatile private var lastRedirectMs: Long = 0L

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopEverything()
                return START_NOT_STICKY
            }
            else -> {
                startBlocker()
                return START_STICKY
            }
        }
    }

    private fun startBlocker() {
        if (isRunning) return
        try {
            loadBlocklist()
            startForegroundNotification()
            establishVpn()
            isRunning = true
            worker = Thread({ runLoop() }, "PurityVpnWorker").apply { start() }
            Log.i(TAG, "Escudo de Pureza activo (${blocklist.size} dominios)")
        } catch (e: Exception) {
            Log.e(TAG, "No se pudo iniciar la VPN", e)
            stopEverything()
        }
    }

    private fun loadBlocklist() {
        val set = HashSet<String>(90000)
        try {
            assets.open("purity_blocklist.txt").bufferedReader().use { reader ->
                reader.forEachLine { line ->
                    val d = line.trim().lowercase()
                    if (d.isNotEmpty() && !d.startsWith("#")) set.add(d)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error cargando blocklist", e)
        }
        // Añade los hostnames DoH para impedir DNS-over-HTTPS.
        set.addAll(DOH_HOSTNAMES)
        blocklist = set
    }

    private fun establishVpn() {
        val builder = Builder()
            .setSession("Escudo de Pureza")
            .addAddress(TUN_ADDRESS, 24)
            .addDnsServer(VIRTUAL_DNS)
            .addRoute(VIRTUAL_DNS, 32)
            .setBlocking(true)
        // Rutea los resolvedores DoH conocidos al túnel: su DNS clásico se
        // filtra y su tráfico DoH (443) se descarta (no lo reenviamos).
        for (ip in DOH_IPS) {
            try {
                builder.addRoute(ip, 32)
            } catch (_: Exception) {
            }
        }
        // No filtrar la propia app.
        try {
            builder.addDisallowedApplication(packageName)
        } catch (_: Exception) {
        }
        vpnInterface = builder.establish()
    }

    private fun runLoop() {
        val fd = vpnInterface ?: return
        val input = FileInputStream(fd.fileDescriptor)
        val output = FileOutputStream(fd.fileDescriptor)
        val packet = ByteArray(32767)
        while (isRunning) {
            try {
                val length = input.read(packet)
                if (length <= 0) continue
                handlePacket(packet, length, output)
            } catch (e: Exception) {
                if (isRunning) Log.w(TAG, "loop error: ${e.message}")
            }
        }
    }

    /** Procesa un paquete IPv4/UDP que llega al túnel (debe ser DNS). */
    private fun handlePacket(packet: ByteArray, length: Int, output: FileOutputStream) {
        if (length < 28) return
        val version = (packet[0].toInt() and 0xF0) ushr 4
        if (version != 4) return
        val ihl = (packet[0].toInt() and 0x0F) * 4
        val protocol = packet[9].toInt() and 0xFF
        if (protocol != 17) return // sólo UDP

        val srcIp = packet.copyOfRange(12, 16)
        val dstIp = packet.copyOfRange(16, 20)
        val udpStart = ihl
        val srcPort = ((packet[udpStart].toInt() and 0xFF) shl 8) or (packet[udpStart + 1].toInt() and 0xFF)
        val dstPort = ((packet[udpStart + 2].toInt() and 0xFF) shl 8) or (packet[udpStart + 3].toInt() and 0xFF)
        if (dstPort != 53) return

        val dnsStart = udpStart + 8
        if (dnsStart >= length) return
        val dns = packet.copyOfRange(dnsStart, length)

        val domain = parseDomain(dns) ?: return

        // 1) Forzar SafeSearch (Google/YouTube/Bing/DuckDuckGo).
        val safeTarget = SAFE_SEARCH[domain]
        if (safeTarget != null) {
            val response = buildCnameResponse(dns, safeTarget)
            if (response != null) {
                writeUdpPacket(output, dstIp, srcIp, dstPort, srcPort, response)
            }
            return
        }

        // 2) Bloquear contenido adulto.
        if (isBlocked(domain)) {
            val response = buildBlockedResponse(dns)
            if (response != null) {
                writeUdpPacket(output, dstIp, srcIp, dstPort, srcPort, response)
            }
            recordBlock()
            triggerRedirect()
        } else {
            forwardDns(dns) { reply ->
                writeUdpPacket(output, dstIp, srcIp, dstPort, srcPort, reply)
            }
        }
    }

    /** Extrae el nombre de dominio (QNAME) de un mensaje DNS. */
    private fun parseDomain(dns: ByteArray): String? {
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

    /** True si el dominio o alguno de sus dominios padre está en la lista. */
    private fun isBlocked(domain: String): Boolean {
        if (blocklist.contains(domain)) return true
        var idx = domain.indexOf('.')
        var d = domain
        while (idx != -1) {
            d = d.substring(idx + 1)
            if (blocklist.contains(d)) return true
            idx = d.indexOf('.')
        }
        return false
    }

    /** Respuesta DNS con A → 0.0.0.0 para consultas A; NOERROR sin respuesta si no. */
    private fun buildBlockedResponse(query: ByteArray): ByteArray? {
        if (query.size < 12) return null
        // Detectar qtype (al final de la sección question).
        var pos = 12
        while (pos < query.size) {
            val len = query[pos].toInt() and 0xFF
            if (len == 0) { pos++; break }
            pos += len + 1
        }
        if (pos + 4 > query.size) return null
        val qtype = ((query[pos].toInt() and 0xFF) shl 8) or (query[pos + 1].toInt() and 0xFF)
        val questionEnd = pos + 4

        val isA = qtype == 1
        val out = ByteBuffer.allocate(questionEnd + if (isA) 16 else 0)
        // Header
        out.put(query[0]); out.put(query[1]) // ID
        out.put(0x81.toByte()); out.put(0x80.toByte()) // flags: response + RA
        out.put(0x00); out.put(0x01) // QDCOUNT = 1
        if (isA) { out.put(0x00); out.put(0x01) } else { out.put(0x00); out.put(0x00) } // ANCOUNT
        out.put(0x00); out.put(0x00) // NSCOUNT
        out.put(0x00); out.put(0x00) // ARCOUNT
        // Question (copiada tal cual)
        out.put(query, 12, questionEnd - 12)
        if (isA) {
            out.put(0xC0.toByte()); out.put(0x0C.toByte()) // name pointer -> 0x0C
            out.put(0x00); out.put(0x01) // type A
            out.put(0x00); out.put(0x01) // class IN
            out.put(0x00); out.put(0x00); out.put(0x00); out.put(0x3C) // TTL 60s
            out.put(0x00); out.put(0x04) // RDLENGTH 4
            out.put(0x00); out.put(0x00); out.put(0x00); out.put(0x00) // 0.0.0.0
        }
        return out.array()
    }

    /** Respuesta DNS con un CNAME que apunta al host seguro (SafeSearch). */
    private fun buildCnameResponse(query: ByteArray, target: String): ByteArray? {
        if (query.size < 12) return null
        var pos = 12
        while (pos < query.size) {
            val len = query[pos].toInt() and 0xFF
            if (len == 0) { pos++; break }
            pos += len + 1
        }
        if (pos + 4 > query.size) return null
        val questionEnd = pos + 4
        val rdata = encodeDomain(target)

        val out = ByteBuffer.allocate(questionEnd + 12 + rdata.size)
        out.put(query[0]); out.put(query[1])           // ID
        out.put(0x81.toByte()); out.put(0x80.toByte()) // flags: response + RA
        out.put(0x00); out.put(0x01)                   // QDCOUNT
        out.put(0x00); out.put(0x01)                   // ANCOUNT = 1
        out.put(0x00); out.put(0x00)                   // NSCOUNT
        out.put(0x00); out.put(0x00)                   // ARCOUNT
        out.put(query, 12, questionEnd - 12)           // question
        out.put(0xC0.toByte()); out.put(0x0C.toByte()) // name pointer -> 0x0C
        out.put(0x00); out.put(0x05)                   // type CNAME
        out.put(0x00); out.put(0x01)                   // class IN
        out.put(0x00); out.put(0x00); out.put(0x00); out.put(0x3C) // TTL 60
        out.put((rdata.size ushr 8).toByte()); out.put((rdata.size and 0xFF).toByte())
        out.put(rdata)
        return out.array()
    }

    /** Codifica un dominio a formato DNS (labels con prefijo de longitud + 0). */
    private fun encodeDomain(domain: String): ByteArray {
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

    /** Registra un bloqueo (contadores total y del día) para la UI. */
    private fun recordBlock() {
        try {
            val prefs = getSharedPreferences("purity_stats", Context.MODE_PRIVATE)
            val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
                .format(java.util.Date())
            val total = prefs.getInt("total", 0) + 1
            val lastDay = prefs.getString("day", "") ?: ""
            val todayCount = if (lastDay == today) prefs.getInt("todayCount", 0) + 1 else 1
            prefs.edit()
                .putInt("total", total)
                .putString("day", today)
                .putInt("todayCount", todayCount)
                .apply()
        } catch (_: Exception) {
        }
    }

    /** Reenvía la consulta DNS cifrada con TLS (RFC 8484 wire format). */
    private fun forwardDns(query: ByteArray, onReply: (ByteArray) -> Unit) {
        var connection: HttpURLConnection? = null
        try {
            connection = (URL(UPSTREAM_DOH).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 5000
                readTimeout = 5000
                doOutput = true
                useCaches = false
                setRequestProperty("Content-Type", "application/dns-message")
                setRequestProperty("Accept", "application/dns-message")
                setFixedLengthStreamingMode(query.size)
            }
            connection.outputStream.use { it.write(query) }
            if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                Log.w(TAG, "DoH respondió HTTP ${connection.responseCode}")
                return
            }
            val contentType = connection.contentType.orEmpty().lowercase()
            if (!contentType.startsWith("application/dns-message")) {
                Log.w(TAG, "DoH respondió un tipo inesperado: $contentType")
                return
            }
            val reply = connection.inputStream.use { it.readBytes() }
            if (reply.size in 12..65535) onReply(reply)
        } catch (e: Exception) {
            Log.w(TAG, "DoH error: ${e.message}")
        } finally {
            connection?.disconnect()
        }
    }

    /** Construye un paquete IPv4/UDP y lo escribe al túnel. */
    private fun writeUdpPacket(
        output: FileOutputStream,
        srcIp: ByteArray,
        dstIp: ByteArray,
        srcPort: Int,
        dstPort: Int,
        payload: ByteArray,
    ) {
        try {
            val udpLen = 8 + payload.size
            val totalLen = 20 + udpLen
            val buf = ByteBuffer.allocate(totalLen)
            // IPv4 header
            buf.put(0x45) // version 4, IHL 5
            buf.put(0x00) // DSCP/ECN
            buf.putShort(totalLen.toShort())
            buf.putShort(0) // id
            buf.putShort(0x4000.toShort()) // flags: don't fragment
            buf.put(64) // TTL
            buf.put(17) // protocol UDP
            buf.putShort(0) // checksum placeholder
            buf.put(srcIp)
            buf.put(dstIp)
            // UDP header
            buf.putShort(srcPort.toShort())
            buf.putShort(dstPort.toShort())
            buf.putShort(udpLen.toShort())
            buf.putShort(0) // UDP checksum 0 (opcional en IPv4)
            buf.put(payload)

            val arr = buf.array()
            // Checksum de la cabecera IPv4
            val checksum = ipChecksum(arr, 0, 20)
            arr[10] = (checksum ushr 8).toByte()
            arr[11] = (checksum and 0xFF).toByte()

            output.write(arr)
            output.flush()
        } catch (e: Exception) {
            Log.w(TAG, "writePacket error: ${e.message}")
        }
    }

    private fun ipChecksum(data: ByteArray, offset: Int, length: Int): Int {
        var sum = 0L
        var i = offset
        val end = offset + length
        while (i + 1 < end) {
            sum += ((data[i].toInt() and 0xFF) shl 8) or (data[i + 1].toInt() and 0xFF)
            i += 2
        }
        if (i < end) sum += (data[i].toInt() and 0xFF) shl 8
        while (sum shr 16 != 0L) sum = (sum and 0xFFFF) + (sum shr 16)
        return (sum.inv() and 0xFFFF).toInt()
    }

    /** Lanza la app en "Necesito Ayuda" (throttled para no spamear). */
    private fun triggerRedirect() {
        val now = System.currentTimeMillis()
        if (now - lastRedirectMs < 8000) return
        lastRedirectMs = now
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("initial_route", "/emergency")
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.w(TAG, "redirect error: ${e.message}")
        }
    }

    private fun startForegroundNotification() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Escudo de Pureza",
                NotificationManager.IMPORTANCE_LOW,
            ).apply { description = "Protección de contenido activa" }
            nm.createNotificationChannel(channel)
        }
        val tapIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val pending = PendingIntent.getActivity(
            this, 0, tapIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification: Notification = builder
            .setContentTitle("Escudo de Pureza activo")
            .setContentText("Filtrando contenido adulto")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pending)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIF_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIF_ID, notification)
        }
    }

    private fun stopEverything() {
        isRunning = false
        try { worker?.interrupt() } catch (_: Exception) {}
        worker = null
        try { vpnInterface?.close() } catch (_: Exception) {}
        vpnInterface = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        stopEverything()
        super.onDestroy()
    }

    override fun onRevoke() {
        // El usuario revocó el permiso de VPN desde ajustes del sistema.
        stopEverything()
        super.onRevoke()
    }
}
