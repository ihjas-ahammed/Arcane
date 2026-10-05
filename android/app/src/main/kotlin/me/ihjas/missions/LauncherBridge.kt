package me.ihjas.missions

import java.util.Locale
import android.Manifest
import android.app.Activity
import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetHostView
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.provider.ContactsContract
import androidx.core.content.ContextCompat
import androidx.core.app.ActivityCompat
import android.content.pm.ApplicationInfo
import android.content.pm.LauncherActivityInfo
import android.content.pm.LauncherApps
import android.content.pm.ShortcutInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.BatteryManager
import android.os.Build
import android.telephony.TelephonyManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.UserHandle
import android.os.UserManager
import android.provider.Settings
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.xmlpull.v1.XmlPullParser
import org.xmlpull.v1.XmlPullParserFactory
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors
import android.graphics.Color
import android.view.Gravity
import android.widget.RemoteViews
import android.widget.TextView
import android.util.Log

/**
 * Native half of the Arcane home-screen launcher (`arcane/launcher` channel).
 *
 * - App discovery through [LauncherApps] (the same API Launcher3 uses) and component launching
 * - Real app icons and icon-pack (ADW / Nova / Go appfilter.xml) icons, rendered to PNG off the UI thread
 * - Android AppWidget hosting: provider listing, bind/configure flow, and an `arcane/appwidget` platform view
 * - Package add/remove/change events, HOME-button presses, notification shade, quick system toggles
 */
class LauncherBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "arcane/launcher"
        const val VIEW_TYPE = "arcane/appwidget"
        private const val TAG = "LauncherBridge"
        private const val HOST_ID = 0x4A52
        private const val REQ_BIND_WIDGET = 4101
        private const val REQ_CONFIGURE_WIDGET = 4102

        private val ICON_PACK_ACTIONS = listOf(
            "org.adw.launcher.THEMES",
            "com.novalauncher.THEME",
            "com.teslacoilsw.launcher.THEME",
            "com.gau.go.launcherex.theme",
            "com.fede.launcher.THEME_ICONPACK",
            "com.anddoes.launcher.THEME",
        )

        private val COUNTRY_CALLING_CODES = mapOf(
            "IN" to "91", "US" to "1", "CA" to "1", "GB" to "44", "AE" to "971", "SA" to "966",
            "QA" to "974", "KW" to "965", "OM" to "968", "BH" to "973", "SG" to "65", "MY" to "60",
            "AU" to "61", "NZ" to "64", "DE" to "49", "FR" to "33", "IT" to "39", "ES" to "34",
            "NL" to "31", "CH" to "41", "SE" to "46", "NO" to "47", "DK" to "45", "IE" to "353",
            "ZA" to "27", "NG" to "234", "KE" to "254", "EG" to "20", "BR" to "55", "MX" to "52",
            "AR" to "54", "CO" to "57", "CL" to "56", "PE" to "51", "JP" to "81", "KR" to "82",
            "CN" to "86", "HK" to "852", "TW" to "886", "PK" to "92", "BD" to "880", "LK" to "94",
            "NP" to "977", "ID" to "62", "TH" to "66", "VN" to "84", "PH" to "63", "TR" to "90",
            "RU" to "7", "UA" to "380", "PL" to "48", "AT" to "43", "BE" to "32", "PT" to "351"
        )
    }

    val channel = MethodChannel(messenger, CHANNEL)
    private val appContext: Context = activity.applicationContext
    private val pm: PackageManager = activity.packageManager
    private val io = Executors.newFixedThreadPool(2)
    private val main = Handler(Looper.getMainLooper())

    private val widgetManager: AppWidgetManager = AppWidgetManager.getInstance(appContext)

    val widgetHost = object : AppWidgetHost(appContext, HOST_ID) {
        override fun onCreateView(
            context: Context,
            appWidgetId: Int,
            appWidget: AppWidgetProviderInfo?
        ): AppWidgetHostView {
            return SafeAppWidgetHostView(context)
        }
    }

    private inner class SafeAppWidgetHostView(context: Context) : AppWidgetHostView(context) {
        override fun getErrorView(): View {
            return TextView(context).apply {
                text = "Widget Unavailable"
                setTextColor(Color.GRAY)
                textSize = 11f
                gravity = Gravity.CENTER
                setPadding(12, 12, 12, 12)
            }
        }

        override fun updateAppWidget(remoteViews: RemoteViews?) {
            try {
                super.updateAppWidget(remoteViews)
            } catch (e: Throwable) {
                Log.e(TAG, "Error updating app widget", e)
                try {
                    removeAllViews()
                    addView(getErrorView())
                } catch (_: Throwable) {}
            }
        }
    }
    /** Completion of the in-flight bind/configure flow (null = cancelled). One flow at a time. */
    private var pendingWidgetDone: ((Map<String, Any?>?) -> Unit)? = null
    private var pendingWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    private val iconPackCache = HashMap<String, IconPack>()
    private var packageReceiver: BroadcastReceiver? = null
    private var torchOn = false
    private var torchCallback: CameraManager.TorchCallback? = null

    private class IconPack(val map: Map<String, String>, val drawables: List<String>)

    init {
        channel.setMethodCallHandler(this)
        registerPackageReceiver()
        registerTorchCallback()
        registerLauncherAppsCallback()
    }

    private var launcherAppsCallback: LauncherApps.Callback? = null

    /** Pinned-shortcut and other-profile package changes (the broadcast only covers our own profile). */
    private fun registerLauncherAppsCallback() {
        val la = launcherApps ?: return
        val cb = object : LauncherApps.Callback() {
            override fun onPackageRemoved(packageName: String?, user: UserHandle?) = changed(packageName)
            override fun onPackageAdded(packageName: String?, user: UserHandle?) = changed(packageName)
            override fun onPackageChanged(packageName: String?, user: UserHandle?) = changed(packageName)
            override fun onPackagesAvailable(packageNames: Array<out String>?, user: UserHandle?, replacing: Boolean) =
                changed(packageNames?.firstOrNull())
            override fun onPackagesUnavailable(packageNames: Array<out String>?, user: UserHandle?, replacing: Boolean) =
                changed(packageNames?.firstOrNull())
            override fun onShortcutsChanged(packageName: String, shortcuts: MutableList<ShortcutInfo>, user: UserHandle) =
                changed(packageName)

            private fun changed(pkg: String?) {
                main.post { channel.invokeMethod("packagesChanged", pkg ?: "") }
            }
        }
        try {
            la.registerCallback(cb, main)
            launcherAppsCallback = cb
        } catch (_: Exception) {}
    }

    // ── Lifecycle ────────────────────────────────────────────────────────────

    fun onStart() {
        try { widgetHost.startListening() } catch (_: Exception) {}
    }

    fun onStop() {
        try { widgetHost.stopListening() } catch (_: Exception) {}
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        launcherAppsCallback?.let { cb -> try { launcherApps?.unregisterCallback(cb) } catch (_: Exception) {} }
        launcherAppsCallback = null
        packageReceiver?.let { try { activity.unregisterReceiver(it) } catch (_: Exception) {} }
        packageReceiver = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            torchCallback?.let {
                try { (appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager).unregisterTorchCallback(it) } catch (_: Exception) {}
            }
        }
        io.shutdown()
    }

    fun trimMemory(level: Int) {
        synchronized(iconPackCache) {
            iconPackCache.clear()
        }
    }

    /** Returns true when [intent] came from the HOME button / home-screen launch. */
    fun isHomeIntent(intent: Intent?): Boolean =
        intent?.action == Intent.ACTION_MAIN && intent.hasCategory(Intent.CATEGORY_HOME)

    fun isPinRequest(intent: Intent?): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            (intent?.action == LauncherApps.ACTION_CONFIRM_PIN_APPWIDGET ||
                intent?.action == LauncherApps.ACTION_CONFIRM_PIN_SHORTCUT)

    /**
     * Another app (or Arcane itself) called AppWidgetManager.requestPinAppWidget and Android
     * routed the request to us as the default launcher. Bind + configure the widget, accept the
     * request, and tell Dart to place it on the home screen.
     */
    fun handlePinRequest(intent: Intent?): Boolean {
        if (!isPinRequest(intent) || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        try {
            val la = appContext.getSystemService(Context.LAUNCHER_APPS_SERVICE) as? LauncherApps ?: return false
            val request = la.getPinItemRequest(intent) ?: return true
            if (!request.isValid) return true
            if (request.requestType == LauncherApps.PinItemRequest.REQUEST_TYPE_SHORTCUT) {
                // Chrome "Install app" / "Add to Home screen" and any app's pin-shortcut request.
                val si = request.shortcutInfo ?: return true
                if (try { request.accept() } catch (_: Exception) { false }) {
                    val me = Process.myUserHandle()
                    val serial = if (si.userHandle == me) -1L else serialOf(si.userHandle)
                    activity.runOnUiThread {
                        try {
                            channel.invokeMethod("shortcutPinned", describeShortcut(si, serial))
                        } catch (e: Throwable) {
                            Log.e(TAG, "Failed to invoke shortcutPinned", e)
                        }
                    }
                }
                return true
            }
            if (request.requestType != LauncherApps.PinItemRequest.REQUEST_TYPE_APPWIDGET) return true
            val info = request.getAppWidgetProviderInfo(activity) ?: return true
            startWidgetFlow(info.provider) { desc ->
                val id = (desc?.get("id") as? Int) ?: return@startWidgetFlow
                val accepted = try {
                    request.isValid && request.accept(Bundle().apply { putInt(AppWidgetManager.EXTRA_APPWIDGET_ID, id) })
                } catch (_: Exception) { false }
                if (accepted) {
                    activity.runOnUiThread {
                        try {
                            channel.invokeMethod("widgetPinned", desc)
                        } catch (e: Throwable) {
                            Log.e(TAG, "Failed to invoke widgetPinned", e)
                        }
                    }
                } else {
                    try { widgetHost.deleteAppWidgetId(id) } catch (_: Exception) {}
                }
            }
        } catch (e: Throwable) {
            Log.e(TAG, "Error handling pin request", e)
        }
        return true
    }

    fun onNewIntent(intent: Intent) {
        if (handlePinRequest(intent)) {
            channel.invokeMethod("homePressed", null)
        } else if (isHomeIntent(intent)) {
            // Takeover swaps (MIUI) must land on home instantly, with no Flutter-side animation.
            val instant = intent.getBooleanExtra(LauncherTakeoverService.EXTRA_TAKEOVER, false)
            channel.invokeMethod("homePressed", mapOf("instant" to instant))
        } else {
            channel.invokeMethod("openArcane", null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        when (requestCode) {
            REQ_BIND_WIDGET -> {
                val id = data?.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, pendingWidgetId) ?: pendingWidgetId
                if (resultCode == Activity.RESULT_OK) configureOrFinish(id) else finishWidget(id, false)
                return true
            }
            REQ_CONFIGURE_WIDGET -> {
                val id = data?.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, pendingWidgetId) ?: pendingWidgetId
                finishWidget(id, resultCode == Activity.RESULT_OK)
                return true
            }
        }
        return false
    }

    // ── Method channel ───────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getLaunchMode" -> result.success(
                if (activity is LauncherActivity) "home" else "app"
            )
            "isDefaultLauncher" -> result.success(isDefaultLauncher())
            // Default home app, or the MIUI-style takeover mode that opens us over the stock launcher.
            "actsAsHome" -> result.success(
                isDefaultLauncher() ||
                    (LauncherTakeoverService.isEnabled(activity) && LauncherTakeoverService.isServiceEnabled(activity))
            )
            "getTakeoverStatus" -> result.success(mapOf(
                "enabled" to LauncherTakeoverService.isEnabled(activity),
                "serviceEnabled" to LauncherTakeoverService.isServiceEnabled(activity),
                "isDefault" to isDefaultLauncher(),
                "isMiui" to isMiui(),
                "stockLaunchers" to LauncherTakeoverService.otherHomePackages(activity).toList(),
            ))
            "setTakeoverEnabled" -> {
                LauncherTakeoverService.setEnabled(activity, call.argument<Boolean>("enabled") ?: false)
                result.success(true)
            }
            "getCrashLog" -> result.success(CrashGuard.read(activity))
            "clearCrashLog" -> {
                CrashGuard.clear(activity)
                result.success(true)
            }
            "getTaskBubbleStatus" -> result.success(mapOf(
                "enabled" to TaskBubbleOverlay.isEnabled(activity),
                "serviceEnabled" to LauncherTakeoverService.isServiceEnabled(activity),
                "ignoringBattery" to isIgnoringBatteryOptimizations(),
                "isMiui" to isMiui(),
            ))
            "setTaskBubbleEnabled" -> {
                TaskBubbleOverlay.setEnabled(activity, call.argument<Boolean>("enabled") ?: true)
                result.success(true)
            }
            "requestIgnoreBatteryOptimizations" -> result.success(requestIgnoreBatteryOptimizations())
            "openAccessibilitySettings" -> {
                val direct = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                result.success(startSafely(direct))
            }
            "openMiuiPermissions" -> result.success(openMiuiPermissions(call.argument<String>("page") ?: "autostart"))
            "openHomeSettings" -> result.success(startSafely(Intent(Settings.ACTION_HOME_SETTINGS)))
            "requestDefaultLauncher" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val rm = activity.getSystemService(android.app.role.RoleManager::class.java)
                    if (rm != null && rm.isRoleAvailable(android.app.role.RoleManager.ROLE_HOME)) {
                        if (!rm.isRoleHeld(android.app.role.RoleManager.ROLE_HOME)) {
                            val roleIntent = rm.createRequestRoleIntent(android.app.role.RoleManager.ROLE_HOME)
                            try {
                                activity.startActivity(roleIntent)
                                result.success(true)
                                return@onMethodCall
                            } catch (_: Exception) {}
                        }
                    }
                }
                val miuiIntent = Intent("miui.intent.action.PREFERRED_APP_SETTINGS")
                if (startSafely(miuiIntent)) {
                    result.success(true)
                    return@onMethodCall
                }
                val miuiComp = Intent().setComponent(ComponentName("com.miui.securitycenter", "com.miui.permcenter.preferredapp.PreferredSettingsActivity"))
                if (startSafely(miuiComp)) {
                    result.success(true)
                    return@onMethodCall
                }
                result.success(startSafely(Intent(Settings.ACTION_HOME_SETTINGS)))
            }
            "getMiuiShieldStatus" -> result.success(mapOf(
                "isDefault" to isDefaultLauncher(),
                "takeoverEnabled" to LauncherTakeoverService.isEnabled(activity),
                "serviceEnabled" to LauncherTakeoverService.isServiceEnabled(activity),
                "ignoringBattery" to isIgnoringBatteryOptimizations(),
                "isMiui" to isMiui(),
                "hasCrashLog" to CrashGuard.read(activity).isNotEmpty(),
                "crashLog" to CrashGuard.read(activity)
            ))
            "getApps" -> background(result) { getApps() }
            "getDefaultApps" -> background(result) { getDefaultApps() }
            "getPinnedShortcuts" -> background(result) { getPinnedShortcuts() }
            "shortcutsAvailable" -> result.success(shortcutsAvailable())
            "getAppShortcuts" -> {
                val pkg = call.argument<String>("package") ?: ""
                val serial = call.argument<Number>("user")?.toLong()
                background(result) { getAppShortcuts(pkg, serial) }
            }
            "launchShortcut" -> result.success(
                launchShortcut(call.argument<String>("package") ?: "", call.argument<String>("id") ?: "", call.argument<Number>("user")?.toLong())
            )
            "unpinShortcut" -> result.success(
                unpinShortcut(call.argument<String>("package") ?: "", call.argument<String>("id") ?: "", call.argument<Number>("user")?.toLong())
            )
            "openUrl" -> {
                val url = call.argument<String>("url") ?: ""
                result.success(url.isNotEmpty() && startSafely(Intent(Intent.ACTION_VIEW, Uri.parse(url))))
            }
            "getAppIcons" -> {
                val items = call.argument<List<Map<String, Any?>>>("items") ?: emptyList()
                val size = call.argument<Int>("size") ?: 144
                background(result) { getAppIcons(items, size) }
            }
            "launchApp" -> result.success(
                launchApp(call.argument<String>("package") ?: "", call.argument<String>("activity"), call.argument<Number>("user")?.toLong())
            )
            "appInfo" -> {
                val pkg = call.argument<String>("package") ?: ""
                result.success(startSafely(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$pkg"))))
            }
            "uninstall" -> {
                val pkg = call.argument<String>("package") ?: ""
                @Suppress("DEPRECATION")
                val intent = Intent(Intent.ACTION_UNINSTALL_PACKAGE, Uri.parse("package:$pkg"))
                result.success(startSafely(intent))
            }
            "expandNotifications" -> result.success(expandStatusBar("expandNotificationsPanel"))
            "expandQuickSettings" -> result.success(expandStatusBar("expandSettingsPanel"))
            "openWebSearch" -> {
                val q = call.argument<String>("query") ?: ""
                val intent = Intent(Intent.ACTION_WEB_SEARCH).putExtra("query", q)
                result.success(startSafely(intent) || startSafely(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/search?q=" + Uri.encode(q)))))
            }

            // Icon packs
            "getIconPacks" -> background(result) { getIconPacks() }
            "getIconPack" -> {
                val pack = call.argument<String>("pack") ?: ""
                background(result) {
                    val p = loadIconPack(pack)
                    mapOf("map" to p.map, "drawables" to p.drawables)
                }
            }
            "getIconPackIcons" -> {
                val pack = call.argument<String>("pack") ?: ""
                val names = call.argument<List<String>>("names") ?: emptyList()
                val size = call.argument<Int>("size") ?: 144
                background(result) { getIconPackIcons(pack, names, size) }
            }

            // System quick controls
            "getSystemStatus" -> result.success(getSystemStatus())
            "getBatteryAndNetworkStatus" -> result.success(getBatteryAndNetworkStatus())
            "openSystemPanel" -> result.success(openSystemPanel(call.argument<String>("panel") ?: ""))
            "setTorch" -> result.success(setTorch(call.argument<Boolean>("on") ?: false))

            // AppWidgets
            "getWidgetProviders" -> background(result) { getWidgetProviders() }
            "getWidgetPreview" -> {
                val provider = call.argument<String>("provider") ?: ""
                val size = call.argument<Int>("size") ?: 360
                background(result) { getWidgetPreview(provider, size) }
            }
            "addWidget" -> {
                val cn = ComponentName.unflattenFromString(call.argument<String>("provider") ?: "")
                if (cn == null) result.success(null) else startWidgetFlow(cn) { result.success(it) }
            }
            "removeWidget" -> {
                val id = call.argument<Int>("id") ?: AppWidgetManager.INVALID_APPWIDGET_ID
                try { widgetHost.deleteAppWidgetId(id) } catch (_: Exception) {}
                result.success(true)
            }
            "getWidgetInfo" -> {
                val id = call.argument<Int>("id") ?: AppWidgetManager.INVALID_APPWIDGET_ID
                result.success(widgetManager.getAppWidgetInfo(id)?.let { describeProvider(it) })
            }
            "reconfigureWidget" -> {
                val id = call.argument<Int>("id") ?: AppWidgetManager.INVALID_APPWIDGET_ID
                result.success(reconfigureWidget(id))
            }

            // Contacts Search & Actions
            "hasContactsPermission" -> result.success(hasContactsPermission())
            "requestContactsPermission" -> requestContactsPermission(result)
            "searchContacts" -> {
                val q = call.argument<String>("query") ?: ""
                val limit = call.argument<Int>("limit") ?: 20
                background(result) { searchContacts(q, limit) }
            }
            "callNumber" -> {
                val num = call.argument<String>("number") ?: ""
                result.success(callNumber(num))
            }
            "messageNumber" -> {
                val num = call.argument<String>("number") ?: ""
                result.success(messageNumber(num))
            }
            "openWhatsApp" -> {
                val num = call.argument<String>("number") ?: ""
                val code = call.argument<String>("countryCode")
                result.success(openWhatsApp(num, code))
            }
            "openContact" -> {
                val id = call.argument<String>("id") ?: ""
                result.success(openContact(id))
            }

            else -> result.notImplemented()
        }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            // Throwable, not Exception: an OutOfMemoryError from a big icon pack on this pool
            // thread would otherwise take the whole launcher down.
            val value = try { work() } catch (_: Throwable) { null }
            main.post { result.success(value) }
        }
    }

    private fun startSafely(intent: Intent): Boolean = try {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        activity.startActivity(intent)
        true
    } catch (_: Exception) {
        false
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = activity.getSystemService(Context.POWER_SERVICE) as? android.os.PowerManager
            return pm?.isIgnoringBatteryOptimizations(activity.packageName) ?: true
        }
        return true
    }

    private fun requestIgnoreBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:${activity.packageName}")
            }
            return startSafely(intent)
        }
        return false
    }

    private fun isMiui(): Boolean {
        if (Build.MANUFACTURER.equals("Xiaomi", true) || Build.BRAND.equals("Redmi", true) || Build.BRAND.equals("POCO", true)) {
            return true
        }
        val value: String? = try {
            val clazz = Class.forName("android.os.SystemProperties")
            clazz.getMethod("get", String::class.java).invoke(null, "ro.miui.ui.version.name") as? String
        } catch (_: Exception) {
            null
        }
        return !value.isNullOrEmpty()
    }

    /**
     * MIUI/HyperOS gate background activity starts behind their own permissions ("Autostart" and
     * "Display pop-up windows while running in the background"); open those pages when present.
     */
    private fun openMiuiPermissions(page: String): Boolean {
        val pkg = activity.packageName
        val candidates = when (page) {
            "autostart" -> listOf(
                Intent().setComponent(ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")),
                Intent("miui.intent.action.OP_AUTO_START").addCategory(Intent.CATEGORY_DEFAULT),
            )
            else -> listOf(
                Intent("miui.intent.action.APP_PERM_EDITOR")
                    .setClassName("com.miui.securitycenter", "com.miui.permcenter.permissions.PermissionsEditorActivity")
                    .putExtra("extra_pkgname", pkg),
                Intent("miui.intent.action.APP_PERM_EDITOR")
                    .setClassName("com.miui.securitycenter", "com.miui.permcenter.permissions.AppPermissionsEditorActivity")
                    .putExtra("extra_pkgname", pkg),
            )
        }
        for (intent in candidates) if (startSafely(intent)) return true
        return startSafely(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$pkg")))
    }

    private fun isDefaultLauncher(): Boolean {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val info = pm.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
        return info?.activityInfo?.packageName == activity.packageName
    }

    /** Packages the system resolves for the classic dock roles (dialer, SMS, browser, camera, …). */
    private fun getDefaultApps(): Map<String, String?> {
        fun resolve(intent: Intent): String? = try {
            val ri = pm.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
            ri?.activityInfo?.packageName?.takeUnless { it == "android" }
        } catch (_: Exception) { null }
        return mapOf(
            "phone" to resolve(Intent(Intent.ACTION_DIAL)),
            "messages" to resolve(Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:"))),
            "browser" to resolve(Intent(Intent.ACTION_VIEW, Uri.parse("https://example.com"))),
            "camera" to resolve(Intent(android.provider.MediaStore.ACTION_IMAGE_CAPTURE)),
            "email" to resolve(Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:"))),
        )
    }

    // ── Apps ─────────────────────────────────────────────────────────────────

    private val launcherApps: LauncherApps?
        get() = appContext.getSystemService(Context.LAUNCHER_APPS_SERVICE) as? LauncherApps
    private val userManager: UserManager
        get() = appContext.getSystemService(Context.USER_SERVICE) as UserManager

    private fun serialOf(user: UserHandle): Long = userManager.getSerialNumberForUser(user)

    /** Own profile → null; other profiles (MIUI Dual Apps / Second Space, work profile) → its handle. */
    private fun userFor(serial: Long?): UserHandle =
        if (serial == null || serial < 0) Process.myUserHandle()
        else userManager.getUserForSerialNumber(serial) ?: Process.myUserHandle()

    private fun profiles(): List<UserHandle> =
        (try { launcherApps?.profiles?.takeIf { it.isNotEmpty() } } catch (_: Exception) { null })
            ?: listOf(Process.myUserHandle())

    /** Every launchable activity in every profile the launcher may show. */
    private fun getApps(): List<Map<String, Any?>> {
        val list = mutableListOf<Map<String, Any?>>()
        val la = launcherApps
        if (la != null) {
            val me = Process.myUserHandle()
            for (user in profiles()) {
                val own = user == me
                val serial = if (own) -1L else serialOf(user)
                val activities = try { la.getActivityList(null, user) } catch (_: Exception) { emptyList<LauncherActivityInfo>() }
                for (info in activities) {
                    val ai = info.applicationInfo
                    list.add(mapOf(
                        "package" to info.componentName.packageName,
                        "activity" to info.componentName.className,
                        "label" to (info.label?.toString()?.trim().takeUnless { it.isNullOrEmpty() } ?: info.componentName.packageName),
                        "isSystem" to ((ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0 && (ai.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) == 0),
                        "installTime" to info.firstInstallTime,
                        "user" to serial,
                    ))
                }
            }
        } else {
            val query = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
            for (ri in pm.queryIntentActivities(query, 0)) {
                val ai = ri.activityInfo.applicationInfo
                list.add(mapOf(
                    "package" to ri.activityInfo.packageName,
                    "activity" to ri.activityInfo.name,
                    "label" to ri.loadLabel(pm).toString(),
                    "isSystem" to ((ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                    "installTime" to 0L,
                    "user" to -1L,
                ))
            }
        }
        return list
    }

    /**
     * items: `{key, kind(app|shortcut), package, activity|shortcutId, user}` → PNG per key.
     * Other-profile icons carry the system badge (Dual Apps / work briefcase).
     */
    private fun getAppIcons(items: List<Map<String, Any?>>, size: Int): Map<String, ByteArray?> {
        val out = HashMap<String, ByteArray?>()
        val la = launcherApps
        val density = activity.resources.displayMetrics.densityDpi
        for (item in items) {
            val key = item["key"] as? String ?: continue
            val pkg = item["package"] as? String ?: continue
            val serial = (item["user"] as? Number)?.toLong()
            val user = userFor(serial)
            val primary: Drawable? = try {
                if (item["kind"] == "shortcut") {
                    val si = findShortcut(pkg, item["shortcutId"] as? String ?: "", user)
                    si?.let { if (Build.VERSION.SDK_INT >= 25) la?.getShortcutIconDrawable(it, density) else null }
                } else {
                    val act = item["activity"] as? String
                    if (serial != null && serial >= 0 && la != null && !act.isNullOrEmpty()) {
                        la.resolveActivity(Intent(Intent.ACTION_MAIN).setComponent(ComponentName(pkg, act)), user)?.getBadgedIcon(density)
                    } else if (!act.isNullOrEmpty()) {
                        pm.getActivityIcon(ComponentName(pkg, act))
                    } else {
                        pm.getApplicationIcon(pkg)
                    }
                }
            } catch (_: Exception) {
                null
            }
            val drawable: Drawable? = primary ?: (try { pm.getApplicationIcon(pkg) } catch (_: Exception) { null })
            out[key] = drawable?.let { encode(it, size) }
        }
        return out
    }

    private fun launchApp(pkg: String, act: String?, serial: Long?): Boolean {
        if (pkg.isEmpty()) return false
        val user = userFor(serial)
        if (!act.isNullOrEmpty()) {
            val cn = ComponentName(pkg, act)
            try {
                val la = launcherApps
                if (la != null) {
                    la.startMainActivity(cn, user, null, null)
                    return true
                }
            } catch (_: Exception) {}
            if (user == Process.myUserHandle()) {
                val intent = Intent(Intent.ACTION_MAIN)
                    .addCategory(Intent.CATEGORY_LAUNCHER)
                    .setComponent(cn)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
                if (startSafely(intent)) return true
            }
        }
        val launch = pm.getLaunchIntentForPackage(pkg) ?: return false
        return startSafely(launch)
    }

    // ── Shortcuts (Chrome web apps, "Add to Home screen", app shortcuts) ───────

    /** Only the default home app may read/launch other apps' shortcuts. */
    private fun shortcutsAvailable(): Boolean =
        Build.VERSION.SDK_INT >= 25 && try { launcherApps?.hasShortcutHostPermission() == true } catch (_: Exception) { false }

    private fun findShortcut(pkg: String, id: String, user: UserHandle): ShortcutInfo? {
        if (Build.VERSION.SDK_INT < 25 || id.isEmpty() || !shortcutsAvailable()) return null
        val q = LauncherApps.ShortcutQuery()
            .setPackage(pkg)
            .setShortcutIds(listOf(id))
            .setQueryFlags(
                LauncherApps.ShortcutQuery.FLAG_MATCH_PINNED or
                    LauncherApps.ShortcutQuery.FLAG_MATCH_DYNAMIC or
                    LauncherApps.ShortcutQuery.FLAG_MATCH_MANIFEST
            )
        return try { launcherApps?.getShortcuts(q, user)?.firstOrNull() } catch (_: Exception) { null }
    }

    private fun describeShortcut(si: ShortcutInfo, serial: Long): Map<String, Any?> {
        if (Build.VERSION.SDK_INT < 25) return emptyMap()
        return mapOf(
            "package" to si.`package`,
            "id" to si.id,
            "label" to (si.shortLabel?.toString()?.takeIf { it.isNotBlank() } ?: si.longLabel?.toString() ?: si.id),
            "user" to serial,
            "enabled" to si.isEnabled,
        )
    }

    /** Shortcuts pinned to this launcher — Chrome web apps / "Add to Home screen" land here. */
    private fun getPinnedShortcuts(): List<Map<String, Any?>> {
        if (Build.VERSION.SDK_INT < 25 || !shortcutsAvailable()) return emptyList()
        val la = launcherApps ?: return emptyList()
        val me = Process.myUserHandle()
        val out = mutableListOf<Map<String, Any?>>()
        for (user in profiles()) {
            val serial = if (user == me) -1L else serialOf(user)
            val q = LauncherApps.ShortcutQuery().setQueryFlags(LauncherApps.ShortcutQuery.FLAG_MATCH_PINNED)
            val list = try { la.getShortcuts(q, user) } catch (_: Exception) { null } ?: continue
            for (si in list) out.add(describeShortcut(si, serial))
        }
        return out
    }

    /** Dynamic + manifest shortcuts of one app (long-press menu). */
    private fun getAppShortcuts(pkg: String, serial: Long?): List<Map<String, Any?>> {
        if (Build.VERSION.SDK_INT < 25 || !shortcutsAvailable()) return emptyList()
        val q = LauncherApps.ShortcutQuery()
            .setPackage(pkg)
            .setQueryFlags(LauncherApps.ShortcutQuery.FLAG_MATCH_DYNAMIC or LauncherApps.ShortcutQuery.FLAG_MATCH_MANIFEST)
        val list = try { launcherApps?.getShortcuts(q, userFor(serial)) } catch (_: Exception) { null } ?: return emptyList()
        return list.sortedBy { it.rank }.take(6).map { describeShortcut(it, serial ?: -1L) }
    }

    private fun launchShortcut(pkg: String, id: String, serial: Long?): Boolean {
        if (Build.VERSION.SDK_INT < 25 || !shortcutsAvailable()) return false
        return try {
            launcherApps?.startShortcut(pkg, id, null, null, userFor(serial))
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun unpinShortcut(pkg: String, id: String, serial: Long?): Boolean {
        if (Build.VERSION.SDK_INT < 25 || !shortcutsAvailable()) return false
        val la = launcherApps ?: return false
        val user = userFor(serial)
        return try {
            val q = LauncherApps.ShortcutQuery().setPackage(pkg).setQueryFlags(LauncherApps.ShortcutQuery.FLAG_MATCH_PINNED)
            val keep = (la.getShortcuts(q, user) ?: emptyList()).map { it.id }.filter { it != id }
            la.pinShortcuts(pkg, keep, user)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun encode(drawable: Drawable, size: Int): ByteArray {
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(canvas)
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        bitmap.recycle()
        return stream.toByteArray()
    }

    // ── Package events ───────────────────────────────────────────────────────

    private fun registerPackageReceiver() {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val pkg = intent?.data?.schemeSpecificPart
                main.post { channel.invokeMethod("packagesChanged", pkg) }
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_ADDED)
            addAction(Intent.ACTION_PACKAGE_REMOVED)
            addAction(Intent.ACTION_PACKAGE_CHANGED)
            addAction(Intent.ACTION_PACKAGE_REPLACED)
            addDataScheme("package")
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                activity.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                activity.registerReceiver(receiver, filter)
            }
            packageReceiver = receiver
        } catch (_: Exception) {}
    }

    // ── Icon packs ───────────────────────────────────────────────────────────

    private fun getIconPacks(): List<Map<String, String>> {
        val seen = LinkedHashMap<String, String>()
        for (action in ICON_PACK_ACTIONS) {
            try {
                for (ri in pm.queryIntentActivities(Intent(action), PackageManager.GET_META_DATA)) {
                    val pkg = ri.activityInfo.packageName
                    if (!seen.containsKey(pkg)) seen[pkg] = ri.loadLabel(pm).toString()
                }
            } catch (_: Exception) {}
        }
        return seen.map { mapOf("package" to it.key, "label" to it.value) }.sortedBy { it["label"]?.lowercase() }
    }

    private fun loadIconPack(pack: String): IconPack {
        synchronized(iconPackCache) { iconPackCache[pack]?.let { return it } }
        val map = HashMap<String, String>()
        val drawables = LinkedHashSet<String>()
        try {
            val res = pm.getResourcesForApplication(pack)
            parseXml(res, pack, "appfilter") { parser ->
                if (parser.name == "item") {
                    val comp = parser.getAttributeValue(null, "component") ?: return@parseXml
                    val drawable = parser.getAttributeValue(null, "drawable") ?: return@parseXml
                    val start = comp.indexOf('{')
                    val end = comp.indexOf('}')
                    if (start >= 0 && end > start) map[comp.substring(start + 1, end)] = drawable
                    drawables.add(drawable)
                }
            }
            parseXml(res, pack, "drawable") { parser ->
                if (parser.name == "item") parser.getAttributeValue(null, "drawable")?.let { drawables.add(it) }
            }
        } catch (_: Exception) {}
        val result = IconPack(map, drawables.toList())
        synchronized(iconPackCache) { iconPackCache[pack] = result }
        return result
    }

    private fun parseXml(res: android.content.res.Resources, pack: String, name: String, onTag: (XmlPullParser) -> Unit) {
        val parser: XmlPullParser = run {
            val id = res.getIdentifier(name, "xml", pack)
            if (id != 0) {
                res.getXml(id)
            } else {
                val stream = try { res.assets.open("$name.xml") } catch (_: Exception) { return }
                XmlPullParserFactory.newInstance().newPullParser().apply { setInput(stream, "utf-8") }
            }
        }
        var event = parser.eventType
        while (event != XmlPullParser.END_DOCUMENT) {
            if (event == XmlPullParser.START_TAG) onTag(parser)
            event = parser.next()
        }
    }

    private fun getIconPackIcons(pack: String, names: List<String>, size: Int): Map<String, ByteArray?> {
        val out = HashMap<String, ByteArray?>()
        val res = try { pm.getResourcesForApplication(pack) } catch (_: Exception) { return out }
        for (name in names) {
            var id = res.getIdentifier(name, "drawable", pack)
            if (id == 0) id = res.getIdentifier(name, "mipmap", pack)
            out[name] = if (id == 0) null else try {
                @Suppress("DEPRECATION")
                val d = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) res.getDrawable(id, null) else res.getDrawable(id)
                encode(d, size)
            } catch (_: Exception) { null }
        }
        return out
    }

    // ── System controls ──────────────────────────────────────────────────────

    private fun expandStatusBar(method: String): Boolean = try {
        @Suppress("WrongConstant")
        val service = activity.getSystemService("statusbar")
        val clazz = Class.forName("android.app.StatusBarManager")
        clazz.getMethod(method).invoke(service)
        true
    } catch (_: Exception) {
        false
    }

    private fun getSystemStatus(): Map<String, Boolean> {
        val wifi = try {
            (appContext.getSystemService(Context.WIFI_SERVICE) as WifiManager).isWifiEnabled
        } catch (_: Exception) { false }
        val bt = try {
            (appContext.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter?.isEnabled == true
        } catch (_: Exception) { false }
        val airplane = try {
            Settings.Global.getInt(appContext.contentResolver, Settings.Global.AIRPLANE_MODE_ON, 0) != 0
        } catch (_: Exception) { false }
        val location = try {
            val lm = appContext.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) lm.isLocationEnabled
            else lm.isProviderEnabled(LocationManager.GPS_PROVIDER) || lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        } catch (_: Exception) { false }
        return mapOf("wifi" to wifi, "bluetooth" to bt, "airplane" to airplane, "location" to location, "torch" to torchOn)
    }

    private fun getBatteryAndNetworkStatus(): Map<String, Any?> {
        val bm = try { appContext.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager } catch (_: Exception) { null }
        val propLevel = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            try { bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: -1 } catch (_: Exception) { -1 }
        } else -1

        val batteryIntent = try {
            appContext.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        } catch (_: Exception) { null }
        val level = batteryIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = batteryIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val status = batteryIntent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val plugged = batteryIntent?.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1) ?: 0
        val isCharging = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            (bm?.isCharging == true) || status == BatteryManager.BATTERY_STATUS_CHARGING ||
            status == BatteryManager.BATTERY_STATUS_FULL || plugged > 0
        } else {
            status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL || plugged > 0
        }

        val batteryPct = if (propLevel in 0..100) {
            propLevel
        } else if (level >= 0 && scale > 0) {
            ((level.toFloat() / scale.toFloat()) * 100).toInt()
        } else {
            100
        }

        val cm = try { appContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager } catch (_: Exception) { null }
        val wm = try { appContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager } catch (_: Exception) { null }
        val tm = try { appContext.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager } catch (_: Exception) { null }

        var networkType = "OFFLINE"
        var signalLevel = 0
        var isWifi = false
        var isCellular = false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val activeNetwork = cm?.activeNetwork
            val caps = cm?.getNetworkCapabilities(activeNetwork)
            if (caps != null) {
                if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                    isWifi = true
                    networkType = "WIFI"
                } else if (caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) {
                    isCellular = true
                    networkType = "CELLULAR"
                } else if (caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) {
                    networkType = "ETH"
                }
            }
        } else {
            @Suppress("DEPRECATION")
            val info = cm?.activeNetworkInfo
            if (info != null && info.isConnected) {
                if (info.type == ConnectivityManager.TYPE_WIFI) {
                    isWifi = true
                    networkType = "WIFI"
                } else if (info.type == ConnectivityManager.TYPE_MOBILE) {
                    isCellular = true
                    networkType = "CELLULAR"
                }
            }
        }

        if (isWifi) {
            val wifiInfo = try { wm?.connectionInfo } catch (_: Exception) { null }
            val rssi = wifiInfo?.rssi ?: -127
            signalLevel = if (rssi > -127 && rssi != 0) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    try { wm?.calculateSignalLevel(rssi) ?: 3 } catch (_: Exception) { 3 }
                } else {
                    @Suppress("DEPRECATION")
                    try { WifiManager.calculateSignalLevel(rssi, 5) } catch (_: Exception) { 3 }
                }
            } else {
                4
            }
        } else if (isCellular) {
            signalLevel = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                try { tm?.signalStrength?.level ?: 3 } catch (_: Exception) { 3 }
            } else {
                3
            }
            val dataNetworkType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                try { tm?.dataNetworkType } catch (_: Exception) { TelephonyManager.NETWORK_TYPE_UNKNOWN }
            } else {
                @Suppress("DEPRECATION")
                tm?.networkType
            }
            networkType = when (dataNetworkType) {
                TelephonyManager.NETWORK_TYPE_NR -> "5G"
                TelephonyManager.NETWORK_TYPE_LTE -> "4G"
                TelephonyManager.NETWORK_TYPE_HSPAP,
                TelephonyManager.NETWORK_TYPE_HSPA,
                TelephonyManager.NETWORK_TYPE_HSDPA,
                TelephonyManager.NETWORK_TYPE_UMTS -> "3G"
                TelephonyManager.NETWORK_TYPE_EDGE,
                TelephonyManager.NETWORK_TYPE_GPRS -> "2G"
                else -> "4G"
            }
        }

        return mapOf(
            "batteryLevel" to batteryPct.coerceIn(0, 100),
            "isCharging" to isCharging,
            "networkType" to networkType,
            "signalLevel" to signalLevel.coerceIn(0, 4),
            "isOnline" to (networkType != "OFFLINE")
        )
    }

    private fun openSystemPanel(panel: String): Boolean {
        val intent = when (panel) {
            "wifi" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) Intent(Settings.Panel.ACTION_INTERNET_CONNECTIVITY) else Intent(Settings.ACTION_WIFI_SETTINGS)
            "bluetooth" -> Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
            "airplane" -> Intent(Settings.ACTION_AIRPLANE_MODE_SETTINGS)
            "location" -> Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
            "settings" -> Intent(Settings.ACTION_SETTINGS)
            else -> return false
        }
        return startSafely(intent) || startSafely(Intent(Settings.ACTION_SETTINGS))
    }

    private fun registerTorchCallback() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            val cm = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val cb = object : CameraManager.TorchCallback() {
                override fun onTorchModeChanged(cameraId: String, enabled: Boolean) {
                    torchOn = enabled
                }
            }
            cm.registerTorchCallback(cb, main)
            torchCallback = cb
        } catch (_: Exception) {}
    }

    private fun setTorch(on: Boolean): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        return try {
            val cm = appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val id = cm.cameraIdList.firstOrNull {
                cm.getCameraCharacteristics(it).get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            } ?: return false
            cm.setTorchMode(id, on)
            torchOn = on
            true
        } catch (_: Exception) {
            false
        }
    }

    // ── AppWidgets ───────────────────────────────────────────────────────────

    private fun dp(px: Int): Int = (px / activity.resources.displayMetrics.density).toInt()

    private fun describeProvider(info: AppWidgetProviderInfo): Map<String, Any?> {
        val appLabel = try {
            pm.getApplicationLabel(pm.getApplicationInfo(info.provider.packageName, 0)).toString()
        } catch (_: Exception) { info.provider.packageName }
        return mapOf(
            "provider" to info.provider.flattenToString(),
            "package" to info.provider.packageName,
            "label" to (try { info.loadLabel(pm) } catch (_: Exception) { null } ?: appLabel),
            "appLabel" to appLabel,
            "minWidth" to dp(info.minWidth),
            "minHeight" to dp(info.minHeight),
            "resizeMode" to info.resizeMode,
            "configurable" to (info.configure != null),
        )
    }

    private fun getWidgetProviders(): List<Map<String, Any?>> =
        widgetManager.installedProviders.map { describeProvider(it) }
            .sortedWith(compareBy<Map<String, Any?>>({ (it["appLabel"] as? String)?.lowercase() }, { (it["label"] as? String)?.lowercase() }))

    private fun getWidgetPreview(provider: String, size: Int): ByteArray? {
        val cn = ComponentName.unflattenFromString(provider) ?: return null
        val info = widgetManager.installedProviders.firstOrNull { it.provider == cn } ?: return null
        val density = activity.resources.displayMetrics.densityDpi
        val d = info.loadPreviewImage(activity, density) ?: info.loadIcon(activity, density) ?: return null
        val w = d.intrinsicWidth.takeIf { it > 0 } ?: size
        val h = d.intrinsicHeight.takeIf { it > 0 } ?: size
        val scale = minOf(1f, size.toFloat() / maxOf(w, h))
        val bw = maxOf(1, (w * scale).toInt())
        val bh = maxOf(1, (h * scale).toInt())
        val bitmap = Bitmap.createBitmap(bw, bh, Bitmap.Config.ARGB_8888)
        d.setBounds(0, 0, bw, bh)
        d.draw(Canvas(bitmap))
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        bitmap.recycle()
        return stream.toByteArray()
    }

    private fun startWidgetFlow(cn: ComponentName, done: (Map<String, Any?>?) -> Unit) {
        pendingWidgetDone?.invoke(null)
        pendingWidgetDone = done
        val id = try {
            widgetHost.allocateAppWidgetId()
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to allocate app widget id", e)
            done(null)
            return
        }
        pendingWidgetId = id
        val bound = try { widgetManager.bindAppWidgetIdIfAllowed(id, cn) } catch (_: Exception) { false }
        if (bound) {
            configureOrFinish(id)
        } else {
            val intent = Intent(AppWidgetManager.ACTION_APPWIDGET_BIND)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_PROVIDER, cn)
            try {
                activity.startActivityForResult(intent, REQ_BIND_WIDGET)
            } catch (e: Throwable) {
                Log.e(TAG, "Failed to launch REQ_BIND_WIDGET", e)
                finishWidget(id, false)
            }
        }
    }

    private fun configureOrFinish(id: Int) {
        val info = widgetManager.getAppWidgetInfo(id)
        if (info == null) {
            finishWidget(id, false)
            return
        }
        if (info.configure == null) {
            finishWidget(id, true)
            return
        }
        if (!launchConfigure(id, info)) finishWidget(id, true)
    }

    private fun launchConfigure(id: Int, info: AppWidgetProviderInfo): Boolean = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            widgetHost.startAppWidgetConfigureActivityForResult(activity, id, 0, REQ_CONFIGURE_WIDGET, null)
        } else {
            val intent = Intent(AppWidgetManager.ACTION_APPWIDGET_CONFIGURE)
                .setComponent(info.configure)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
            activity.startActivityForResult(intent, REQ_CONFIGURE_WIDGET)
        }
        true
    } catch (_: Exception) {
        false
    }

    private fun reconfigureWidget(id: Int): Boolean {
        val info = widgetManager.getAppWidgetInfo(id) ?: return false
        if (info.configure == null) return false
        pendingWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                widgetHost.startAppWidgetConfigureActivityForResult(activity, id, 0, REQ_CONFIGURE_WIDGET + 100, null)
            } else {
                activity.startActivityForResult(
                    Intent(AppWidgetManager.ACTION_APPWIDGET_CONFIGURE).setComponent(info.configure)
                        .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id),
                    REQ_CONFIGURE_WIDGET + 100,
                )
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun finishWidget(id: Int, success: Boolean) {
        val done = pendingWidgetDone ?: return
        pendingWidgetDone = null
        pendingWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
        val info = if (success) widgetManager.getAppWidgetInfo(id) else null
        if (info == null) {
            try { widgetHost.deleteAppWidgetId(id) } catch (_: Exception) {}
            done(null)
            return
        }
        done(describeProvider(info) + mapOf("id" to id))
    }

    // ── AppWidget platform view ──────────────────────────────────────────────

    inner class WidgetViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
        override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
            return try {
                @Suppress("UNCHECKED_CAST")
                val params = args as? Map<String, Any?> ?: emptyMap()
                val widgetId = (params["id"] as? Number)?.toInt() ?: AppWidgetManager.INVALID_APPWIDGET_ID
                val widthDp = (params["width"] as? Number)?.toInt() ?: 0
                val heightDp = (params["height"] as? Number)?.toInt() ?: 0
                HostedWidget(activity, widgetId, widthDp, heightDp)
            } catch (e: Throwable) {
                Log.e(TAG, "WidgetViewFactory error creating view", e)
                object : PlatformView {
                    private val v = TextView(activity).apply {
                        text = "Widget layout error"
                        setTextColor(Color.GRAY)
                    }
                    override fun getView(): View = v
                    override fun dispose() {}
                }
            }
        }
    }

    private inner class HostedWidget(
        private val hostContext: Context,
        private val widgetId: Int,
        private val widthDp: Int,
        private val heightDp: Int
    ) : PlatformView {
        private val container = FrameLayout(hostContext)
        private var hostView: AppWidgetHostView? = null

        init {
            try {
                val info = try { widgetManager.getAppWidgetInfo(widgetId) } catch (_: Throwable) { null }
                if (info != null) {
                    val view: AppWidgetHostView = try {
                        widgetHost.createView(hostContext, widgetId, info)
                    } catch (e: Throwable) {
                        Log.e(TAG, "Failed widgetHost.createView for $widgetId", e)
                        SafeAppWidgetHostView(hostContext).apply {
                            setAppWidget(widgetId, info)
                        }
                    }
                    view.setPadding(0, 0, 0, 0)
                    container.addView(
                        view,
                        FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
                    )
                    hostView = view
                    if (widthDp > 0 && heightDp > 0) {
                        try {
                            @Suppress("DEPRECATION")
                            view.updateAppWidgetSize(Bundle(), widthDp, heightDp, widthDp, heightDp)
                        } catch (_: Exception) {}
                    }
                } else {
                    val tv = TextView(hostContext).apply {
                        text = "Widget unavailable ($widgetId)"
                        setTextColor(Color.GRAY)
                        textSize = 11f
                        gravity = Gravity.CENTER
                    }
                    container.addView(tv)
                }
            } catch (e: Throwable) {
                Log.e(TAG, "HostedWidget init error for $widgetId", e)
                val tv = TextView(hostContext).apply {
                    text = "Widget load failed"
                    setTextColor(Color.GRAY)
                    textSize = 11f
                    gravity = Gravity.CENTER
                }
                try {
                    container.removeAllViews()
                    container.addView(tv)
                } catch (_: Throwable) {}
            }
        }

        override fun getView(): View = container

        override fun dispose() {
            try {
                container.removeAllViews()
                hostView = null
            } catch (_: Throwable) {}
        }
    }

    // ── Contacts Search & Actions ─────────────────────────────────────────────

    private var pendingContactsResult: MethodChannel.Result? = null
    val CONTACTS_PERMISSION_REQUEST_CODE = 3001

    fun hasContactsPermission(): Boolean {
        return ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED
    }

    fun requestContactsPermission(result: MethodChannel.Result) {
        if (hasContactsPermission()) {
            result.success(true)
            return
        }
        pendingContactsResult = result
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.READ_CONTACTS),
            CONTACTS_PERMISSION_REQUEST_CODE
        )
    }

    fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode == CONTACTS_PERMISSION_REQUEST_CODE) {
            val idx = permissions.indexOf(Manifest.permission.READ_CONTACTS)
            val granted = idx != -1 && grantResults.isNotEmpty() && grantResults[idx] == PackageManager.PERMISSION_GRANTED
            pendingContactsResult?.success(granted)
            pendingContactsResult = null
            return true
        }
        return false
    }

    private fun searchContacts(query: String, limit: Int = 20): List<Map<String, Any?>> {
        if (!hasContactsPermission()) return emptyList()
        val cleanQuery = query.trim()
        if (cleanQuery.isEmpty()) return emptyList()

        val results = mutableListOf<Map<String, Any?>>()
        val contactsMap = linkedMapOf<String, MutableMap<String, Any?>>()

        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER,
            ContactsContract.CommonDataKinds.Phone.TYPE,
            ContactsContract.CommonDataKinds.Phone.LABEL,
            ContactsContract.CommonDataKinds.Phone.PHOTO_THUMBNAIL_URI
        )

        val sortOrder = "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC"

        var cursor: android.database.Cursor? = null
        try {
            val filterUri = Uri.withAppendedPath(
                ContactsContract.CommonDataKinds.Phone.CONTENT_FILTER_URI,
                Uri.encode(cleanQuery)
            )
            cursor = activity.contentResolver.query(filterUri, projection, null, null, sortOrder)
        } catch (_: Exception) {
            cursor = null
        }

        if (cursor == null || cursor.count == 0) {
            cursor?.close()
            try {
                val selection = "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ? OR ${ContactsContract.CommonDataKinds.Phone.NUMBER} LIKE ?"
                val selectionArgs = arrayOf("%$cleanQuery%", "%$cleanQuery%")
                cursor = activity.contentResolver.query(
                    ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                    projection,
                    selection,
                    selectionArgs,
                    sortOrder
                )
            } catch (_: Exception) {
                cursor = null
            }
        }

        cursor?.use { c ->
            val idIdx = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.CONTACT_ID)
            val nameIdx = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
            val numIdx = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
            val typeIdx = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.TYPE)
            val labelIdx = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.LABEL)
            val photoIdx = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.PHOTO_THUMBNAIL_URI)

            while (c.moveToNext() && contactsMap.size < limit) {
                val id = if (idIdx >= 0) c.getString(idIdx) ?: "" else ""
                val name = if (nameIdx >= 0) c.getString(nameIdx) ?: "" else ""
                val rawNumber = if (numIdx >= 0) c.getString(numIdx) ?: "" else ""
                val cleanNumber = rawNumber.replace(Regex("[^0-9+]"), "")
                val type = if (typeIdx >= 0) c.getInt(typeIdx) else 0
                val label = if (labelIdx >= 0) c.getString(labelIdx) ?: "" else ""
                val photo = if (photoIdx >= 0) c.getString(photoIdx) else null

                val phoneTypeLabel = when (type) {
                    ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE -> "Mobile"
                    ContactsContract.CommonDataKinds.Phone.TYPE_HOME -> "Home"
                    ContactsContract.CommonDataKinds.Phone.TYPE_WORK -> "Work"
                    ContactsContract.CommonDataKinds.Phone.TYPE_MAIN -> "Main"
                    else -> if (label.isNotEmpty()) label else "Other"
                }

                if (name.isNotEmpty() && rawNumber.isNotEmpty()) {
                    val key = if (id.isNotEmpty()) id else name
                    if (!contactsMap.containsKey(key)) {
                        contactsMap[key] = mutableMapOf(
                            "id" to id,
                            "name" to name,
                            "number" to rawNumber,
                            "cleanNumber" to cleanNumber,
                            "type" to phoneTypeLabel,
                            "photoUri" to photo,
                            "phones" to mutableListOf<Map<String, String>>(
                                mapOf("number" to rawNumber, "cleanNumber" to cleanNumber, "type" to phoneTypeLabel)
                            )
                        )
                    } else {
                        @Suppress("UNCHECKED_CAST")
                        val phonesList = contactsMap[key]!!["phones"] as? MutableList<Map<String, String>>
                        if (phonesList != null && phonesList.none { it["cleanNumber"] == cleanNumber }) {
                            phonesList.add(mapOf("number" to rawNumber, "cleanNumber" to cleanNumber, "type" to phoneTypeLabel))
                        }
                    }
                }
            }
            results.addAll(contactsMap.values)
        }

        return results
    }

    private fun callNumber(number: String): Boolean {
        val clean = number.trim()
        if (clean.isEmpty()) return false
        val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:${Uri.encode(clean)}"))
        return startSafely(intent)
    }

    private fun messageNumber(number: String): Boolean {
        val clean = number.trim()
        if (clean.isEmpty()) return false
        val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:${Uri.encode(clean)}"))
        return startSafely(intent)
    }



    private fun getDeviceCountryCallingCode(): String {
        try {
            val tm = appContext.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
            val simIso = tm?.simCountryIso?.trim()?.uppercase(Locale.ROOT)
            val networkIso = tm?.networkCountryIso?.trim()?.uppercase(Locale.ROOT)
            val localeIso = Locale.getDefault().country?.trim()?.uppercase(Locale.ROOT)
            val iso = if (!simIso.isNullOrEmpty()) simIso else if (!networkIso.isNullOrEmpty()) networkIso else localeIso
            if (!iso.isNullOrEmpty()) {
                val code = COUNTRY_CALLING_CODES[iso]
                if (!code.isNullOrEmpty()) return code
            }
        } catch (_: Exception) {}
        return "91"
    }

    private fun openWhatsApp(number: String, customCountryCode: String? = null): Boolean {
        val trimmed = number.trim()
        if (trimmed.isEmpty()) return false

        val defaultCode = if (!customCountryCode.isNullOrBlank()) {
            customCountryCode.replace(Regex("[^0-9]"), "")
        } else {
            getDeviceCountryCallingCode()
        }.ifEmpty { "91" }

        var digits = trimmed.replace(Regex("[^0-9]"), "")
        if (digits.isEmpty()) return false

        val hasExplicitPlus = trimmed.startsWith("+")
        val hasDoubleZero = trimmed.startsWith("00")

        if (hasDoubleZero) {
            digits = digits.replaceFirst(Regex("^00+"), "")
        } else if (!hasExplicitPlus) {
            // Strip leading domestic trunk zeros (e.g. 09876543210 -> 9876543210)
            val withoutLeadingZeros = digits.replaceFirst(Regex("^0+"), "")

            if (withoutLeadingZeros.length == 10) {
                // Standard 10-digit mobile number: prepend country code
                digits = defaultCode + withoutLeadingZeros
            } else if (withoutLeadingZeros.length in 7..9) {
                digits = defaultCode + withoutLeadingZeros
            } else if (withoutLeadingZeros.length > 10) {
                if (withoutLeadingZeros.startsWith(defaultCode) && withoutLeadingZeros.length == 10 + defaultCode.length) {
                    digits = withoutLeadingZeros
                } else if (withoutLeadingZeros.length == 11 && withoutLeadingZeros.startsWith("1")) {
                    digits = withoutLeadingZeros
                } else if (withoutLeadingZeros.length == 12 && withoutLeadingZeros.startsWith("91")) {
                    digits = withoutLeadingZeros
                } else {
                    digits = withoutLeadingZeros
                }
            } else {
                digits = withoutLeadingZeros
            }
        }

        val url = "https://wa.me/$digits"
        val uri = Uri.parse(url)

        val waIntent = Intent(Intent.ACTION_VIEW, uri).apply {
            setPackage("com.whatsapp")
        }
        if (startSafely(waIntent)) return true

        val waBizIntent = Intent(Intent.ACTION_VIEW, uri).apply {
            setPackage("com.whatsapp.w4b")
        }
        if (startSafely(waBizIntent)) return true

        return startSafely(Intent(Intent.ACTION_VIEW, uri))
    }

    private fun openContact(contactId: String): Boolean {
        if (contactId.isEmpty()) return false
        return try {
            val uri = ContentUris.withAppendedId(ContactsContract.Contacts.CONTENT_URI, contactId.toLong())
            startSafely(Intent(Intent.ACTION_VIEW, uri))
        } catch (_: Exception) {
            false
        }
    }
}
