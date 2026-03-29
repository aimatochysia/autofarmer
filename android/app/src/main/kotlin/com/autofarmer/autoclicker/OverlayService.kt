package com.autofarmer.autoclicker

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import androidx.core.app.NotificationCompat

/**
 * Foreground service that displays a transparent full-screen overlay.
 *
 * While active the user can tap anywhere on the screen to add numbered
 * click-point markers. A small "Done" button at the bottom lets the user
 * finish placing points and returns control to the Flutter UI.
 *
 * Events emitted via [setEventCallback]:
 *  - `point_added`   – `{type, x, y, index}`
 *  - `points_cleared`– `{type}`
 *  - `overlay_done`  – `{type}`
 */
class OverlayService : Service() {

    // ── Binder ────────────────────────────────────────────────────────────

    inner class LocalBinder : Binder() {
        fun getService(): OverlayService = this@OverlayService
    }

    private val binder = LocalBinder()

    override fun onBind(intent: Intent?): IBinder = binder

    // ── State ─────────────────────────────────────────────────────────────

    private var windowManager: WindowManager? = null
    private var rootLayout: FrameLayout? = null
    private var drawingView: PointDrawingView? = null
    private var eventCallback: ((Map<String, Any>) -> Unit)? = null

    private companion object {
        const val CHANNEL_ID = "autoclicker_overlay"
        const val NOTIF_ID = 1001
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIF_ID, buildNotification())
        showOverlay()
    }

    override fun onDestroy() {
        super.onDestroy()
        removeOverlay()
    }

    // ── Public API ────────────────────────────────────────────────────────

    fun setEventCallback(callback: (Map<String, Any>) -> Unit) {
        eventCallback = callback
        drawingView?.eventCallback = callback
    }

    // ── Overlay construction ──────────────────────────────────────────────

    @SuppressLint("ClickableViewAccessibility")
    private fun showOverlay() {
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )

        // Container
        rootLayout = FrameLayout(this)

        // Drawing layer that captures taps and draws numbered circles
        drawingView = PointDrawingView(this).also { dv ->
            dv.eventCallback = eventCallback
        }
        rootLayout!!.addView(
            drawingView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )

        // Bottom action bar: "Clear" and "Done"
        val actionBar = buildActionBar()
        val actionParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply { gravity = Gravity.BOTTOM }
        rootLayout!!.addView(actionBar, actionParams)

        windowManager!!.addView(rootLayout, params)
    }

    private fun buildActionBar(): FrameLayout {
        val bar = FrameLayout(this)
        bar.setBackgroundColor(Color.argb(180, 0, 0, 0))

        val clearBtn = Button(this).apply {
            text = "Clear"
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.TRANSPARENT)
            setOnClickListener {
                drawingView?.clearPoints()
                eventCallback?.invoke(mapOf("type" to "points_cleared"))
            }
        }

        val doneBtn = Button(this).apply {
            text = "Done ✓"
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.argb(200, 98, 0, 238))
            setOnClickListener {
                eventCallback?.invoke(mapOf("type" to "overlay_done"))
                stopSelf()
            }
        }

        val clearParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply { gravity = Gravity.START or Gravity.CENTER_VERTICAL }

        val doneParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply { gravity = Gravity.END or Gravity.CENTER_VERTICAL }

        bar.addView(clearBtn, clearParams)
        bar.addView(doneBtn, doneParams)
        return bar
    }

    private fun removeOverlay() {
        rootLayout?.let {
            try { windowManager?.removeView(it) } catch (e: IllegalArgumentException) {
                android.util.Log.w("AutoFarmer", "Overlay view already removed: ${e.message}")
            }
        }
        rootLayout = null
        drawingView = null
    }

    // ── Notification ──────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "AutoFarmer Overlay",
                NotificationManager.IMPORTANCE_LOW
            ).apply { description = "Shows while placing click targets" }
            (getSystemService(NotificationManager::class.java))
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AutoFarmer – Placing Targets")
            .setContentText("Tap the screen to add click points. Tap Done when finished.")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setOngoing(true)
            .build()
}

// ── PointDrawingView ─────────────────────────────────────────────────────────

/**
 * Full-screen transparent view that:
 *  - captures touch-down events and records them as click points
 *  - draws a numbered red circle at each recorded position
 *  - notifies [eventCallback] on every new point
 */
@SuppressLint("ViewConstructor", "ClickableViewAccessibility")
private class PointDrawingView(context: android.content.Context) : View(context) {

    var eventCallback: ((Map<String, Any>) -> Unit)? = null

    private val points = mutableListOf<Pair<Float, Float>>()

    private val circlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.RED
        style = Paint.Style.FILL
        alpha = 200
    }
    private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.STROKE
        strokeWidth = 4f
        alpha = 230
    }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 36f
        textAlign = Paint.Align.CENTER
        isFakeBoldText = true
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        points.forEachIndexed { i, (x, y) ->
            canvas.drawCircle(x, y, 36f, circlePaint)
            canvas.drawCircle(x, y, 36f, borderPaint)
            // Vertically center text inside the circle
            val textY = y - (textPaint.descent() + textPaint.ascent()) / 2
            canvas.drawText("${i + 1}", x, textY, textPaint)
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (event.action == MotionEvent.ACTION_DOWN) {
            val x = event.rawX
            val y = event.rawY
            val index = points.size
            points.add(x to y)
            invalidate()
            eventCallback?.invoke(
                mapOf(
                    "type" to "point_added",
                    "x" to x.toDouble(),
                    "y" to y.toDouble(),
                    "index" to index
                )
            )
            return true
        }
        return super.onTouchEvent(event)
    }

    fun clearPoints() {
        points.clear()
        invalidate()
    }
}
