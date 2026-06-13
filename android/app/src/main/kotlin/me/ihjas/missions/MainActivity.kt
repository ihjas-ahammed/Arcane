package me.ihjas.missions

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "arcane/widget"

        // Held while the Flutter engine is attached so a background widget tap
        // can be applied in-process instead of foregrounding the app.
        @Volatile
        private var channel: MethodChannel? = null

        @Volatile
        private var engineAlive = false

        /**
         * Deliver a widget action to the running Flutter isolate. Returns false
         * when the app process/engine isn't alive, so the caller can fall back
         * to launching the app.
         */
        fun dispatchWidgetAction(action: String): Boolean {
            val ch = channel
            if (!engineAlive || ch == null) return false
            Handler(Looper.getMainLooper()).post {
                try {
                    ch.invokeMethod("widgetAction", action)
                } catch (_: Exception) {
                }
            }
            return true
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        engineAlive = true
    }

    override fun onDestroy() {
        engineAlive = false
        channel = null
        super.onDestroy()
    }
}
