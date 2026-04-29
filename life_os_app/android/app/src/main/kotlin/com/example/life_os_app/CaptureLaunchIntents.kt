package com.example.life_os_app

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri

object CaptureLaunchIntents {
    const val EXTRA_TARGET_ROUTE = "target_route"
    const val ROUTE_CAPTURE_AI = "/capture?mode=ai"
    const val ROUTE_CAPTURE_TIME = "/capture?type=time&mode=manual"
    const val ROUTE_CAPTURE_LEARNING = "/capture?type=learning&mode=manual"
    const val ROUTE_CAPTURE_VOICE = "/capture?mode=voice"
    const val ROUTE_CAPTURE_SHELL = "/native-shell?mode=ai"

    fun createActivityIntent(context: Context, route: String): Intent {
        return Intent(context, resolveActivityClass(route)).apply {
            action = Intent.ACTION_VIEW
            putExtra(EXTRA_TARGET_ROUTE, route)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
    }

    fun createPendingIntent(context: Context, route: String, requestCode: Int): PendingIntent {
        return PendingIntent.getActivity(
            context,
            requestCode,
            createActivityIntent(context, route),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun extractRoute(intent: Intent?): String? {
        if (intent == null) {
            return null
        }
        intent.getStringExtra(EXTRA_TARGET_ROUTE)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?.let { return it }
        return deepLinkToRoute(intent.data)
    }

    private fun deepLinkToRoute(uri: Uri?): String? {
        if (uri == null || uri.scheme != "skyeos") {
            return null
        }
        val target = uri.host
            ?.takeIf { it.isNotBlank() }
            ?: uri.pathSegments.firstOrNull()
            ?: return null
        val query = uri.query
            ?.takeIf { it.isNotBlank() }
            ?.let { "?$it" }
            ?: ""
        return when (target.lowercase()) {
            "capture" -> "/capture$query"
            "today" -> "/today$query"
            "management" -> "/management$query"
            "review" -> "/review$query"
            else -> null
        }
    }

    private fun resolveActivityClass(route: String): Class<*> {
        return if (route.startsWith(ROUTE_CAPTURE_SHELL)) {
            QuickCaptureShellActivity::class.java
        } else if (route.startsWith("/capture")) {
            QuickCaptureActivity::class.java
        } else {
            MainActivity::class.java
        }
    }
}
