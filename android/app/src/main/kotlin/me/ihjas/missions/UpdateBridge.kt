package me.ihjas.missions

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * In-app updater helpers (`arcane/update`): device ABIs for picking the right split APK,
 * the "install unknown apps" permission, and reading a downloaded APK's version code so a
 * stale/cached download is caught before Android's installer rejects it.
 */
class UpdateBridge(private val activity: Activity, messenger: BinaryMessenger) {

    private val channel = MethodChannel(messenger, "arcane/update")

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "supportedAbis" -> result.success(Build.SUPPORTED_ABIS.toList())
                "canInstallPackages" -> result.success(canInstallPackages())
                "openInstallPermission" -> result.success(openInstallPermission())
                "archiveVersionCode" -> result.success(archiveVersionCode(call.argument<String>("path") ?: ""))
                "installedVersionCode" -> result.success(installedVersionCode())
                else -> result.notImplemented()
            }
        }
    }

    fun dispose() = channel.setMethodCallHandler(null)

    private fun canInstallPackages(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || activity.packageManager.canRequestPackageInstalls()

    private fun openInstallPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return try {
            activity.startActivity(
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${activity.packageName}"))
            )
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun archiveVersionCode(path: String): Long {
        if (path.isEmpty()) return -1L
        return try {
            @Suppress("DEPRECATION")
            val info = activity.packageManager.getPackageArchiveInfo(path, 0) ?: return -1L
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                info.versionCode.toLong()
            }
        } catch (_: Exception) {
            -1L
        }
    }

    private fun installedVersionCode(): Long = try {
        @Suppress("DEPRECATION")
        val info = activity.packageManager.getPackageInfo(activity.packageName, 0)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
    } catch (_: PackageManager.NameNotFoundException) {
        -1L
    }
}
