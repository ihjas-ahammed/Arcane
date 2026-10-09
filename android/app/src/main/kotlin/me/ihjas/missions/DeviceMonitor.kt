package me.ihjas.missions

import android.annotation.SuppressLint
import android.app.ActivityManager
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import org.json.JSONObject
import java.io.File
import java.util.UUID

/**
 * Append-only record of everything a paired / connected device tells us (GATT notifications,
 * classic Bluetooth broadcasts, the watch app's own notifications). Lives in a file so data
 * keeps accumulating while the Flutter UI is closed; the Devices screen reads it back.
 */
object DeviceEventLog {
    private const val FILE = "device_events.jsonl"
    private const val MAX_BYTES = 1_500_000L
    private val lock = Any()

    /** Live listener (the Devices screen while it is open). */
    @Volatile var sink: ((Map<String, Any?>) -> Unit)? = null

    fun append(context: Context, source: String, device: String?, kind: String, data: Map<String, Any?>) {
        val ts = System.currentTimeMillis()
        val obj = JSONObject().apply {
            put("ts", ts)
            put("source", source)
            put("device", device ?: "")
            put("kind", kind)
            put("data", JSONObject(data.filterValues { it != null }))
        }
        try {
            synchronized(lock) {
                val f = File(context.filesDir, FILE)
                if (f.exists() && f.length() > MAX_BYTES) {
                    val lines = f.readLines()
                    f.writeText(lines.drop(lines.size / 2).joinToString("\n", postfix = "\n"))
                }
                f.appendText(obj.toString() + "\n")
            }
        } catch (_: Exception) {
        }
        val live = sink ?: return
        val map = mapOf("ts" to ts, "source" to source, "device" to (device ?: ""), "kind" to kind, "data" to data)
        Handler(Looper.getMainLooper()).post { try { live(map) } catch (_: Exception) {} }
    }

    /** Newest [limit] events as raw JSON lines, oldest first. */
    fun read(context: Context, limit: Int): List<String> = synchronized(lock) {
        try {
            val f = File(context.filesDir, FILE)
            if (!f.exists()) emptyList() else f.readLines().filter { it.isNotBlank() }.takeLast(limit)
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun clear(context: Context) = synchronized(lock) {
        try { File(context.filesDir, FILE).delete() } catch (_: Exception) {}
        Unit
    }
}

/**
 * Process-wide Bluetooth capture: classic-profile broadcasts plus any number of GATT
 * connections whose every readable / notifying characteristic is logged.
 */
@SuppressLint("MissingPermission")
object DeviceMonitor {
    private const val CCCD = "00002902-0000-1000-8000-00805f9b34fb"

    private lateinit var app: Context
    private val main = Handler(Looper.getMainLooper())
    private var started = false
    private val gatts = HashMap<String, BluetoothGatt>()
    private val queues = HashMap<String, ArrayDeque<() -> Unit>>()
    private val busy = HashSet<String>()
    private var scanCallback: ScanCallback? = null

    private val adapter: BluetoothAdapter?
        get() = (app.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    fun hasConnectPermission(context: Context): Boolean =
        Build.VERSION.SDK_INT < 31 ||
            ContextCompat.checkSelfPermission(context, android.Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    fun hasScanPermission(context: Context): Boolean =
        if (Build.VERSION.SDK_INT >= 31)
            ContextCompat.checkSelfPermission(context, android.Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
        else
            ContextCompat.checkSelfPermission(context, android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

    fun isBluetoothOn(): Boolean = try { adapter?.isEnabled == true } catch (_: Exception) { false }
    fun connectedAddresses(): List<String> = synchronized(gatts) { gatts.keys.toList() }

    private fun log(source: String, device: String?, kind: String, data: Map<String, Any?>) =
        DeviceEventLog.append(app, source, device, kind, data)

    // ── Classic broadcasts ───────────────────────────────────────

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val action = intent.action ?: return
            val dev: BluetoothDevice? = try {
                if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                else @Suppress("DEPRECATION") intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
            } catch (_: Exception) { null }
            val addr = dev?.address
            val data = mutableMapOf<String, Any?>("action" to action.substringAfterLast('.'))
            try { dev?.name?.let { data["name"] = it } } catch (_: Exception) {}
            // Every extra the system attached (battery %, bond state, vendor AT commands, …).
            intent.extras?.keySet()?.forEach { k ->
                if (k == BluetoothDevice.EXTRA_DEVICE) return@forEach
                val v = try { intent.extras?.get(k) } catch (_: Exception) { null }
                data[k.substringAfterLast('.')] = when (v) {
                    is ByteArray -> hex(v)
                    is Array<*> -> v.joinToString(",") { it.toString() }
                    null -> null
                    else -> v.toString()
                }
            }
            log("classic", addr, "broadcast", data)
        }
    }

    fun start(context: Context) {
        if (started) return
        app = context.applicationContext
        started = true
        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
            addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
            addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
            addAction(BluetoothDevice.ACTION_NAME_CHANGED)
            addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
            addAction("android.bluetooth.device.action.BATTERY_LEVEL_CHANGED")
            addAction("android.bluetooth.headset.action.VENDOR_SPECIFIC_HEADSET_EVENT")
            addAction("android.bluetooth.headset.profile.action.CONNECTION_STATE_CHANGED")
            addAction("android.bluetooth.a2dp.profile.action.CONNECTION_STATE_CHANGED")
            addAction("android.bluetooth.headset.profile.action.AUDIO_STATE_CHANGED")
        }
        try {
            if (Build.VERSION.SDK_INT >= 33) app.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
            else app.registerReceiver(receiver, filter)
        } catch (_: Exception) {
        }
    }

    // ── Devices & scanning ───────────────────────────────────────

    fun bonded(): List<Map<String, Any?>> {
        if (!hasConnectPermission(app)) return emptyList()
        val out = mutableListOf<Map<String, Any?>>()
        for (d in adapter?.bondedDevices ?: emptySet()) {
            var battery: Int? = null
            try {
                val m = d.javaClass.getMethod("getBatteryLevel")
                (m.invoke(d) as? Int)?.takeIf { it in 0..100 }?.let { battery = it }
            } catch (_: Exception) {}
            out.add(mapOf(
                "address" to d.address,
                "name" to (d.name ?: d.address),
                "type" to when (d.type) {
                    BluetoothDevice.DEVICE_TYPE_CLASSIC -> "classic"
                    BluetoothDevice.DEVICE_TYPE_LE -> "le"
                    BluetoothDevice.DEVICE_TYPE_DUAL -> "dual"
                    else -> "unknown"
                },
                "majorClass" to (d.bluetoothClass?.majorDeviceClass ?: -1),
                "uuids" to ((d.uuids ?: emptyArray()).map { it.toString() }),
                "battery" to battery,
                "gatt" to synchronized(gatts) { gatts.containsKey(d.address) },
            ))
        }
        return out
    }

    fun startScan(): Boolean {
        val scanner = adapter?.bluetoothLeScanner ?: return false
        if (!hasScanPermission(app)) return false
        stopScan()
        val cb = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val rec = result.scanRecord
                val mfr = rec?.manufacturerSpecificData
                val mfrMap = mutableMapOf<String, String>()
                if (mfr != null) for (i in 0 until mfr.size()) mfrMap["0x%04X".format(mfr.keyAt(i))] = hex(mfr.valueAt(i))
                val svcData = mutableMapOf<String, String>()
                rec?.serviceData?.forEach { (k, v) -> svcData[k.toString()] = hex(v) }
                DeviceEventLog.sink?.let { live ->
                    val map = mapOf(
                        "ts" to System.currentTimeMillis(), "source" to "scan", "device" to result.device.address, "kind" to "scanResult",
                        "data" to mapOf(
                            "name" to (rec?.deviceName ?: result.device.name),
                            "rssi" to result.rssi,
                            "services" to (rec?.serviceUuids?.map { it.toString() } ?: emptyList<String>()),
                            "manufacturer" to mfrMap,
                            "serviceData" to svcData,
                            "raw" to rec?.bytes?.let { hex(it) },
                        ),
                    )
                    main.post { try { live(map) } catch (_: Exception) {} }
                }
            }
        }
        scanCallback = cb
        return try {
            scanner.startScan(null, ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(), cb)
            main.postDelayed({ if (scanCallback === cb) stopScan() }, 25_000)
            true
        } catch (_: Exception) { scanCallback = null; false }
    }

    fun stopScan() {
        val cb = scanCallback ?: return
        scanCallback = null
        try { adapter?.bluetoothLeScanner?.stopScan(cb) } catch (_: Exception) {}
        DeviceEventLog.sink?.let { live -> main.post { try { live(mapOf("ts" to System.currentTimeMillis(), "source" to "scan", "device" to "", "kind" to "scanStopped", "data" to emptyMap<String, Any?>())) } catch (_: Exception) {} } }
    }

    // ── GATT ─────────────────────────────────────────────────────

    fun connect(address: String): Boolean {
        if (!hasConnectPermission(app)) return false
        val dev = try { adapter?.getRemoteDevice(address) } catch (_: Exception) { null } ?: return false
        disconnect(address)
        val gatt = try {
            if (Build.VERSION.SDK_INT >= 23) dev.connectGatt(app, true, gattCallback, BluetoothDevice.TRANSPORT_LE)
            else dev.connectGatt(app, true, gattCallback)
        } catch (_: Exception) { null } ?: return false
        synchronized(gatts) { gatts[address] = gatt }
        log("gatt", address, "connecting", mapOf("name" to (dev.name ?: address)))
        return true
    }

    fun disconnect(address: String) {
        val g = synchronized(gatts) { gatts.remove(address) } ?: return
        queues.remove(address)
        busy.remove(address)
        try { g.disconnect(); g.close() } catch (_: Exception) {}
        log("gatt", address, "disconnected", mapOf("reason" to "user"))
    }

    private fun enqueue(address: String, op: () -> Unit) {
        main.post {
            queues.getOrPut(address) { ArrayDeque() }.addLast(op)
            pump(address)
        }
    }

    private fun pump(address: String) {
        if (busy.contains(address)) return
        val op = queues[address]?.removeFirstOrNull() ?: return
        busy.add(address)
        // An op that never calls back must not stall the queue.
        main.postDelayed({ if (busy.remove(address)) pump(address) }, 4000)
        try { op() } catch (_: Exception) { busy.remove(address); pump(address) }
    }

    private fun done(address: String) {
        main.post { busy.remove(address); pump(address) }
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            val addr = gatt.device.address
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                log("gatt", addr, "connected", mapOf("status" to status))
                main.post { try { if (!gatt.requestMtu(247)) gatt.discoverServices() } catch (_: Exception) {} }
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                log("gatt", addr, "disconnected", mapOf("status" to status, "reason" to "link"))
                queues.remove(addr); busy.remove(addr)
                // autoConnect=true: the stack reconnects by itself when the watch is back in range.
            }
        }

        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
            log("gatt", gatt.device.address, "mtu", mapOf("mtu" to mtu))
            main.post { try { gatt.discoverServices() } catch (_: Exception) {} }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            val addr = gatt.device.address
            val tree = gatt.services.map { s ->
                mapOf("uuid" to s.uuid.toString(), "chars" to s.characteristics.map { c ->
                    mapOf("uuid" to c.uuid.toString(), "props" to propNames(c.properties), "name" to nameOf(c.uuid))
                })
            }
            log("gatt", addr, "services", mapOf("services" to tree))
            for (s in gatt.services) for (c in s.characteristics) {
                val p = c.properties
                if (p and BluetoothGattCharacteristic.PROPERTY_READ != 0) enqueue(addr) { gatt.readCharacteristic(c) }
                if (p and (BluetoothGattCharacteristic.PROPERTY_NOTIFY or BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0) {
                    enqueue(addr) {
                        gatt.setCharacteristicNotification(c, true)
                        val d = c.getDescriptor(UUID.fromString(CCCD))
                        if (d == null) { done(addr); return@enqueue }
                        val v = if (p and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0) BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                                else BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
                        if (Build.VERSION.SDK_INT >= 33) gatt.writeDescriptor(d, v)
                        else @Suppress("DEPRECATION") run { d.value = v; gatt.writeDescriptor(d) }
                    }
                }
            }
        }

        override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
            done(gatt.device.address)
        }

        @Deprecated("API 33 replaced this")
        override fun onCharacteristicRead(gatt: BluetoothGatt, c: BluetoothGattCharacteristic, status: Int) {
            if (Build.VERSION.SDK_INT >= 33) return
            @Suppress("DEPRECATION") emit(gatt, c, c.value, "read", status)
        }

        override fun onCharacteristicRead(gatt: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray, status: Int) {
            emit(gatt, c, value, "read", status)
        }

        @Deprecated("API 33 replaced this")
        override fun onCharacteristicChanged(gatt: BluetoothGatt, c: BluetoothGattCharacteristic) {
            if (Build.VERSION.SDK_INT >= 33) return
            @Suppress("DEPRECATION") emit(gatt, c, c.value, "notify", 0)
        }

        override fun onCharacteristicChanged(gatt: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray) {
            emit(gatt, c, value, "notify", 0)
        }
    }

    private fun emit(gatt: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray?, how: String, status: Int) {
        val addr = gatt.device.address
        if (how == "read") done(addr)
        if (value == null || (how == "read" && status != BluetoothGatt.GATT_SUCCESS)) return
        val data = mutableMapOf<String, Any?>(
            "how" to how,
            "service" to c.service.uuid.toString(),
            "char" to c.uuid.toString(),
            "name" to nameOf(c.uuid),
            "hex" to hex(value),
            "text" to printable(value),
        )
        parse(c.uuid, value)?.let { data["parsed"] = it }
        log("gatt", addr, "data", data)
    }

    // ── Decoding ─────────────────────────────────────────────────

    private fun hex(b: ByteArray) = b.joinToString(" ") { "%02X".format(it) }

    private fun printable(b: ByteArray): String? {
        if (b.isEmpty() || b.any { it < 32 || it > 126 }) return null
        return String(b, Charsets.US_ASCII)
    }

    private fun propNames(p: Int): List<String> = buildList {
        if (p and BluetoothGattCharacteristic.PROPERTY_READ != 0) add("read")
        if (p and BluetoothGattCharacteristic.PROPERTY_WRITE != 0) add("write")
        if (p and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0) add("writeNoResp")
        if (p and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0) add("notify")
        if (p and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0) add("indicate")
    }

    private fun short(u: UUID): String? {
        val s = u.toString()
        return if (s.endsWith("-0000-1000-8000-00805f9b34fb")) s.substring(4, 8).uppercase() else null
    }

    private fun nameOf(u: UUID): String? = when (short(u)) {
        "2A00" -> "Device Name"; "2A01" -> "Appearance"; "2A19" -> "Battery Level"
        "2A24" -> "Model Number"; "2A25" -> "Serial Number"; "2A26" -> "Firmware Rev"
        "2A27" -> "Hardware Rev"; "2A28" -> "Software Rev"; "2A29" -> "Manufacturer"
        "2A37" -> "Heart Rate"; "2A38" -> "Body Sensor Location"; "2A53" -> "RSC Measurement"
        "2A5B" -> "CSC Measurement"; "2A2B" -> "Current Time"; "2A63" -> "Cycling Power"
        "2A98" -> "Weight"; "2A9D" -> "Weight Measurement"; "2A35" -> "Blood Pressure"
        "2A1C" -> "Temperature"; "2A5F" -> "SpO2 Continuous"; "2A5E" -> "SpO2 Spot-check"
        "2A56" -> "Digital"; "2A3F" -> "Alert Status"; "2AA7" -> "CGM Measurement"
        else -> null
    }

    /** Decodes the standard health characteristics; everything else stays raw hex. */
    private fun parse(u: UUID, v: ByteArray): String? = try {
        when (short(u)) {
            "2A19" -> "${v[0].toInt() and 0xFF}%"
            "2A37" -> {
                val flags = v[0].toInt() and 0xFF
                val bpm = if (flags and 1 == 0) v[1].toInt() and 0xFF else ((v[2].toInt() and 0xFF) shl 8) or (v[1].toInt() and 0xFF)
                "$bpm bpm"
            }
            "2A53" -> {
                val speed = (((v[2].toInt() and 0xFF) shl 8) or (v[1].toInt() and 0xFF)) / 256.0
                "%.2f m/s".format(speed)
            }
            else -> null
        }
    } catch (_: Exception) { null }
}

/**
 * Keeps the user's watch companion app (Mi Fitness, Zepp, Galaxy Wearable, …) running. Every
 * [CHECK_MS] the process list is read, and the app is started only when its process is not in it.
 * The check is driven by the notification listener service, which the system keeps bound.
 */
object WatchKeepAlive {
    private const val PREFS = "arcane_devices"
    private const val K_PKG = "watch_pkg"
    private const val K_ON = "watch_keepalive"
    private const val K_LAST_CHECK = "watch_last_check"
    private const val K_RESTARTS = "watch_restarts"
    private const val K_LAST_RESTART = "watch_last_restart"
    const val CHECK_MS = 10 * 60_000L

    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    fun pkg(c: Context): String = prefs(c).getString(K_PKG, "") ?: ""
    fun enabled(c: Context): Boolean = prefs(c).getBoolean(K_ON, false)

    fun set(c: Context, pkg: String?, enabled: Boolean?) {
        val e = prefs(c).edit()
        if (pkg != null) e.putString(K_PKG, pkg)
        if (enabled != null) e.putBoolean(K_ON, enabled)
        e.apply()
    }

    fun status(c: Context): Map<String, Any?> {
        val p = prefs(c)
        return mapOf(
            "package" to pkg(c), "enabled" to enabled(c),
            "lastCheck" to p.getLong(K_LAST_CHECK, 0L), "restarts" to p.getInt(K_RESTARTS, 0),
            "lastRestart" to p.getLong(K_LAST_RESTART, 0L),
        )
    }

    /**
     * true when the watch app's process is listed, false when it is not, and null when the list
     * cannot answer. From Android 5 a normal app only sees its own processes, so if nothing else is
     * listed the answer is null and the app is left alone rather than started again and again.
     */
    fun isRunning(c: Context, pkg: String): Boolean? {
        val am = c.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return null
        val procs = try { am.runningAppProcesses } catch (_: Exception) { null } ?: return null
        if (procs.none { !it.processName.startsWith(c.packageName) }) return null
        return procs.any { it.processName == pkg || it.processName.startsWith("$pkg:") }
    }

    /** One check: starts the watch app only if its process is not running. Called every [CHECK_MS]. */
    fun heartbeat(c: Context) {
        val pkg = pkg(c)
        if (pkg.isEmpty() || !enabled(c)) return
        prefs(c).edit().putLong(K_LAST_CHECK, System.currentTimeMillis()).apply()
        when (isRunning(c, pkg)) {
            true -> Unit
            false -> restart(c, "process not running")
            null -> DeviceEventLog.append(c, "keepalive", pkg, "unknown",
                mapOf("reason" to "process list not readable for other apps"))
        }
    }

    /** Watch-app notifications are kept for the Devices screen. They no longer drive the keep-alive. */
    fun onPosted(svc: android.service.notification.NotificationListenerService, sbn: android.service.notification.StatusBarNotification) {
        val pkg = pkg(svc)
        if (pkg.isEmpty() || sbn.packageName != pkg) return
        val ex = sbn.notification?.extras ?: return
        val title = ex.getCharSequence(android.app.Notification.EXTRA_TITLE)?.toString()
        val text = ex.getCharSequence(android.app.Notification.EXTRA_TEXT)?.toString()
        val big = ex.getCharSequence(android.app.Notification.EXTRA_BIG_TEXT)?.toString()
        val sub = ex.getCharSequence(android.app.Notification.EXTRA_SUB_TEXT)?.toString()
        val sig = "$title|$text|$big|$sub"
        if (sig == lastSig[sbn.id]) return
        lastSig[sbn.id] = sig
        DeviceEventLog.append(svc, "watch-app", pkg, "notification",
            mapOf("title" to title, "text" to text, "bigText" to big, "subText" to sub, "id" to sbn.id))
    }

    private val lastSig = HashMap<Int, String>()

    fun restart(context: Context, reason: String): Boolean {
        val pkg = pkg(context)
        if (pkg.isEmpty()) return false
        val p = prefs(context)
        val intent = context.packageManager.getLaunchIntentForPackage(pkg)?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) ?: return false
        return try {
            context.startActivity(intent)
            p.edit().putInt(K_RESTARTS, p.getInt(K_RESTARTS, 0) + 1)
                .putLong(K_LAST_RESTART, System.currentTimeMillis()).apply()
            DeviceEventLog.append(context, "keepalive", pkg, "restart", mapOf("reason" to reason))
            true
        } catch (e: Exception) {
            DeviceEventLog.append(context, "keepalive", pkg, "restartFailed", mapOf("error" to e.message))
            false
        }
    }
}
