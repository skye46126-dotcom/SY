package com.example.life_os_app

import android.app.Application

class SkyOsApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        FlutterEngineManager.prewarm(this)
    }
}
