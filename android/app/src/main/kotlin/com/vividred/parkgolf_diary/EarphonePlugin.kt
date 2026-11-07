package com.vividred.parkgolf_diary

import android.annotation.SuppressLint
import android.bluetooth.BluetoothA2dp
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothHeadset
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothSocket
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 블루투스 이어폰 연동 (Android).
 * - 연결 상태 · 이름 · 마이크(HFP) 여부 · 전체 배터리(HFP)
 * - 주변 이어폰 검색 · 페어링 · 연결 / 해제
 * - 에어팟 BLE 광고(애플 0x004C) 원본 전달 → Dart에서 왼쪽 · 오른쪽 · 케이스 배터리 · 착용 해석
 * - 에어팟 AACP(L2CAP 0x1001) 채널: 착용 · 1% 배터리 · 청취 모드 · 기기 정보 · 이름 변경 (휴대폰이 허용할 때만)
 * - 이어폰 마이크(SCO)로 음성 입력
 * 숨김 API는 일반 반사로만 시도하고, 막힌 휴대폰에서는 조용히 실패해요.
 */
class EarphonePlugin(private val ctx: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val method = MethodChannel(messenger, "parkgolf/earphone")
    private val events = EventChannel(messenger, "parkgolf/earphone/events")
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null

    private val adapter: BluetoothAdapter?
        get() = ctx.getSystemService(BluetoothManager::class.java)?.adapter

    private var a2dp: BluetoothProfile? = null
    private var headset: BluetoothProfile? = null
    private var lastBattery: Int? = null
    private var receiverOn = false
    private var bleCallback: ScanCallback? = null
    @Volatile private var aacp: Aacp? = null

    init {
        method.setMethodCallHandler(this)
        events.setStreamHandler(this)
        bindProfiles()
    }

    // ── 전달 ─────────────────────────────

    private fun emit(m: Map<String, Any?>) = main.post { sink?.success(m) }

    override fun onListen(arguments: Any?, s: EventChannel.EventSink?) {
        sink = s
        registerReceiver()
        emit(state())
    }

    override fun onCancel(arguments: Any?) {
        sink = null
        stopBle()
        try { if (receiverOn) ctx.unregisterReceiver(receiver) } catch (_: Exception) {}
        receiverOn = false
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "state" -> result.success(state())
                "bonded" -> result.success(bonded())
                "startDiscovery" -> result.success(startDiscovery())
                "stopDiscovery" -> { safe { adapter?.cancelDiscovery() }; result.success(true) }
                "pair" -> result.success(pair(call.argument<String>("address")!!))
                "connect" -> result.success(connectProfiles(device(call.argument("address")), true))
                "disconnect" -> result.success(connectProfiles(device(call.argument("address")), false))
                "openSettings" -> {
                    ctx.startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(true)
                }
                "startBle" -> result.success(startBle())
                "stopBle" -> { stopBle(); result.success(true) }
                "aacpStart" -> result.success(aacpStart())
                "aacpStop" -> { aacp?.close(); aacp = null; result.success(true) }
                "aacpSend" -> result.success(aacp?.send(call.argument<ByteArray>("data")!!) ?: false)
                "scoStart" -> result.success(sco(true))
                "scoStop" -> result.success(sco(false))
                else -> result.notImplemented()
            }
        } catch (e: SecurityException) {
            result.error("permission", e.message, null)
        } catch (e: Exception) {
            result.error("error", e.message, null)
        }
    }

    private inline fun <T> safe(f: () -> T): T? = try { f() } catch (_: Exception) { null }

    // ── 연결 상태 ─────────────────────────────

    private fun bindProfiles() {
        val a = adapter ?: return
        val l = object : BluetoothProfile.ServiceListener {
            override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                if (profile == BluetoothProfile.A2DP) a2dp = proxy else headset = proxy
                emit(state())
            }
            override fun onServiceDisconnected(profile: Int) {
                if (profile == BluetoothProfile.A2DP) a2dp = null else headset = null
            }
        }
        safe { a.getProfileProxy(ctx, l, BluetoothProfile.A2DP) }
        safe { a.getProfileProxy(ctx, l, BluetoothProfile.HEADSET) }
    }

    @SuppressLint("MissingPermission")
    private fun connectedDevice(): BluetoothDevice? =
        safe { a2dp?.connectedDevices?.firstOrNull() } ?: safe { headset?.connectedDevices?.firstOrNull() }

    @SuppressLint("MissingPermission")
    private fun state(): Map<String, Any?> {
        val a = adapter
        val d = connectedDevice()
        val mic = d != null && (safe { headset?.connectedDevices?.any { it.address == d.address } } ?: false)
        val bat = d?.let { readBattery(it) } ?: if (d == null) null else lastBattery
        if (d == null) lastBattery = null else if (bat != null) lastBattery = bat
        return mapOf(
            "type" to "state",
            "supported" to (a != null),
            "enabled" to (safe { a?.isEnabled } ?: false),
            "connected" to (d != null),
            "name" to d?.let { safe { it.alias ?: it.name } ?: safe { it.name } },
            "address" to d?.address,
            "mic" to mic,
            "battery" to bat,
        )
    }

    @SuppressLint("DiscouragedPrivateApi")
    private fun readBattery(d: BluetoothDevice): Int? = try {
        val v = d.javaClass.getMethod("getBatteryLevel").invoke(d) as Int
        if (v in 0..100) v else lastBattery
    } catch (_: Throwable) { lastBattery }

    @SuppressLint("MissingPermission")
    private fun device(address: String?): BluetoothDevice? = address?.let { safe { adapter?.getRemoteDevice(it) } }

    // ── 검색 · 페어링 ─────────────────────────────

    @SuppressLint("MissingPermission")
    private fun bonded(): List<Map<String, Any?>> =
        (safe { adapter?.bondedDevices?.toList() } ?: emptyList()).map { describe(it, true) }

    @SuppressLint("MissingPermission")
    private fun describe(d: BluetoothDevice, bonded: Boolean): Map<String, Any?> {
        val cls = safe { d.bluetoothClass }
        val major = cls?.majorDeviceClass
        val audio = major == BluetoothClass.Device.Major.AUDIO_VIDEO
        val mic = cls?.hasService(BluetoothClass.Service.AUDIO) == true &&
            (cls.deviceClass == BluetoothClass.Device.AUDIO_VIDEO_WEARABLE_HEADSET ||
                cls.deviceClass == BluetoothClass.Device.AUDIO_VIDEO_HANDSFREE ||
                safe { cls.hasService(BluetoothClass.Service.TELEPHONY) } == true ||
                cls.deviceClass == BluetoothClass.Device.AUDIO_VIDEO_HEADPHONES)
        return mapOf(
            "type" to "found",
            "name" to (safe { d.alias ?: d.name } ?: safe { d.name }),
            "address" to d.address,
            "audio" to audio,
            "headset" to (cls?.deviceClass == BluetoothClass.Device.AUDIO_VIDEO_WEARABLE_HEADSET ||
                cls?.deviceClass == BluetoothClass.Device.AUDIO_VIDEO_HANDSFREE),
            "mic" to mic,
            "bonded" to bonded,
        )
    }

    @SuppressLint("MissingPermission")
    private fun startDiscovery(): Boolean {
        val a = adapter ?: return false
        registerReceiver()
        safe { a.cancelDiscovery() }
        return a.startDiscovery()
    }

    @SuppressLint("MissingPermission")
    private fun pair(address: String): Boolean {
        val d = device(address) ?: return false
        safe { adapter?.cancelDiscovery() }
        if (d.bondState == BluetoothDevice.BOND_BONDED) return connectProfiles(d, true)
        return d.createBond()
    }

    /** 음악(A2DP) · 통화(HFP) 프로파일 연결 / 해제 — 숨김 API라 막힌 휴대폰에서는 false. */
    private fun connectProfiles(d: BluetoothDevice?, connect: Boolean): Boolean {
        d ?: return false
        var ok = false
        for (p in listOfNotNull(a2dp, headset)) {
            try {
                val m = p.javaClass.getMethod(if (connect) "connect" else "disconnect", BluetoothDevice::class.java)
                if (m.invoke(p, d) == true) ok = true
            } catch (_: Throwable) {}
        }
        return ok
    }

    // ── 방송 수신 ─────────────────────────────

    private val receiver = object : BroadcastReceiver() {
        @SuppressLint("MissingPermission")
        override fun onReceive(c: Context, i: Intent) {
            when (i.action) {
                BluetoothDevice.ACTION_FOUND -> {
                    val d: BluetoothDevice? = if (Build.VERSION.SDK_INT >= 33)
                        i.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                    else @Suppress("DEPRECATION") i.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                    if (d != null) emit(describe(d, safe { d.bondState == BluetoothDevice.BOND_BONDED } ?: false))
                }
                BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> emit(mapOf("type" to "discoveryDone"))
                BluetoothDevice.ACTION_BOND_STATE_CHANGED -> {
                    val d: BluetoothDevice? = if (Build.VERSION.SDK_INT >= 33)
                        i.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                    else @Suppress("DEPRECATION") i.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                    val st = i.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, -1)
                    if (d != null && st == BluetoothDevice.BOND_BONDED) connectProfiles(d, true)
                    emit(mapOf("type" to "bond", "address" to d?.address, "bonded" to (st == BluetoothDevice.BOND_BONDED),
                        "bonding" to (st == BluetoothDevice.BOND_BONDING)))
                }
                ACTION_BATTERY -> {
                    val v = i.getIntExtra(EXTRA_BATTERY, -1)
                    if (v in 0..100) lastBattery = v
                    emit(state())
                }
                BluetoothHeadset.ACTION_VENDOR_SPECIFIC_HEADSET_EVENT -> {
                    @Suppress("DEPRECATION")
                    val args = i.extras?.get(BluetoothHeadset.EXTRA_VENDOR_SPECIFIC_HEADSET_EVENT_ARGS) as? Array<*>
                    appleAccEv(args)?.let { lastBattery = it; emit(state()) }
                }
                else -> main.postDelayed({ emit(state()) }, 300)
            }
        }
    }

    private fun appleAccEv(args: Array<*>?): Int? {
        if (args == null || args.isEmpty()) return null
        fun num(i: Int) = when (val a = args.getOrNull(i)) { is Number -> a.toInt(); is String -> a.trim().toIntOrNull(); else -> null }
        val pairs = num(0) ?: return null
        for (k in 0 until pairs) {
            val key = num(1 + 2 * k) ?: return null
            val value = num(2 + 2 * k) ?: return null
            if (key == 1 && value in 0..9) return (value + 1) * 10
        }
        return null
    }

    private fun registerReceiver() {
        if (receiverOn) return
        val f = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
            addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
            addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
            addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
            addAction(BluetoothA2dp.ACTION_CONNECTION_STATE_CHANGED)
            addAction(BluetoothHeadset.ACTION_CONNECTION_STATE_CHANGED)
            addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
            addAction(ACTION_BATTERY)
            addAction(BluetoothHeadset.ACTION_VENDOR_SPECIFIC_HEADSET_EVENT)
            addCategory(BluetoothHeadset.VENDOR_SPECIFIC_HEADSET_EVENT_COMPANY_ID_CATEGORY + "." + BluetoothAssignedNumbers_APPLE)
        }
        try {
            if (Build.VERSION.SDK_INT >= 33) ctx.registerReceiver(receiver, f, Context.RECEIVER_EXPORTED)
            else ctx.registerReceiver(receiver, f)
            receiverOn = true
        } catch (_: Exception) {}
    }

    // ── 에어팟 BLE 광고 ─────────────────────────────

    @SuppressLint("MissingPermission")
    private fun startBle(): Boolean {
        if (bleCallback != null) return true
        val scanner = safe { adapter?.bluetoothLeScanner } ?: return false
        val cb = object : ScanCallback() {
            override fun onScanResult(type: Int, r: ScanResult) {
                val data = r.scanRecord?.getManufacturerSpecificData(APPLE_ID) ?: return
                if (r.rssi < -70) return // 내 이어폰만 (가까운 것)
                emit(mapOf("type" to "ble", "data" to data, "rssi" to r.rssi))
            }
        }
        val filter = ScanFilter.Builder().setManufacturerData(APPLE_ID, byteArrayOf()).build()
        val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build()
        return try { scanner.startScan(listOf(filter), settings, cb); bleCallback = cb; true } catch (_: Exception) { false }
    }

    @SuppressLint("MissingPermission")
    private fun stopBle() {
        val cb = bleCallback ?: return
        safe { adapter?.bluetoothLeScanner?.stopScan(cb) }
        bleCallback = null
    }

    // ── 에어팟 AACP ─────────────────────────────

    private fun aacpStart(): Boolean {
        if (aacp != null) return true
        val a = adapter ?: return false
        val d = connectedDevice() ?: return false
        val client = Aacp(a, d,
            onState = { s, msg -> emit(mapOf("type" to "aacpState", "state" to s, "message" to msg)); if (s != "connected") aacp = null },
            onPacket = { p -> emit(mapOf("type" to "aacp", "data" to p)) })
        aacp = client
        Thread { client.run() }.apply { isDaemon = true; start() }
        return true
    }

    // ── 이어폰 마이크 (SCO) ─────────────────────────────

    @Suppress("DEPRECATION")
    private fun sco(on: Boolean): Boolean {
        val am = ctx.getSystemService(AudioManager::class.java) ?: return false
        return try {
            if (Build.VERSION.SDK_INT >= 31) {
                if (on) {
                    val dev = am.availableCommunicationDevices.firstOrNull { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO }
                        ?: return false
                    am.setCommunicationDevice(dev)
                } else { am.clearCommunicationDevice(); true }
            } else {
                if (on) { am.startBluetoothSco(); am.isBluetoothScoOn = true } else { am.isBluetoothScoOn = false; am.stopBluetoothSco() }
                true
            }
        } catch (_: Exception) { false }
    }

    companion object {
        private const val APPLE_ID = 0x004C
        private const val BluetoothAssignedNumbers_APPLE = 0x004C
        private const val ACTION_BATTERY = "android.bluetooth.device.action.BATTERY_LEVEL_CHANGED"
        private const val EXTRA_BATTERY = "android.bluetooth.device.extra.BATTERY_LEVEL"
    }
}

/** AACP 채널(L2CAP PSM 0x1001). 공개 API로는 클래식 L2CAP 소켓을 만들 수 없어 숨김 생성자를 일반 반사로 시도해요. */
private class Aacp(
    private val adapter: BluetoothAdapter,
    private val device: BluetoothDevice,
    private val onState: (String, String?) -> Unit,
    private val onPacket: (ByteArray) -> Unit,
) {
    @Volatile private var socket: BluetoothSocket? = null
    @Volatile private var closed = false

    private fun bytes(vararg v: Int) = ByteArray(v.size) { v[it].toByte() }

    @SuppressLint("MissingPermission")
    fun run() {
        val s = try { createSocket() } catch (e: Throwable) { onState("failed", "socket"); return }
        socket = s
        val watchdog = Thread {
            try { Thread.sleep(5000) } catch (_: InterruptedException) { return@Thread }
            if (!s.isConnected) close()
        }.apply { isDaemon = true; start() }
        try { s.connect() } catch (e: Throwable) { watchdog.interrupt(); onState("failed", "connect"); close(); return }
        watchdog.interrupt()
        try {
            val init = listOf(
                bytes(0x00, 0x00, 0x04, 0x00, 0x01, 0x00, 0x02, 0x00, 0, 0, 0, 0, 0, 0, 0, 0),
                bytes(0x04, 0x00, 0x04, 0x00, 0x4D, 0x00, 0xD7, 0x00, 0, 0, 0, 0, 0, 0),
                bytes(0x04, 0x00, 0x04, 0x00, 0x0F, 0x00, 0xFF, 0xFF, 0xFF, 0xFF),
            )
            for (p in init) { send(p); Thread.sleep(200) }
            onState("connected", null)
            val buf = ByteArray(8192)
            val input = s.inputStream
            while (!closed) {
                val n = input.read(buf)
                if (n < 0) break
                if (n > 0) onPacket(buf.copyOf(n))
            }
        } catch (_: Throwable) {
        } finally { close(); onState("closed", null) }
    }

    fun send(p: ByteArray): Boolean {
        val s = socket ?: return false
        if (closed || !s.isConnected) return false
        return try { synchronized(this) { s.outputStream.write(p); s.outputStream.flush() }; true } catch (_: Exception) { false }
    }

    fun close() { closed = true; try { socket?.close() } catch (_: Exception) {} }

    @SuppressLint("DiscouragedPrivateApi", "SoonBlockedPrivateApi", "BlockedPrivateApi")
    private fun createSocket(): BluetoothSocket {
        val type = 3 // TYPE_L2CAP
        val psm = 0x1001
        val uuid = ParcelUuid.fromString("74ec2172-0bad-4d01-8f77-997b2be0722a")
        val i = Integer.TYPE; val z = java.lang.Boolean.TYPE
        val A = BluetoothAdapter::class.java; val D = BluetoothDevice::class.java; val U = ParcelUuid::class.java
        val candidates = listOf(
            arrayOf(A, D, i, z, z, i, U) to arrayOf<Any>(adapter, device, type, true, true, psm, uuid),
            arrayOf(D, i, z, z, i, U) to arrayOf<Any>(device, type, true, true, psm, uuid),
            arrayOf(D, i, i, z, z, i, U) to arrayOf<Any>(device, type, -1, true, true, psm, uuid),
            arrayOf(i, i, z, z, D, i, U) to arrayOf<Any>(type, -1, true, true, device, psm, uuid),
            arrayOf(i, z, z, D, i, U) to arrayOf<Any>(type, true, true, device, psm, uuid),
        )
        for ((types, args) in candidates) {
            try {
                val c = BluetoothSocket::class.java.getDeclaredConstructor(*types)
                c.isAccessible = true
                return c.newInstance(*args) as BluetoothSocket
            } catch (_: Throwable) {}
        }
        throw IllegalStateException("no constructor")
    }
}
