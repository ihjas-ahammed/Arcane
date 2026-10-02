package me.ihjas.missions

import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Dedicated activity for the Home Launcher (android.intent.category.HOME).
 *
 * Separated from MainActivity so:
 * 1. The Home screen runs in its own task (taskAffinity="me.ihjas.missions.launcher").
 * 2. MainActivity runs as a standard app (taskAffinity="me.ihjas.missions.app") and
 *    is ALWAYS visible in Android Recents (Overview).
 * 3. The launcher never acts as the main app, and launching Missions opens the main
 *    app directly without launcher interference.
 */
class LauncherActivity : FlutterActivity() {
    private var launcherBridge: LauncherBridge? = null
    private var updateBridge: UpdateBridge? = null

    override fun getInitialRoute(): String = "/launcher"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent?.getBooleanExtra(LauncherTakeoverService.EXTRA_TAKEOVER, false) == true) {
            suppressTransition()
        }
        launcherBridge?.handlePinRequest(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra(LauncherTakeoverService.EXTRA_TAKEOVER, false)) {
            suppressTransition()
        }
        launcherBridge?.onNewIntent(intent)
    }

    private fun suppressTransition() {
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                overrideActivityTransition(android.app.Activity.OVERRIDE_TRANSITION_OPEN, 0, 0)
            } else {
                @Suppress("DEPRECATION")
                overridePendingTransition(0, 0)
            }
        } catch (_: Exception) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        launcherBridge = LauncherBridge(this, flutterEngine.dartExecutor.binaryMessenger).also { bridge ->
            flutterEngine.platformViewsController.registry
                .registerViewFactory(LauncherBridge.VIEW_TYPE, bridge.WidgetViewFactory())
        }
        updateBridge = UpdateBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onStart() {
        super.onStart()
        launcherBridge?.onStart()
    }

    override fun onStop() {
        launcherBridge?.onStop()
        super.onStop()
    }

    override fun onDestroy() {
        launcherBridge?.dispose()
        launcherBridge = null
        super.onDestroy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (launcherBridge?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }
}
