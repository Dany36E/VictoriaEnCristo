package com.example.app_quitar

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class SacredAlarmBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_DATE_CHANGED -> SacredAlarmScheduler.rescheduleSaved(context)
        }
    }
}