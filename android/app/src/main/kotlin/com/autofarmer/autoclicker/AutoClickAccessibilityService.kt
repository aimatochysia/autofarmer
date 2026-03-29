package com.autofarmer.autoclicker

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Context
import android.graphics.Path
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import kotlin.math.max
import kotlin.random.Random

/**
 * Accessibility service that performs automated taps on the screen.
 *
 * Settings (click points, delay, variance) are read from SharedPreferences
 * so they can be written by [MainActivity] without an IPC boundary.
 */
class AutoClickAccessibilityService : AccessibilityService() {

    companion object {
        /** Live singleton reference – set when the service is connected. */
        var instance: AutoClickAccessibilityService? = null

        /** Whether the clicker loop is currently active. */
        @Volatile
        var isRunning: Boolean = false
    }

    private val handler = Handler(Looper.getMainLooper())
    private var pendingClick: Runnable? = null
    private var currentPointIndex = 0

    // ── Lifecycle ─────────────────────────────────────────────────────────

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Not needed for gesture-based auto-clicking
    }

    override fun onInterrupt() {
        stopClicking()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopClicking()
        if (instance === this) instance = null
    }

    // ── Public control API ────────────────────────────────────────────────

    fun startClicking() {
        stopClicking()
        isRunning = true
        currentPointIndex = 0
        scheduleNextClick()
    }

    fun stopClicking() {
        isRunning = false
        pendingClick?.let { handler.removeCallbacks(it) }
        pendingClick = null
        currentPointIndex = 0
    }

    // ── Internal loop ─────────────────────────────────────────────────────

    private fun scheduleNextClick() {
        if (!isRunning) return

        val prefs = getSharedPreferences("autoclicker_prefs", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("should_click", false)) {
            stopClicking()
            return
        }

        val points = parsePoints(prefs.getString("click_points", "[]") ?: "[]")
        if (points.isEmpty()) {
            stopClicking()
            return
        }

        val baseDelay = prefs.getInt("delay_ms", 250).toLong()
        val variance = prefs.getInt("random_variance_ms", 50).toLong()

        // Random offset in the range [-variance, +variance]
        val offset = if (variance > 0) Random.nextLong(-variance, variance + 1) else 0L
        val actualDelay = max(1L, baseDelay + offset)

        val point = points[currentPointIndex % points.size]
        pendingClick = Runnable {
            if (!isRunning) return@Runnable
            performTap(point.first, point.second)
            currentPointIndex = (currentPointIndex + 1) % points.size
            scheduleNextClick()
        }
        handler.postDelayed(pendingClick!!, actualDelay)
    }

    private fun performTap(x: Float, y: Float) {
        val path = Path().apply { moveTo(x, y) }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0L, 50L))
            .build()
        dispatchGesture(gesture, null, null)
    }

    // ── JSON parsing (no external dependency) ────────────────────────────

    /**
     * Parses a minimal JSON array of `{"x":…,"y":…}` objects.
     * Example: `[{"x":100.0,"y":200.0},{"x":300.0,"y":400.0}]`
     */
    private fun parsePoints(json: String): List<Pair<Float, Float>> {
        val result = mutableListOf<Pair<Float, Float>>()
        val objectPattern = Regex("""\{\s*"x"\s*:\s*([\d.]+)\s*,\s*"y"\s*:\s*([\d.]+)\s*\}""")
        objectPattern.findAll(json).forEach { match ->
            val x = match.groupValues[1].toFloatOrNull() ?: return@forEach
            val y = match.groupValues[2].toFloatOrNull() ?: return@forEach
            result.add(x to y)
        }
        return result
    }
}
