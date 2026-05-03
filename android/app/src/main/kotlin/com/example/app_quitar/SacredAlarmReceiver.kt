package com.example.app_quitar

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class SacredAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        SacredAlarmForegroundService.start(context, intent.extras)
    }
}