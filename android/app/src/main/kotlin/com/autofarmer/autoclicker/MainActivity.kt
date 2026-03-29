package com.autofarmer.autoclicker

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val methodChannelName = "com.autofarmer.autoclicker/control"
    private val eventChannelName = "com.autofarmer.autoclicker/events"

    private var overlayService: OverlayService? = null
    private var eventSink: EventChannel.EventSink? = null

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            val localBinder = binder as? OverlayService.LocalBinder
            overlayService = localBinder?.getService()
            overlayService?.setEventCallback { event ->
                runOnUiThread { eventSink?.success(event) }
            }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            overlayService = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkOverlayPermission" ->
                        result.success(checkOverlayPermission())

                    "requestOverlayPermission" -> {
                        requestOverlayPermission()
                        result.success(null)
                    }

                    "checkAccessibilityPermission" ->
                        result.success(checkAccessibilityPermission())

                    "requestAccessibilityPermission" -> {
                        requestAccessibilityPermission()
                        result.success(null)
                    }

                    "startOverlay" -> {
                        if (checkOverlayPermission()) startOverlayService()
                        result.success(null)
                    }

                    "stopOverlay" -> {
                        stopOverlayService()
                        result.success(null)
                    }

                    "startAutoClicker" -> {
                        @Suppress("UNCHECKED_CAST")
                        val points =
                            call.argument<List<Map<String, Any>>>("points") ?: emptyList()
                        val delay = call.argument<Int>("delay") ?: 250
                        val variance = call.argument<Int>("randomVariance") ?: 50
                        startAutoClicker(points, delay, variance)
                        result.success(null)
                    }

                    "stopAutoClicker" -> {
                        stopAutoClicker()
                        result.success(null)
                    }

                    "isAutoClickerRunning" ->
                        result.success(AutoClickAccessibilityService.isRunning)

                    else -> result.notImplemented()
                }
            }
    }

    // ── Permission helpers ────────────────────────────────────────────────

    private fun checkOverlayPermission(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
        }
    }

    private fun checkAccessibilityPermission(): Boolean {
        val service =
            "$packageName/${AutoClickAccessibilityService::class.java.canonicalName}"
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabled.contains(service)
    }

    private fun requestAccessibilityPermission() {
        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
    }

    // ── Overlay service ───────────────────────────────────────────────────

    private fun startOverlayService() {
        val intent = Intent(this, OverlayService::class.java)
        startForegroundService(intent)
        bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
    }

    private fun stopOverlayService() {
        try { unbindService(serviceConnection) } catch (e: IllegalArgumentException) {
            android.util.Log.w("AutoFarmer", "Overlay service not bound: ${e.message}")
        }
        stopService(Intent(this, OverlayService::class.java))
        overlayService = null
    }

    // ── Auto-clicker ──────────────────────────────────────────────────────

    private fun startAutoClicker(
        points: List<Map<String, Any>>,
        delay: Int,
        variance: Int
    ) {
        val prefs = getSharedPreferences("autoclicker_prefs", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putString("click_points", pointsToJson(points))
            putInt("delay_ms", delay)
            putInt("random_variance_ms", variance)
            putBoolean("should_click", true)
            apply()
        }
        AutoClickAccessibilityService.instance?.startClicking()
    }

    private fun stopAutoClicker() {
        getSharedPreferences("autoclicker_prefs", Context.MODE_PRIVATE)
            .edit().putBoolean("should_click", false).apply()
        AutoClickAccessibilityService.instance?.stopClicking()
    }

    /** Converts a list of point maps into a JSON array string. */
    private fun pointsToJson(points: List<Map<String, Any>>): String {
        val sb = StringBuilder("[")
        points.forEachIndexed { i, p ->
            if (i > 0) sb.append(",")
            sb.append("""{"x":${p["x"]},"y":${p["y"]}}""")
        }
        sb.append("]")
        return sb.toString()
    }
}
