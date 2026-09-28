package me.ihjas.missions

import android.app.Application
import android.content.Context
import android.os.Process
import android.util.Log
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.system.exitProcess

/**
 * Installs [CrashGuard] before anything else runs in the process (activity, accessibility
 * service, widget receivers).
 */
class ArcaneApplication : Application() {
    override fun onCreate() {
        CrashGuard.install(this)
        super.onCreate()
    }
}

/**
 * Keeps Arcane the default home app when it crashes.
 *
 * Android clears the preferred home app every time a non-system home app crashes
 * (ActivityTaskManager: "Clearing package preferred activities"), so the next HOME press asks
 * "Select a Home app" again. That happens inside the system's crash path, which the default
 * uncaught-exception handler enters. This handler records the crash to a log file instead and
 * then ends the process quietly: the system treats it as a normal process death, keeps Arcane as
 * the default, and simply relaunches it on the next HOME press.
 *
 * The log (Settings › Home Launcher › Crash log) is how the real causes get found and fixed.
 */
object CrashGuard {
    private const val FILE = "crash_log.txt"
    private const val MAX_BYTES = 96 * 1024
    private const val KEEP_BYTES = 64 * 1024
    const val SEPARATOR = "\n\n──────────\n\n"

    @Volatile private var handling = false

    fun install(context: Context) {
        val app = context.applicationContext
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            // A second crash while recording the first: just die.
            if (!handling) {
                handling = true
                try {
                    record(app, thread, error)
                } catch (_: Throwable) {
                }
            }
            Process.killProcess(Process.myPid())
            exitProcess(10)
        }
    }

    private fun record(context: Context, thread: Thread, error: Throwable) {
        val trace = StringWriter().also { error.printStackTrace(PrintWriter(it)) }.toString()
        val time = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
        val version = try {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageInfo(context.packageName, 0).versionName
        } catch (_: Exception) {
            "?"
        }
        val entry = "$time · v$version · thread \"${thread.name}\"\n${trace.take(6000).trimEnd()}"
        Log.e("CrashGuard", "Caught crash, keeping Arcane as home app:\n$entry")

        val file = File(context.filesDir, FILE)
        val existing = if (file.exists()) file.readText() else ""
        var text = if (existing.isEmpty()) entry else existing + SEPARATOR + entry
        if (text.length > MAX_BYTES) {
            // Drop the oldest entries, cutting at an entry boundary.
            val tail = text.takeLast(KEEP_BYTES)
            val cut = tail.indexOf(SEPARATOR)
            text = if (cut >= 0) tail.substring(cut + SEPARATOR.length) else tail
        }
        file.writeText(text)
    }

    /** Recorded crashes, oldest first. */
    fun read(context: Context): List<String> {
        val file = File(context.filesDir, FILE)
        if (!file.exists()) return emptyList()
        return file.readText().split(SEPARATOR).map { it.trim() }.filter { it.isNotEmpty() }
    }

    fun clear(context: Context) {
        File(context.filesDir, FILE).delete()
    }
}
