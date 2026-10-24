package me.ihjas.missions

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/** Quick Settings status bar toggle that switches the whole display to grayscale. */
class GrayscaleTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        refresh()
    }

    override fun onClick() {
        super.onClick()
        if (!DisplayGrayscale.hasPermission(this)) {
            openSetupGuide()
            refresh()
            return
        }
        DisplayGrayscale.set(this, !DisplayGrayscale.isOn(contentResolver))
        refresh()
    }

    /** Opens the one-time setup guide. The shade collapses so the guide is visible. */
    private fun openSetupGuide() {
        val intent = Intent(this, GrayscaleSetupActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val pending = PendingIntent.getActivity(
                this, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            startActivityAndCollapse(pending)
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }

    private fun refresh() {
        val tile = qsTile ?: return
        val granted = DisplayGrayscale.hasPermission(this)
        // Keep the tile tappable without the permission: STATE_UNAVAILABLE would swallow the
        // click that opens the setup guide.
        tile.state = if (granted && DisplayGrayscale.isOn(contentResolver)) {
            Tile.STATE_ACTIVE
        } else {
            Tile.STATE_INACTIVE
        }
        tile.label = "Grayscale"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = if (granted) null else "Setup needed"
        }
        tile.updateTile()
    }
}
