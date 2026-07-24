package com.maliyati.app

import android.animation.ValueAnimator
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.GestureDetector
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

class FloatingInputService : Service() {
    private var bubble: View? = null
    private var trashZone: View? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var trashParams: WindowManager.LayoutParams? = null
    private lateinit var windowManager: WindowManager

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_HIDE) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (!Settings.canDrawOverlays(this)) {
            stopSelf()
            return START_NOT_STICKY
        }
        startForeground(NOTIFICATION_ID, notification())
        showBubble()
        return START_STICKY
    }

    override fun onDestroy() {
        if (::windowManager.isInitialized) {
            bubble?.let { runCatching { windowManager.removeView(it) } }
            trashZone?.let { runCatching { windowManager.removeView(it) } }
        }
        bubble = null
        trashZone = null
        bubbleParams = null
        trashParams = null
        super.onDestroy()
    }

    private fun showBubble() {
        if (bubble != null) return
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        val density = resources.displayMetrics.density
        val size = (60 * density).toInt()
        val edge = (12 * density).toInt()
        val touchSlop = 7 * density
        val bubbleView = createBubbleView(size)
        val params = overlayParams(size, size).apply {
            gravity = Gravity.START or Gravity.TOP
            x = resources.displayMetrics.widthPixels - size - edge
            y = (resources.displayMetrics.heightPixels - size) / 2
        }
        bubble = bubbleView
        bubbleParams = params
        windowManager.addView(bubbleView, params)

        var startX = 0
        var startY = 0
        var startTouchX = 0f
        var startTouchY = 0f
        var dragged = false

        val detector = GestureDetector(
            this,
            object : GestureDetector.SimpleOnGestureListener() {
                override fun onDown(event: MotionEvent): Boolean = true

                override fun onSingleTapUp(event: MotionEvent): Boolean {
                    if (!dragged) {
                        openSmartInput()
                    }
                    return true
                }

                override fun onLongPress(event: MotionEvent) {
                    hideBubblePermanently()
                }
            },
        )

        bubbleView.setOnTouchListener { view, event ->
            detector.onTouchEvent(event)
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    startX = params.x
                    startY = params.y
                    startTouchX = event.rawX
                    startTouchY = event.rawY
                    dragged = false
                    view.animate().scaleX(1.08f).scaleY(1.08f).setDuration(90).start()
                    showTrashZone()
                    true
                }

                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - startTouchX
                    val dy = event.rawY - startTouchY
                    if (abs(dx) > touchSlop || abs(dy) > touchSlop) {
                        dragged = true
                    }
                    params.x = clampX(startX + dx.toInt(), size)
                    params.y = clampY(startY + dy.toInt(), size)
                    windowManager.updateViewLayout(view, params)
                    updateTrashState(params.x + size / 2, params.y + size / 2)
                    true
                }

                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    view.animate().scaleX(1f).scaleY(1f).setDuration(110).start()
                    if (isOverTrash(params.x + size / 2, params.y + size / 2)) {
                        hideBubblePermanently()
                    } else {
                        hideTrashZone()
                        snapBubbleToEdge(size)
                    }
                    true
                }

                else -> true
            }
        }
    }

    private fun createBubbleView(size: Int): FrameLayout {
        val density = resources.displayMetrics.density

        return FrameLayout(this).apply {
            alpha = 0.96f
            elevation = 18f
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 18 * density
                setColor(Color.WHITE)
                setStroke((1.2f * density).toInt(), Color.argb(72, 11, 92, 173))
            }

            addView(
                ImageView(this@FloatingInputService).apply {
                    setImageResource(R.drawable.maliyati_floating_icon)
                    scaleType = ImageView.ScaleType.CENTER_CROP
                    setPadding(
                        (4 * density).toInt(),
                        (4 * density).toInt(),
                        (4 * density).toInt(),
                        (4 * density).toInt(),
                    )
                    contentDescription = "Open Maliyati quick input"
                },
                FrameLayout.LayoutParams(
                    size,
                    size,
                    Gravity.CENTER,
                ),
            )
        }
    }

    private fun showTrashZone() {
        if (trashZone != null) return
        val density = resources.displayMetrics.density
        val size = (62 * density).toInt()
        val bottom = (28 * density).toInt()
        val view = TextView(this).apply {
            text = "X"
            textSize = 20f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            alpha = 0f
            scaleX = 0.74f
            scaleY = 0.74f
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.argb(158, 25, 32, 36))
                setStroke((1 * density).toInt(), Color.argb(80, 255, 255, 255))
            }
            elevation = 12f
        }
        val params = overlayParams(size, size).apply {
            gravity = Gravity.START or Gravity.TOP
            x = (resources.displayMetrics.widthPixels - size) / 2
            y = resources.displayMetrics.heightPixels - size - bottom
        }
        trashZone = view
        trashParams = params
        windowManager.addView(view, params)
        view.animate().alpha(0.68f).scaleX(0.92f).scaleY(0.92f).setDuration(120).start()
    }

    private fun hideTrashZone() {
        val view = trashZone ?: return
        view.animate()
            .alpha(0f)
            .scaleX(0.74f)
            .scaleY(0.74f)
            .setDuration(110)
            .withEndAction {
                if (trashZone === view && ::windowManager.isInitialized) {
                    runCatching { windowManager.removeView(view) }
                    trashZone = null
                    trashParams = null
                }
            }
            .start()
    }

    private fun updateTrashState(centerX: Int, centerY: Int) {
        val view = trashZone ?: return
        val inside = isOverTrash(centerX, centerY)
        val scale = if (inside) 1.08f else 0.92f
        val color = if (inside) Color.argb(210, 213, 43, 56) else Color.argb(158, 25, 32, 36)
        (view.background as? GradientDrawable)?.setColor(color)
        view.animate().scaleX(scale).scaleY(scale).setDuration(80).start()
    }

    private fun isOverTrash(centerX: Int, centerY: Int): Boolean {
        val params = trashParams ?: return false
        val width = params.width
        val height = params.height
        val extra = (18 * resources.displayMetrics.density).toInt()
        return centerX in (params.x - extra)..(params.x + width + extra) &&
            centerY in (params.y - extra)..(params.y + height + extra)
    }

    private fun snapBubbleToEdge(size: Int) {
        val view = bubble ?: return
        val params = bubbleParams ?: return
        val screenWidth = resources.displayMetrics.widthPixels
        val edge = (12 * resources.displayMetrics.density).toInt()
        val targetX = if (params.x + size / 2 < screenWidth / 2) edge else screenWidth - size - edge
        val startX = params.x
        val animator = ValueAnimator.ofInt(startX, targetX).apply {
            duration = 180
            interpolator = DecelerateInterpolator()
            addUpdateListener {
                params.x = it.animatedValue as Int
                if (::windowManager.isInitialized) {
                    runCatching { windowManager.updateViewLayout(view, params) }
                }
            }
        }
        animator.start()
    }

    private fun overlayParams(width: Int, height: Int): WindowManager.LayoutParams {
        return WindowManager.LayoutParams(
            width,
            height,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        )
    }

    private fun clampX(value: Int, size: Int): Int {
        return min(max(0, value), resources.displayMetrics.widthPixels - size)
    }

    private fun clampY(value: Int, size: Int): Int {
        return min(max(0, value), resources.displayMetrics.heightPixels - size)
    }

    private fun openSmartInput() {
        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit()
            .putBoolean("flutter.smart_clipboard_bubble_tapped", true)
            .apply()
        startActivity(
            Intent(this, MainActivity::class.java).apply {
                action = ACTION_OPEN_INPUT
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
        )
    }

    private fun hideBubblePermanently() {
        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit()
            .putBoolean("flutter.smart_clipboard_enabled", false)
            .apply()
        stopSelf()
    }

    private fun notification(): Notification {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Maliyati floating input",
                    NotificationManager.IMPORTANCE_LOW,
                ),
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(R.drawable.ic_launcher_finance)
            .setContentTitle("Maliyati quick input")
            .setContentText("Tap the floating button after copying text")
            .build()
    }

    companion object {
        const val ACTION_SHOW = "com.maliyati.app.SHOW_FLOATING_INPUT"
        const val ACTION_HIDE = "com.maliyati.app.HIDE_FLOATING_INPUT"
        const val ACTION_OPEN_INPUT = "com.maliyati.app.OPEN_SMART_INPUT"
        private const val CHANNEL_ID = "maliyati_quick_input"
        private const val NOTIFICATION_ID = 4501
    }
}
