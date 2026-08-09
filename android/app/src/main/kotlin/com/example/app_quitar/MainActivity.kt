package com.example.app_quitar

import android.content.Intent
import android.net.Uri
import android.net.VpnService
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val NAVIGATION_CHANNEL = "victoria/navigation"
    private val SACRED_ALARMS_CHANNEL = "victoria/sacred_alarms"
    private val PURITY_CHANNEL = "victoria/purity_guard"
    private val VPN_REQUEST_CODE = 9911
    private var initialRouteConsumed = false
    private var navigationChannel: MethodChannel? = null
    private var pendingPurityResult: MethodChannel.Result? = null

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

        // ── Escudo de Pureza (VPN local de filtrado DNS) ──────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PURITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val prep = VpnService.prepare(this)
                        if (prep != null) {
                            pendingPurityResult = result
                            startActivityForResult(prep, VPN_REQUEST_CODE)
                        } else {
                            startPurityVpn()
                            result.success(true)
                        }
                    }
                    "startIfPrepared" -> {
                        if (VpnService.prepare(this) == null) {
                            startPurityVpn()
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "stop" -> {
                        val i = Intent(this, PurityVpnService::class.java)
                            .setAction(PurityVpnService.ACTION_STOP)
                        startService(i)
                        result.success(true)
                    }
                    "isRunning" -> result.success(PurityVpnService.isRunning)
                    "blocklistCount" ->
                        result.success(PurityVpnService.blocklistCount(this))
                    else -> result.notImplemented()
                }
            }
    }

    private fun startPurityVpn() {
        val i = Intent(this, PurityVpnService::class.java)
            .setAction(PurityVpnService.ACTION_START)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(i)
        } else {
            startService(i)
        }
    }

    @Deprecated("Compat con flujo de consentimiento de VPN")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == RESULT_OK) {
                startPurityVpn()
                pendingPurityResult?.success(true)
            } else {
                pendingPurityResult?.success(false)
            }
            pendingPurityResult = null
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
