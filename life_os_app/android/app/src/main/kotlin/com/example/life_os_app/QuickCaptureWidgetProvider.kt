package com.example.life_os_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

class QuickCaptureWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        appWidgetIds.forEach { appWidgetId ->
            appWidgetManager.updateAppWidget(appWidgetId, buildRemoteViews(context))
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
    }

    private fun buildRemoteViews(context: Context): RemoteViews {
        return RemoteViews(context.packageName, R.layout.quick_capture_widget).apply {
            setOnClickPendingIntent(
                R.id.widget_action_ai,
                CaptureLaunchIntents.createPendingIntent(
                    context,
                    CaptureLaunchIntents.ROUTE_CAPTURE_SHELL,
                    3002
                )
            )
        }
    }
}
