package com.faithvictory

import android.app.Application
import com.faithvictory.di.AppModule
import org.koin.core.context.loadKoinModules
import org.koin.core.context.startKoin

class FaithVictoryApp : Application() {
    override fun onCreate() {
        super.onCreate()
        startKoin {
            // Load Koin modules
            loadKoinModules(AppModule.modules)
        }
    }
}