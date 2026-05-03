package com.example.app_quitar

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.PowerManager
import android.provider.Settings

class SacredAlarmForegroundService : Service() {
    private var player: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var activeSessionId: String? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            val requestedSession = intent.getStringExtra(EXTRA_SESSION_ID)
            if (requestedSession == null || requestedSession == activeSessionId) {
                stopAlarm()
            }
            return START_NOT_STICKY
        }

        val extras = intent?.extras ?: Bundle.EMPTY
        val sessionId = extras.getString("id") ?: extras.getString(EXTRA_SESSION_ID) ?: "sacred-${System.currentTimeMillis()}"
        val title = extras.getString("title") ?: "Campana Sagrada"
        val body = extras.getString("body") ?: "Abre la app para completar este momento."
        val route = extras.getString("route") ?: "/sacred-alarm?sessionId=$sessionId"
        val asset = extras.getString("asset") ?: "flutter_assets/assets/sounds/Worship_pads.mp3"
        val enforceMinimumVolume = extras.getBoolean("enforceMinimumVolume", true)
        val minimumVolumePercent = when (val value = extras.get("minimumVolumePercent")) {
            is Number -> value.toInt()
            is String -> value.toIntOrNull() ?: 50
            else -> 50
        }

        activeSessionId = sessionId
        acquireWakeLock()
        startForeground(NOTIFICATION_ID, buildNotification(title, body, route))
        raiseAlarmVolumeIfNeeded(enforceMinimumVolume, minimumVolumePercent)
        startAudio(asset)
        return START_STICKY
    }

    override fun onDestroy() {
        stopAlarm()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(title: String, body: String, route: String): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("initial_route", route)
        }
        val contentIntent = PendingIntent.getActivity(
            this,
            73001,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder.setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setPriority(Notification.PRIORITY_MAX)
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOnlyAlertOnce(false)
            .build()
    }

    private fun startAudio(assetPath: String) {
        stopPlayerOnly()
        try {
            player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                isLooping = true
                try {
                    val afd = assets.openFd(assetPath)
                    setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    afd.close()
                } catch (_: Exception) {
                    val fallback = Settings.System.DEFAULT_ALARM_ALERT_URI
                    setDataSource(this@SacredAlarmForegroundService, fallback)
                }
                prepare()
                start()
            }
        } catch (_: Exception) {
            stopPlayerOnly()
        }
    }

    private fun raiseAlarmVolumeIfNeeded(enabled: Boolean, minimumPercent: Int) {
        if (!enabled) return
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            if (maxVolume <= 0) return
            val target = ((maxVolume * minimumPercent.coerceIn(30, 100)) / 100.0).toInt()
                .coerceAtLeast(1)
            val current = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
            if (current < target) {
                audioManager.setStreamVolume(AudioManager.STREAM_ALARM, target, 0)
            }
        } catch (_: Exception) {}
    }

    private fun stopAlarm() {
        stopPlayerOnly()
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
        activeSessionId = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun stopPlayerOnly() {
        player?.run {
            try {
                stop()
            } catch (_: Exception) {}
            release()
        }
        player = null
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "VictoriaEnCristo:SacredAlarm"
        ).apply {
            setReferenceCounted(false)
            acquire(10 * 60 * 1000L)
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Campanas Sagradas",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Alarmas espirituales que se apagan dentro de la app"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setSound(null, null)
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    companion object {
        private const val CHANNEL_ID = "sacred_alarms_active"
        private const val NOTIFICATION_ID = 73001
        private const val ACTION_STOP = "com.example.app_quitar.SACRED_ALARM_STOP"
        private const val EXTRA_SESSION_ID = "session_id"

        fun start(context: Context, extras: Bundle?) {
            val intent = Intent(context, SacredAlarmForegroundService::class.java).apply {
                extras?.let { putExtras(it) }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun start(context: Context, alarm: Map<String, Any?>) {
            val bundle = Bundle()
            alarm.forEach { (key, value) ->
                when (value) {
                    is String -> bundle.putString(key, value)
                    is Int -> bundle.putInt(key, value)
                    is Long -> bundle.putLong(key, value)
                    is Double -> bundle.putDouble(key, value)
                    is Boolean -> bundle.putBoolean(key, value)
                    is Number -> bundle.putLong(key, value.toLong())
                }
            }
            start(context, bundle)
        }

        fun stop(context: Context, sessionId: String?) {
            val intent = Intent(context, SacredAlarmForegroundService::class.java).apply {
                action = ACTION_STOP
                putExtra(EXTRA_SESSION_ID, sessionId)
            }
            context.startService(intent)
        }
    }
}