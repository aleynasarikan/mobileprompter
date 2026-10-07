package app.cueline.teleprompter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.TextUtils
import android.text.style.ForegroundColorSpan
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.TextView

/**
 * Process-local handle so the activity can update the overlay without
 * putting the whole script into an [Intent] (those are size-limited).
 */
internal object CreatorOverlayBridge {
    private var service: CreatorOverlayService? = null
    private var words: List<String> = emptyList()
    var activeIndex: Int = -1
        private set
    var useMicrophone: Boolean = false
        private set

    fun isRunning(): Boolean = service != null

    fun attach(service: CreatorOverlayService) {
        this.service = service
        service.render(words, activeIndex)
    }

    fun detach(service: CreatorOverlayService) {
        if (this.service === service) this.service = null
    }

    fun prepare(words: List<String>, index: Int, useMicrophone: Boolean) {
        this.words = words
        activeIndex = index
        this.useMicrophone = useMicrophone
        service?.render(words, index)
    }

    fun update(index: Int): Boolean {
        activeIndex = index
        val current = service ?: return false
        current.render(words, index)
        return true
    }

    fun stop() {
        val current = service
        clear()
        current?.shutdown()
    }

    private fun clear() {
        words = emptyList()
        activeIndex = -1
        useMicrophone = false
    }
}

/**
 * Small draggable script window drawn over other apps.
 *
 * The view is owned by the service, not the activity, so it stays after the
 * user leaves this app. Touches outside the box pass through
 * ([WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE]).
 */
class CreatorOverlayService : Service() {
    private var windowManager: WindowManager? = null
    private var overlayView: TextView? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    private var inForeground = false
    private var dragStartX = 0
    private var dragStartY = 0
    private var dragTouchX = 0f
    private var dragTouchY = 0f

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW -> {
                // Promote before adding the window. A service started with
                // startForegroundService is killed if startForeground is late.
                startAsForeground()
                if (!showOverlay()) {
                    stopOverlay(startId)
                } else {
                    CreatorOverlayBridge.attach(this)
                }
            }
            ACTION_HIDE -> {
                CreatorOverlayBridge.stop()
            }
            else -> if (!inForeground) stopSelf(startId)
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        removeOverlay()
        CreatorOverlayBridge.detach(this)
        super.onDestroy()
    }

    fun shutdown() {
        if (inForeground) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            inForeground = false
        }
        stopSelf()
    }

    fun render(words: List<String>, activeIndex: Int) {
        overlayView?.text = scriptSpan(words, activeIndex)
    }

    private fun startAsForeground() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val withMic = CreatorOverlayBridge.useMicrophone && hasMicPermission()
            val type = if (withMic) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            } else {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            }
            try {
                startForeground(NOTIFICATION_ID, notification, type)
            } catch (_: SecurityException) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
                )
            }
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        inForeground = true
    }

    private fun hasMicPermission(): Boolean {
        return checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun showOverlay(): Boolean {
        if (overlayView != null) return true
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || !Settings.canDrawOverlays(this)) {
            return false
        }

        val manager = getSystemService(WINDOW_SERVICE) as WindowManager
        val params = overlayLayoutParams()
        val view = overlayTextView()
        view.setOnTouchListener { touched, event ->
            dragOverlay(touched, event)
        }

        return try {
            manager.addView(view, params)
            windowManager = manager
            layoutParams = params
            overlayView = view
            true
        } catch (_: RuntimeException) {
            false
        }
    }

    private fun overlayLayoutParams(): WindowManager.LayoutParams {
        return WindowManager.LayoutParams(
            dp(280),
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(16)
            y = dp(96)
        }
    }

    private fun overlayTextView(): TextView {
        return TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 16f
            maxLines = 8
            ellipsize = TextUtils.TruncateAt.END
            setPadding(dp(16), dp(12), dp(16), dp(12))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#E6121212"))
                cornerRadius = dp(12).toFloat()
            }
            isClickable = true
            isFocusable = false
            isFocusableInTouchMode = false
        }
    }

    private fun dragOverlay(view: View, event: MotionEvent): Boolean {
        val params = layoutParams ?: return false
        val manager = windowManager ?: return false
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                dragStartX = params.x
                dragStartY = params.y
                dragTouchX = event.rawX
                dragTouchY = event.rawY
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                params.x = dragStartX + (event.rawX - dragTouchX).toInt()
                params.y = dragStartY + (event.rawY - dragTouchY).toInt()
                clampToScreen(params, view)
                manager.updateViewLayout(view, params)
                return true
            }
            MotionEvent.ACTION_UP -> {
                view.performClick()
                return true
            }
            else -> return false
        }
    }

    private fun clampToScreen(params: WindowManager.LayoutParams, view: View) {
        if (view.width == 0 || view.height == 0) return
        val screen = resources.displayMetrics
        val maxX = (screen.widthPixels - view.width).coerceAtLeast(0)
        val maxY = (screen.heightPixels - view.height).coerceAtLeast(0)
        params.x = params.x.coerceIn(0, maxX)
        params.y = params.y.coerceIn(0, maxY)
    }

    private fun stopOverlay(startId: Int) {
        removeOverlay()
        if (inForeground) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            inForeground = false
        }
        stopSelf(startId)
    }

    private fun removeOverlay() {
        val view = overlayView ?: return
        val manager = windowManager
        overlayView = null
        layoutParams = null
        if (manager == null) return
        try {
            manager.removeView(view)
        } catch (_: IllegalArgumentException) {
            // Already detached.
        }
    }

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Yüzen teleprompter",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Creator mode yüzen yazı kutusu açıkken gösterilir."
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }

        val openApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("Teleprompter")
            .setContentText("Creator mode açık")
            .setSmallIcon(R.drawable.ic_stat_creator_overlay)
            .setOngoing(true)
            .setContentIntent(openApp)
            .build()
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    companion object {
        const val ACTION_SHOW =
            "app.cueline.teleprompter.action.CREATOR_OVERLAY_SHOW"
        const val ACTION_HIDE =
            "app.cueline.teleprompter.action.CREATOR_OVERLAY_HIDE"

        private const val NOTIFICATION_ID = 7101
        private const val CHANNEL_ID = "creator_overlay"
        private const val WORDS_BEFORE = 2
        private const val WORDS_AFTER = 18

        private val colorPast: Int = Color.parseColor("#66FFFFFF")
        private val colorActive: Int = Color.parseColor("#FFFFC107")
        private val colorUpcoming: Int = Color.WHITE

        fun scriptSpan(words: List<String>, activeIndex: Int): CharSequence {
            if (words.isEmpty()) return "Metin yok"
            val safeActive = if (activeIndex in words.indices) activeIndex else -1
            val from = if (safeActive < 0) 0 else (safeActive - WORDS_BEFORE).coerceAtLeast(0)
            val to = if (safeActive < 0) {
                (WORDS_BEFORE + 1 + WORDS_AFTER).coerceAtMost(words.size)
            } else {
                (safeActive + 1 + WORDS_AFTER).coerceAtMost(words.size)
            }
            val builder = SpannableStringBuilder()
            for (i in from until to) {
                if (builder.isNotEmpty()) builder.append(' ')
                val start = builder.length
                builder.append(words[i])
                val color = when {
                    safeActive < 0 -> colorUpcoming
                    i < safeActive -> colorPast
                    i == safeActive -> colorActive
                    else -> colorUpcoming
                }
                builder.setSpan(
                    ForegroundColorSpan(color),
                    start,
                    builder.length,
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
                )
            }
            return builder
        }
    }
}
