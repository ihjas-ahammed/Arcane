package me.ihjas.missions

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import me.ihjas.missions.notifications.ArcaneNotificationListenerService

/** `arcane/devices` channel: Bluetooth device capture (see [DeviceMonitor]) and the watch-app keep-alive. */
class DevicesBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "arcane/devices"
        private const val REQ_BT = 4301
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private var pendingPerm: MethodChannel.Result? = null

    init {
        DeviceMonitor.start(activity.applicationContext)
        channel.setMethodCallHandler(this)
        DeviceEventLog.sink = { event -> channel.invokeMethod("event", event) }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        DeviceEventLog.sink = null
        DeviceMonitor.stopScan()
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQ_BT) return false
        pendingPerm?.success(grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED })
        pendingPerm = null
        return true
    }

    private fun listenerEnabled(): Boolean {
        val flat = Settings.Secure.getString(activity.contentResolver, "enabled_notification_listeners") ?: return false
        return flat.contains(activity.packageName)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = activity.applicationContext
        when (call.method) {
            "getState" -> result.success(mapOf(
                "bluetoothOn" to DeviceMonitor.isBluetoothOn(),
                "connectPermission" to DeviceMonitor.hasConnectPermission(ctx),
                "scanPermission" to DeviceMonitor.hasScanPermission(ctx),
                "listenerEnabled" to listenerEnabled(),
                "overlayAllowed" to Settings.canDrawOverlays(ctx),
                "connected" to DeviceMonitor.connectedAddresses(),
                "watch" to WatchKeepAlive.status(ctx),
            ))
            "requestPermissions" -> {
                val perms = if (Build.VERSION.SDK_INT >= 31)
                    arrayOf(Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_SCAN)
                else arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
                if (perms.all { ActivityCompat.checkSelfPermission(ctx, it) == PackageManager.PERMISSION_GRANTED }) {
                    result.success(true)
                } else {
                    pendingPerm = result
                    ActivityCompat.requestPermissions(activity, perms, REQ_BT)
                }
            }
            "getBonded" -> result.success(DeviceMonitor.bonded())
            "startScan" -> result.success(DeviceMonitor.startScan())
            "stopScan" -> { DeviceMonitor.stopScan(); result.success(true) }
            "connect" -> result.success(DeviceMonitor.connect(call.argument<String>("address") ?: ""))
            "disconnect" -> { DeviceMonitor.disconnect(call.argument<String>("address") ?: ""); result.success(true) }
            "readLog" -> result.success(DeviceEventLog.read(ctx, call.argument<Int>("limit") ?: 500))
            "clearLog" -> { DeviceEventLog.clear(ctx); result.success(true) }
            "setWatchApp" -> {
                WatchKeepAlive.set(ctx, call.argument<String>("package") ?: "", null)
                result.success(true)
            }
            "setKeepAlive" -> {
                WatchKeepAlive.set(ctx, null, call.argument<Boolean>("enabled") ?: false)
                result.success(true)
            }
            "restartWatchApp" -> result.success(WatchKeepAlive.restart(ctx, "manual"))
            "openListenerSettings" -> result.success(try {
                activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)); true
            } catch (_: Exception) { false })
            "openOverlaySettings" -> result.success(try {
                activity.startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${activity.packageName}"))); true
            } catch (_: Exception) { false })
            "openBatterySettings" -> result.success(try {
                activity.startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)); true
            } catch (_: Exception) { false })
            "openAppSettings" -> result.success(try {
                activity.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${call.argument<String>("package") ?: ""}"))); true
            } catch (_: Exception) { false })
            else -> result.notImplemented()
        }
    }
}
