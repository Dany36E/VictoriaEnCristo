package com.example.app_quitar

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val NAVIGATION_CHANNEL = "victoria/navigation"
    private val SACRED_ALARMS_CHANNEL = "victoria/sacred_alarms"
    private var initialRouteConsumed = false
    private var navigationChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Configurar MethodChannel para comunicación Flutter <-> Android
        navigationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL)
        navigationChannel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialRoute" -> {
                        // Leer ruta inicial del intent solo una vez
                        val route = if (!initialRouteConsumed) {
                            intent?.getStringExtra("initial_route")
                        } else {
                            null
                        }
                        initialRouteConsumed = true
                        result.success(route)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SACRED_ALARMS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleAlarms" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<String, Any?>
                        @Suppress("UNCHECKED_CAST")
                        val alarms = args?.get("alarms") as? List<Map<String, Any?>> ?: emptyList()
                        SacredAlarmScheduler.schedule(this, alarms)
                        result.success(true)
                    }
                    "cancelAlarms" -> {
                        SacredAlarmScheduler.cancelAll(this)
                        result.success(true)
                    }
                    "startAlarmNow" -> {
                        @Suppress("UNCHECKED_CAST")
                        val alarm = call.arguments as? Map<String, Any?> ?: emptyMap()
                        SacredAlarmForegroundService.start(this, alarm)
                        result.success(true)
                    }
                    "stopAlarm" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<String, Any?>
                        val sessionId = args?.get("sessionId") as? String
                        SacredAlarmForegroundService.stop(this, sessionId)
                        result.success(true)
                    }
                    "isExactAlarmAllowed" -> {
                        result.success(SacredAlarmScheduler.canScheduleExactAlarms(this))
                    }
                    "openExactAlarmSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.getStringExtra("initial_route")?.let { route ->
            if (route.isNotEmpty()) {
                navigationChannel?.invokeMethod("routeChanged", route)
            }
        }
    }
}
