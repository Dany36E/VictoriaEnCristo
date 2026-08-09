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
import java.net.InetAddress
import java.nio.ByteBuffer

/**
 * Escudo de Pureza — VPN local que filtra DNS para bloquear contenido adulto.
 *
 * Sólo captura tráfico DNS (enruta una IP virtual de DNS al túnel). Para cada
 * consulta:
 *   - Si el dominio está en la lista de bloqueo → responde 0.0.0.0 (la web no
 *     carga en ningún navegador) y lanza la app en "Necesito Ayuda".
 *   - Si no → reenvía la consulta a un DNS real (Cloudflare) y devuelve la
 *     respuesta.
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
        private const val UPSTREAM_DNS = "1.1.1.1"

        @Volatile
        var isRunning: Boolean = false
            private set

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
        blocklist = set
    }

    private fun establishVpn() {
        val builder = Builder()
            .setSession("Escudo de Pureza")
            .addAddress(TUN_ADDRESS, 24)
            .addDnsServer(VIRTUAL_DNS)
            .addRoute(VIRTUAL_DNS, 32)
            .setBlocking(true)
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
        if (isBlocked(domain)) {
            val response = buildBlockedResponse(dns)
            if (response != null) {
                writeUdpPacket(output, dstIp, srcIp, dstPort, srcPort, response)
            }
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

    /** Reenvía la consulta DNS a un resolvedor real y entrega la respuesta. */
    private fun forwardDns(query: ByteArray, onReply: (ByteArray) -> Unit) {
        var socket: java.net.DatagramSocket? = null
        try {
            socket = java.net.DatagramSocket()
            protect(socket)
            socket.soTimeout = 4000
            val upstream = InetAddress.getByName(UPSTREAM_DNS)
            socket.send(java.net.DatagramPacket(query, query.size, upstream, 53))
            val respBuf = ByteArray(2048)
            val respPacket = java.net.DatagramPacket(respBuf, respBuf.size)
            socket.receive(respPacket)
            val reply = respBuf.copyOfRange(0, respPacket.length)
            onReply(reply)
        } catch (e: Exception) {
            Log.w(TAG, "forward error: ${e.message}")
        } finally {
            try { socket?.close() } catch (_: Exception) {}
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
