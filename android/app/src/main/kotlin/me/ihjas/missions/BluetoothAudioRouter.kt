package me.ihjas.missions

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * Manages routing voice and microphone streams to connected Bluetooth audio
 * devices (SCO headsets, BLE headsets, hearing aids, and call-capable smartwatches).
 *
 * Supports an optional experimental "Force Bluetooth Call SCO" simulation mode
 * designed for smartwatches that only support phone calls (HFP/SCO) rather than
 * standard media audio.
 */
object BluetoothAudioRouter {
    private const val TAG = "BluetoothAudioRouter"
    private const val PREFS_AUTO_TAP = "arcane_auto_tap"
    private const val KEY_FORCE_SCO_CALL = "force_bluetooth_sco_call"

    private val mainHandler = Handler(Looper.getMainLooper())
    private var scoReceiver: BroadcastReceiver? = null
    private var keepAliveTrack: AudioTrack? = null
    private var safetyTimeoutRunnable: Runnable? = null
    private var isScoCallActive = false

    fun isForceBluetoothScoCallEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_AUTO_TAP, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_FORCE_SCO_CALL, false)
    }

    fun setForceBluetoothScoCallEnabled(context: Context, enabled: Boolean) {
        val prefs = context.getSharedPreferences(PREFS_AUTO_TAP, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_FORCE_SCO_CALL, enabled).apply()
        Log.i(TAG, "Force Bluetooth SCO Call set to $enabled")
    }

    fun routeAudio(context: Context, enable: Boolean) {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        val forceScoCall = isForceBluetoothScoCallEnabled(context)

        Log.i(TAG, "routeAudio(enable=$enable, forceScoCall=$forceScoCall)")

        if (enable) {
            startAudioRouting(context, audioManager, forceScoCall)
        } else {
            stopAudioRouting(context, audioManager)
        }
    }

    private fun startAudioRouting(context: Context, audioManager: AudioManager, forceScoCall: Boolean) {
        try {
            // Cancel any pending teardown
            safetyTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }

            // 1. Set mode to communication (VoIP / two-way audio state)
            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
            audioManager.isSpeakerphoneOn = false

            // 2. Android 12+ Communication Device selection
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val devices = audioManager.availableCommunicationDevices
                val btDevice = devices.firstOrNull {
                    it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                    it.type == AudioDeviceInfo.TYPE_BLE_HEADSET ||
                    it.type == AudioDeviceInfo.TYPE_HEARING_AID
                }
                if (btDevice != null) {
                    val res = audioManager.setCommunicationDevice(btDevice)
                    Log.i(TAG, "setCommunicationDevice(${btDevice.productName}, type=${btDevice.type}) result: $res")
                }
            }

            // 3. Bluetooth SCO link initialization (crucial for call-only smartwatches or pre-Android 12)
            if (forceScoCall || (Build.VERSION.SDK_INT < Build.VERSION_CODES.S && audioManager.isBluetoothScoAvailableOffCall)) {
                registerScoReceiver(context)
                try {
                    audioManager.startBluetoothSco()
                    audioManager.isBluetoothScoOn = true
                    Log.i(TAG, "startBluetoothSco() requested")
                } catch (e: Exception) {
                    Log.w(TAG, "startBluetoothSco failed", e)
                }

                if (forceScoCall) {
                    // Start low-level silent keep-alive track so Android's audio server doesn't
                    // tear down the SCO link while waiting for the assistant app to bind to mic
                    startKeepAliveTrack()
                }
            }

            isScoCallActive = true

            // 4. Safety watchdog timer: release after 120s to prevent permanent in-call audio lock
            val timeout = Runnable {
                Log.i(TAG, "Safety timeout reached (120s). Releasing Bluetooth SCO call mode.")
                stopAudioRouting(context, audioManager)
            }
            safetyTimeoutRunnable = timeout
            mainHandler.postDelayed(timeout, 120_000L)

        } catch (e: Exception) {
            Log.e(TAG, "Error starting audio routing", e)
        }
    }

    private fun stopAudioRouting(context: Context, audioManager: AudioManager) {
        try {
            safetyTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
            safetyTimeoutRunnable = null

            stopKeepAliveTrack()
            unregisterScoReceiver(context)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                try {
                    audioManager.clearCommunicationDevice()
                } catch (_: Exception) {}
            }

            if (audioManager.isBluetoothScoOn) {
                try {
                    audioManager.stopBluetoothSco()
                    audioManager.isBluetoothScoOn = false
                } catch (_: Exception) {}
            }

            audioManager.mode = AudioManager.MODE_NORMAL
            audioManager.isSpeakerphoneOn = false
            isScoCallActive = false
            Log.i(TAG, "Audio mode reset to MODE_NORMAL, SCO stopped.")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping audio routing", e)
        }
    }

    private fun registerScoReceiver(context: Context) {
        if (scoReceiver != null) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(c: Context?, intent: Intent?) {
                if (intent?.action == AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED) {
                    val state = intent.getIntExtra(AudioManager.EXTRA_SCO_AUDIO_STATE, AudioManager.SCO_AUDIO_STATE_ERROR)
                    when (state) {
                        AudioManager.SCO_AUDIO_STATE_CONNECTED -> {
                            Log.i(TAG, "ACTION_SCO_AUDIO_STATE_UPDATED: CONNECTED to Bluetooth SCO audio link")
                        }
                        AudioManager.SCO_AUDIO_STATE_CONNECTING -> {
                            Log.i(TAG, "ACTION_SCO_AUDIO_STATE_UPDATED: CONNECTING...")
                        }
                        AudioManager.SCO_AUDIO_STATE_DISCONNECTED -> {
                            Log.i(TAG, "ACTION_SCO_AUDIO_STATE_UPDATED: DISCONNECTED")
                        }
                    }
                }
            }
        }
        val filter = IntentFilter(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.applicationContext.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                context.applicationContext.registerReceiver(receiver, filter)
            }
            scoReceiver = receiver
        } catch (e: Exception) {
            Log.w(TAG, "Failed to register SCO receiver", e)
        }
    }

    private fun unregisterScoReceiver(context: Context) {
        val receiver = scoReceiver ?: return
        try {
            context.applicationContext.unregisterReceiver(receiver)
        } catch (_: Exception) {}
        scoReceiver = null
    }

    private fun startKeepAliveTrack() {
        if (keepAliveTrack != null) return
        try {
            val sampleRate = 8000
            val bufferSize = AudioTrack.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            ).coerceAtLeast(1024)

            val track = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setBufferSizeInBytes(bufferSize)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()

            track.play()
            // Write a tiny silent buffer
            val silentBytes = ByteArray(bufferSize)
            track.write(silentBytes, 0, bufferSize)
            keepAliveTrack = track
            Log.i(TAG, "Bluetooth SCO Keep-alive track active")
        } catch (e: Exception) {
            Log.w(TAG, "Could not start keepAliveTrack", e)
        }
    }

    private fun stopKeepAliveTrack() {
        try {
            keepAliveTrack?.stop()
            keepAliveTrack?.release()
        } catch (_: Exception) {}
        keepAliveTrack = null
    }
}
