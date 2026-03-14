package com.example.app_quitar

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val NAVIGATION_CHANNEL = "victoria/navigation"
    private var initialRouteConsumed = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Configurar MethodChannel para comunicación Flutter <-> Android
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL)
            .setMethodCallHandler { call, result ->
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
    }
}
