package com.example.life_os_app

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant

object FlutterEngineManager {
    const val ENGINE_ID = "skyos.shared.engine"

    fun prewarm(context: Context): FlutterEngine {
        val cache = FlutterEngineCache.getInstance()
        cache.get(ENGINE_ID)?.let { return it }

        val engine = FlutterEngine(context.applicationContext)
        engine.navigationChannel.setInitialRoute("/today")
        GeneratedPluginRegistrant.registerWith(engine)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        cache.put(ENGINE_ID, engine)
        return engine
    }

    fun cached(): FlutterEngine? = FlutterEngineCache.getInstance().get(ENGINE_ID)
}
