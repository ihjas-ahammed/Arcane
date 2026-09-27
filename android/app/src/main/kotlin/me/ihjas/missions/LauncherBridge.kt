package me.ihjas.missions

import android.app.Activity
import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetHostView
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.LauncherApps
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.location.LocationManager
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Process
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
    }

    val channel = MethodChannel(messenger, CHANNEL)
    private val appContext: Context = activity.applicationContext
    private val pm: PackageManager = activity.packageManager
    private val io = Executors.newFixedThreadPool(2)
    private val main = Handler(Looper.getMainLooper())

    private val widgetManager: AppWidgetManager = AppWidgetManager.getInstance(appContext)
    val widgetHost = AppWidgetHost(appContext, HOST_ID)
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
        packageReceiver?.let { try { activity.unregisterReceiver(it) } catch (_: Exception) {} }
        packageReceiver = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            torchCallback?.let {
                try { (appContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager).unregisterTorchCallback(it) } catch (_: Exception) {}
            }
        }
        io.shutdown()
    }

    /** Returns true when [intent] came from the HOME button / home-screen launch. */
    fun isHomeIntent(intent: Intent?): Boolean =
        intent?.action == Intent.ACTION_MAIN && intent.hasCategory(Intent.CATEGORY_HOME)

    fun isPinRequest(intent: Intent?): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            intent?.action == LauncherApps.ACTION_CONFIRM_PIN_APPWIDGET

    /**
     * Another app (or Arcane itself) called AppWidgetManager.requestPinAppWidget and Android
     * routed the request to us as the default launcher. Bind + configure the widget, accept the
     * request, and tell Dart to place it on the home screen.
     */
    fun handlePinRequest(intent: Intent?): Boolean {
        if (!isPinRequest(intent) || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        try {
            val la = appContext.getSystemService(Context.LAUNCHER_APPS_SERVICE) as LauncherApps
            val request = la.getPinItemRequest(intent) ?: return true
            if (request.requestType != LauncherApps.PinItemRequest.REQUEST_TYPE_APPWIDGET || !request.isValid) return true
            val info = request.getAppWidgetProviderInfo(activity) ?: return true
            startWidgetFlow(info.provider) { desc ->
                val id = (desc?.get("id") as? Int) ?: return@startWidgetFlow
                val accepted = try {
                    request.isValid && request.accept(Bundle().apply { putInt(AppWidgetManager.EXTRA_APPWIDGET_ID, id) })
                } catch (_: Exception) { false }
                if (accepted) {
                    channel.invokeMethod("widgetPinned", desc)
                } else {
                    try { widgetHost.deleteAppWidgetId(id) } catch (_: Exception) {}
                }
            }
        } catch (_: Exception) {}
        return true
    }

    fun onNewIntent(intent: Intent) {
        if (handlePinRequest(intent)) {
            channel.invokeMethod("homePressed", null)
        } else if (isHomeIntent(intent)) {
            channel.invokeMethod("homePressed", null)
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
                if (isHomeIntent(activity.intent) || isPinRequest(activity.intent)) "home" else "app"
            )
            "isDefaultLauncher" -> result.success(isDefaultLauncher())
            "openHomeSettings" -> result.success(startSafely(Intent(Settings.ACTION_HOME_SETTINGS)))
            "getApps" -> background(result) { getApps() }
            "getDefaultApps" -> background(result) { getDefaultApps() }
            "getAppIcons" -> {
                val items = call.argument<List<Map<String, String>>>("items") ?: emptyList()
                val size = call.argument<Int>("size") ?: 144
                background(result) { getAppIcons(items, size) }
            }
            "launchApp" -> result.success(
                launchApp(call.argument<String>("package") ?: "", call.argument<String>("activity"))
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
            else -> result.notImplemented()
        }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            val value = try { work() } catch (e: Exception) { null }
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

    private fun isDefaultLauncher(): Boolean {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val info = pm.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
        return info?.activityInfo?.packageName == activity.packageName
    }

    // ── Apps ─────────────────────────────────────────────────────────────────

    private fun getApps(): List<Map<String, Any?>> {
        val list = mutableListOf<Map<String, Any?>>()
        val la = appContext.getSystemService(Context.LAUNCHER_APPS_SERVICE) as? LauncherApps
        val activities = la?.getActivityList(null, Process.myUserHandle())
        if (activities != null) {
            for (info in activities) {
                val ai = info.applicationInfo
                list.add(mapOf(
                    "package" to info.componentName.packageName,
                    "activity" to info.componentName.className,
                    "label" to (info.label?.toString()?.trim().takeUnless { it.isNullOrEmpty() } ?: info.componentName.packageName),
                    "isSystem" to ((ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0 && (ai.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) == 0),
                    "installTime" to info.firstInstallTime,
                ))
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
                ))
            }
        }
        return list
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

    private fun getAppIcons(items: List<Map<String, String>>, size: Int): Map<String, ByteArray?> {
        val out = HashMap<String, ByteArray?>()
        for (item in items) {
            val key = item["key"] ?: continue
            val pkg = item["package"] ?: continue
            val act = item["activity"]
            val drawable = try {
                if (!act.isNullOrEmpty()) pm.getActivityIcon(ComponentName(pkg, act)) else pm.getApplicationIcon(pkg)
            } catch (_: Exception) {
                try { pm.getApplicationIcon(pkg) } catch (_: Exception) { null }
            }
            out[key] = drawable?.let { encode(it, size) }
        }
        return out
    }

    private fun launchApp(pkg: String, act: String?): Boolean {
        if (pkg.isEmpty()) return false
        if (!act.isNullOrEmpty()) {
            val cn = ComponentName(pkg, act)
            try {
                val la = appContext.getSystemService(Context.LAUNCHER_APPS_SERVICE) as? LauncherApps
                if (la != null) {
                    la.startMainActivity(cn, Process.myUserHandle(), null, null)
                    return true
                }
            } catch (_: Exception) {}
            val intent = Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_LAUNCHER)
                .setComponent(cn)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
            if (startSafely(intent)) return true
        }
        val launch = pm.getLaunchIntentForPackage(pkg) ?: return false
        return startSafely(launch)
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
        val id = widgetHost.allocateAppWidgetId()
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
            } catch (_: Exception) {
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
            @Suppress("UNCHECKED_CAST")
            val params = args as? Map<String, Any?> ?: emptyMap()
            val widgetId = (params["id"] as? Number)?.toInt() ?: AppWidgetManager.INVALID_APPWIDGET_ID
            val widthDp = (params["width"] as? Number)?.toInt() ?: 0
            val heightDp = (params["height"] as? Number)?.toInt() ?: 0
            return HostedWidget(widgetId, widthDp, heightDp)
        }
    }

    private inner class HostedWidget(widgetId: Int, widthDp: Int, heightDp: Int) : PlatformView {
        private val container = FrameLayout(activity)

        init {
            val info = widgetManager.getAppWidgetInfo(widgetId)
            if (info != null) {
                val hostView: AppWidgetHostView = widgetHost.createView(activity, widgetId, info)
                hostView.setPadding(0, 0, 0, 0)
                container.addView(
                    hostView,
                    FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
                )
                if (widthDp > 0 && heightDp > 0) {
                    try {
                        @Suppress("DEPRECATION")
                        hostView.updateAppWidgetSize(Bundle(), widthDp, heightDp, widthDp, heightDp)
                    } catch (_: Exception) {}
                }
            }
        }

        override fun getView(): View = container

        override fun dispose() {
            container.removeAllViews()
        }
    }
}
