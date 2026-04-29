package com.example.life_os_app

import android.app.PendingIntent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

class QuickCaptureTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        qsTile?.apply {
            label = getString(R.string.qs_tile_quick_capture)
            state = Tile.STATE_ACTIVE
            updateTile()
        }
    }

    override fun onClick() {
        super.onClick()
        if (isLocked) {
            unlockAndRun(::openQuickCapture)
        } else {
            openQuickCapture()
        }
    }

    private fun openQuickCapture() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val pendingIntent = CaptureLaunchIntents.createPendingIntent(
                this,
                CaptureLaunchIntents.ROUTE_CAPTURE_SHELL,
                2001
            )
            startActivityAndCollapse(pendingIntent)
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(
                CaptureLaunchIntents.createActivityIntent(
                    this,
                    CaptureLaunchIntents.ROUTE_CAPTURE_SHELL
                )
            )
        }
    }
}
