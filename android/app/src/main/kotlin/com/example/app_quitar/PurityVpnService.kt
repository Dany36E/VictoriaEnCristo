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
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import org.json.JSONObject

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

        // Aviso al propio usuario cuando el Escudo se apaga sin que él lo pida.
        private const val ALERT_CHANNEL_ID = "purity_alerts"
        private const val ALERT_NOTIF_ID = 7713

        // Motivos que la app reporta (ver shield_status_service.dart).
        const val REASON_USER_OFF = "user_off"
        const val REASON_REVOKED = "revoked"
        const val REASON_STOPPED = "stopped"

        private const val EVENTS_PREFS = "purity_events"
        private const val STATS_PREFS = "purity_stats"
        private const val BY_DAY_KEEP = 14

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
        // seguro (valor) junto con sus direcciones. Android no sigue un CNAME
        // suelto: sin las direcciones, Google y YouTube no cargaban.
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

        private fun todayKey(): String =
            java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
                .format(java.util.Date())

        /**
         * Estadísticas de bloqueos: total histórico, del día y por día (últimas
         * dos semanas, solo cuentas; nunca qué sitio se bloqueó).
         */
        fun blockStats(context: Context): Map<String, Any> {
            return try {
                val prefs = context.getSharedPreferences(STATS_PREFS, Context.MODE_PRIVATE)
                val today = todayKey()
                val todayCount = if (prefs.getString("day", "") == today)
                    prefs.getInt("todayCount", 0) else 0
                val byDay = HashMap<String, Int>()
                try {
                    val json = JSONObject(prefs.getString("byDay", "{}") ?: "{}")
                    val keys = json.keys()
                    while (keys.hasNext()) {
                        val k = keys.next()
                        byDay[k] = json.optInt(k, 0)
                    }
                } catch (_: Exception) {
                }
                mapOf(
                    "total" to prefs.getInt("total", 0),
                    "today" to todayCount,
                    "byDay" to byDay,
                )
            } catch (e: Exception) {
                mapOf("total" to 0, "today" to 0, "byDay" to HashMap<String, Int>())
            }
        }

        /** Guarda un apagado del Escudo para reportarlo al abrir la app. */
        fun recordOff(context: Context, reason: String) {
            try {
                context.getSharedPreferences(EVENTS_PREFS, Context.MODE_PRIVATE).edit()
                    .putString("off_reason", reason)
                    .putLong("off_at", System.currentTimeMillis())
                    .apply()
            } catch (_: Exception) {
            }
        }

        /** Guarda un encendido del Escudo. */
        fun recordOn(context: Context) {
            try {
                context.getSharedPreferences(EVENTS_PREFS, Context.MODE_PRIVATE).edit()
                    .putLong("on_at", System.currentTimeMillis())
                    .apply()
            } catch (_: Exception) {
            }
        }

        /**
         * Devuelve y borra los cambios guardados (último apagado y último
         * encendido) o null si no hay nada pendiente.
         */
        fun consumeEvents(context: Context): Map<String, Any>? {
            return try {
                val prefs = context.getSharedPreferences(EVENTS_PREFS, Context.MODE_PRIVATE)
                val out = HashMap<String, Any>()
                val reason = prefs.getString("off_reason", null)
                val offAt = prefs.getLong("off_at", 0L)
                val onAt = prefs.getLong("on_at", 0L)
                if (reason != null && offAt > 0L) {
                    out["offReason"] = reason
                    out["offAt"] = offAt
                }
                if (onAt > 0L) out["onAt"] = onAt
                prefs.edit().clear().apply()
                if (out.isEmpty()) null else out
            } catch (e: Exception) {
                null
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
    // Una página hace decenas de consultas a la vez; de una en una, con
    // DoH de hasta 5 s cada una, la navegación se quedaba esperando.
    private var dnsPool: ExecutorService? = null
    private val writeLock = Any()
    // Evita registrar dos veces el mismo apagado (onRevoke → onDestroy).
    @Volatile private var offRecorded = false

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                // El usuario lo apagó desde la app (ya pasó la pausa o el PIN).
                if (isRunning) recordOffOnce(REASON_USER_OFF, notifyUser = false)
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
            dnsPool = Executors.newFixedThreadPool(8)
            isRunning = true
            offRecorded = false
            recordOn(this)
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

        val domain = PurityDns.parseDomain(dns) ?: return

        // 1) Bloquear contenido adulto (respuesta local, inmediata).
        if (isBlocked(domain)) {
            val response = PurityDns.buildBlockedResponse(dns)
            if (response != null) {
                writeUdpPacket(output, dstIp, srcIp, dstPort, srcPort, response)
            }
            recordBlock()
            triggerRedirect()
            return
        }

        // 2) SafeSearch (Google/YouTube/Bing/DuckDuckGo) o reenvío por DoH,
        // en paralelo para no frenar el resto de consultas.
        val safeTarget = SAFE_SEARCH[domain]
        val pool = dnsPool ?: return
        try {
            pool.execute {
                val reply = if (safeTarget != null) {
                    resolveSafeSearch(dns, safeTarget)
                } else {
                    queryDoh(dns)
                }
                if (reply != null && isRunning) {
                    writeUdpPacket(output, dstIp, srcIp, dstPort, srcPort, reply)
                }
            }
        } catch (_: Exception) {
            // Pool cerrado: el servicio se está deteniendo.
        }
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

    /**
     * SafeSearch: CNAME a [target] con sus direcciones (resueltas por DoH)
     * para consultas A/AAAA; otros tipos (p. ej. HTTPS) reciben una respuesta
     * vacía y el navegador usa A/AAAA.
     */
    private fun resolveSafeSearch(query: ByteArray, target: String): ByteArray? {
        val qtype = PurityDns.questionType(query) ?: return null
        if (qtype != PurityDns.TYPE_A && qtype != PurityDns.TYPE_AAAA) {
            return PurityDns.buildBlockedResponse(query)
        }
        val sub = PurityDns.buildTargetQuery(query, target) ?: return null
        val reply = queryDoh(sub) ?: return null
        return PurityDns.buildSafeSearchResponse(query, target, reply)
    }

    /** Registra un bloqueo (contadores total, del día y por día) para la UI. */
    private fun recordBlock() {
        try {
            val prefs = getSharedPreferences(STATS_PREFS, Context.MODE_PRIVATE)
            val today = todayKey()
            val total = prefs.getInt("total", 0) + 1
            val lastDay = prefs.getString("day", "") ?: ""
            val todayCount = if (lastDay == today) prefs.getInt("todayCount", 0) + 1 else 1
            // Por día: solo cuentas, últimas dos semanas.
            val byDay = try {
                JSONObject(prefs.getString("byDay", "{}") ?: "{}")
            } catch (_: Exception) {
                JSONObject()
            }
            byDay.put(today, byDay.optInt(today, 0) + 1)
            val keys = mutableListOf<String>()
            val iter = byDay.keys()
            while (iter.hasNext()) keys.add(iter.next())
            keys.sorted().dropLast(BY_DAY_KEEP).forEach { k -> byDay.remove(k) }
            prefs.edit()
                .putInt("total", total)
                .putString("day", today)
                .putInt("todayCount", todayCount)
                .putString("byDay", byDay.toString())
                .apply()
        } catch (_: Exception) {
        }
    }

    /**
     * Envía la consulta DNS cifrada con TLS (RFC 8484 wire format) y devuelve
     * la respuesta, o null si falló. Sin disconnect() en el caso normal, para
     * que la conexión HTTPS se reutilice entre consultas.
     */
    private fun queryDoh(query: ByteArray): ByteArray? {
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
                connection.disconnect()
                return null
            }
            val contentType = connection.contentType.orEmpty().lowercase()
            if (!contentType.startsWith("application/dns-message")) {
                Log.w(TAG, "DoH respondió un tipo inesperado: $contentType")
                connection.disconnect()
                return null
            }
            val reply = connection.inputStream.use { it.readBytes() }
            return if (reply.size in 12..65535) reply else null
        } catch (e: Exception) {
            Log.w(TAG, "DoH error: ${e.message}")
            connection?.disconnect()
            return null
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

            // Varios hilos responden a la vez: un paquete por escritura.
            synchronized(writeLock) {
                output.write(arr)
                output.flush()
            }
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
        try { dnsPool?.shutdownNow() } catch (_: Exception) {}
        dnsPool = null
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

    /**
     * Guarda el apagado para que la app lo reporte (y, si el usuario lo
     * activó, su compañero reciba un aviso). Si no lo pidió el usuario, le
     * avisa con una notificación para que pueda encenderlo de nuevo.
     */
    private fun recordOffOnce(reason: String, notifyUser: Boolean) {
        if (offRecorded) return
        offRecorded = true
        recordOff(this, reason)
        if (notifyUser) notifyShieldOff()
    }

    private fun notifyShieldOff() {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    ALERT_CHANNEL_ID,
                    "Avisos del Escudo",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ).apply { description = "Te avisa si el Escudo de Pureza se apaga" }
                nm.createNotificationChannel(channel)
            }
            val tapIntent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            val pending = PendingIntent.getActivity(
                this, 1, tapIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, ALERT_CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
            }
            val notification = builder
                .setContentTitle("Tu Escudo de Pureza se apagó")
                .setContentText("Toca para abrir la app y volver a encenderlo.")
                .setSmallIcon(android.R.drawable.ic_lock_lock)
                .setContentIntent(pending)
                .setAutoCancel(true)
                .build()
            nm.notify(ALERT_NOTIF_ID, notification)
        } catch (e: Exception) {
            Log.w(TAG, "notifyShieldOff error: ${e.message}")
        }
    }

    override fun onDestroy() {
        // Si llega aquí corriendo, el sistema lo detuvo (no fue el usuario).
        if (isRunning) recordOffOnce(REASON_STOPPED, notifyUser = true)
        stopEverything()
        super.onDestroy()
    }

    override fun onRevoke() {
        // El permiso de VPN se revocó (desde ajustes del sistema u otra VPN).
        if (isRunning) recordOffOnce(REASON_REVOKED, notifyUser = true)
        stopEverything()
        super.onRevoke()
    }
}
