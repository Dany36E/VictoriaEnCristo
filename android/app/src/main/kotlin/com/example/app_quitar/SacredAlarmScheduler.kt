package com.example.app_quitar

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.abs

object SacredAlarmScheduler {
    private const val PREFS = "sacred_alarm_native"
    private const val KEY_ALARMS = "alarms_json"
    private const val ACTION_FIRE = "com.example.app_quitar.SACRED_ALARM_FIRE"

    fun schedule(context: Context, alarms: List<Map<String, Any?>>) {
        cancelAll(context)
        saveAlarms(context, alarms)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = System.currentTimeMillis()

        alarms.forEach { alarm ->
            val sessionId = alarm["id"] as? String ?: return@forEach
            val scheduledAtMs = (alarm["scheduledAtMs"] as? Number)?.toLong() ?: return@forEach
            if (scheduledAtMs < now) return@forEach

            val intent = Intent(context, SacredAlarmReceiver::class.java).apply {
                action = ACTION_FIRE
                putExtras(alarm.toBundle())
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCodeFor(sessionId),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            if (canScheduleExactAlarms(context)) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        scheduledAtMs,
                        pendingIntent
                    )
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, scheduledAtMs, pendingIntent)
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, scheduledAtMs, pendingIntent)
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, scheduledAtMs, pendingIntent)
            }
        }
    }

    fun cancelAll(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        loadAlarms(context).forEach { alarm ->
            val sessionId = alarm.optString("id")
            if (sessionId.isEmpty()) return@forEach
            val intent = Intent(context, SacredAlarmReceiver::class.java).apply { action = ACTION_FIRE }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCodeFor(sessionId),
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
            }
        }
    }

    fun rescheduleSaved(context: Context) {
        val alarms = loadAlarms(context)
            .map { it.toMap() }
            .filter { (it["scheduledAtMs"] as? Long ?: 0L) >= System.currentTimeMillis() }
        schedule(context, alarms)
    }

    fun canScheduleExactAlarms(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return alarmManager.canScheduleExactAlarms()
    }

    private fun saveAlarms(context: Context, alarms: List<Map<String, Any?>>) {
        val json = JSONArray()
        alarms.forEach { alarm -> json.put(JSONObject(alarm)) }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_ALARMS, json.toString())
            .apply()
    }

    private fun loadAlarms(context: Context): List<JSONObject> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_ALARMS, null)
            ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            List(array.length()) { index -> array.getJSONObject(index) }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun requestCodeFor(sessionId: String): Int {
        val hash = sessionId.hashCode()
        return if (hash == Int.MIN_VALUE) 73000 else abs(hash)
    }

    private fun Map<String, Any?>.toBundle(): android.os.Bundle {
        val bundle = android.os.Bundle()
        forEach { (key, value) ->
            when (value) {
                is String -> bundle.putString(key, value)
                is Int -> bundle.putInt(key, value)
                is Long -> bundle.putLong(key, value)
                is Double -> bundle.putDouble(key, value)
                is Boolean -> bundle.putBoolean(key, value)
                is Number -> bundle.putLong(key, value.toLong())
            }
        }
        return bundle
    }

    private fun JSONObject.toMap(): Map<String, Any?> {
        val result = mutableMapOf<String, Any?>()
        keys().forEach { key ->
            result[key] = when (val value = get(key)) {
                JSONObject.NULL -> null
                is Int -> value
                is Long -> value
                is Double -> value
                is Boolean -> value
                else -> value.toString()
            }
        }
        return result
    }
}