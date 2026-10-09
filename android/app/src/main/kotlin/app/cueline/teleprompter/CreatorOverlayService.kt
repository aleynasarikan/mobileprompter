package app.cueline.teleprompter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.text.Spannable
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/** Texts shown by the native overlay, translated on the Flutter side. */
internal data class OverlayLabels(
    val notificationTitle: String = "Mobile Prompter",
    val notificationText: String = "",
    val play: String = "Play",
    val pause: String = "Pause",
    val close: String = "Close",
) {
    companion object {
        fun from(raw: Map<*, *>?): OverlayLabels {
            if (raw == null) return OverlayLabels()
            fun text(key: String, fallback: String) = raw[key] as? String ?: fallback
            val defaults = OverlayLabels()
            return OverlayLabels(
                notificationTitle = text("notificationTitle", defaults.notificationTitle),
                notificationText = text("notificationText", defaults.notificationText),
                play = text("play", defaults.play),
                pause = text("pause", defaults.pause),
                close = text("close", defaults.close),
            )
        }
    }
}

/**
 * Process-local handle so the activity can update the overlay without
 * putting the whole script into an [Intent] (those are size-limited).
 */
internal object CreatorOverlayBridge {
    private var service: CreatorOverlayService? = null
    private var words: List<String> = emptyList()
    var activeIndex: Int = -1
        private set
    var playing: Boolean = false
        private set
    var visible: Boolean = true
        private set
    var labels: OverlayLabels = OverlayLabels()
        private set

    /** Buttons on the overlay. Set by the activity while Flutter runs. */
    var onAction: ((String) -> Unit)? = null

    fun isRunning(): Boolean = service != null

    fun attach(service: CreatorOverlayService) {
        this.service = service
        service.render(words, activeIndex, playing, visible)
    }

    fun detach(service: CreatorOverlayService) {
        if (this.service === service) this.service = null
    }

    fun prepare(words: List<String>, index: Int, labels: OverlayLabels) {
        this.words = words
        activeIndex = index
        this.labels = labels
        service?.render(words, index, playing, visible)
    }

    fun update(index: Int): Boolean {
        activeIndex = index
        val current = service ?: return false
        current.render(words, index, playing, visible)
        return true
    }

    fun setPlaying(value: Boolean) {
        playing = value
        service?.render(words, activeIndex, playing, visible)
    }

    fun setVisible(value: Boolean) {
        visible = value
        service?.render(words, activeIndex, playing, visible)
    }

    fun dispatch(action: String) {
        onAction?.invoke(action)
    }

    fun stop() {
        val current = service
        clear()
        current?.shutdown()
    }

    private fun clear() {
        words = emptyList()
        activeIndex = -1
        playing = false
        visible = true
    }
}

/**
 * Small draggable prompter drawn over other apps.
 *
 * The view is owned by the service, not the activity, so it stays after the
 * user leaves this app. The service is a `microphone` foreground service:
 * speech recognition keeps its while-in-use microphone access while CueLine
 * is in the background. It must be started while the activity is visible.
 * Touches outside the box pass through
 * ([WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE]).
 */
class CreatorOverlayService : Service() {
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var textView: TextView? = null
    private var scrollView: ScrollView? = null
    private var playButton: ImageButton? = null
    private var renderedWords: List<String>? = null
    private var wordStarts = IntArray(0)
    private var wordEnds = IntArray(0)
    private val readSpan = ForegroundColorSpan(colorPast)
    private val activeSpan = ForegroundColorSpan(colorActive)
    private var scrolledLine = -1
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
                if (!startAsForeground() || !showOverlay()) {
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

    /** Swiping CueLine away from recents ends the floating prompter too. */
    override fun onTaskRemoved(rootIntent: Intent?) {
        CreatorOverlayBridge.stop()
        super.onTaskRemoved(rootIntent)
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        val view = overlayView ?: return
        val params = layoutParams ?: return
        view.post {
            clampToScreen(params, view)
            try {
                windowManager?.updateViewLayout(view, params)
            } catch (_: IllegalArgumentException) {
                // Already removed.
            }
        }
    }

    override fun onDestroy() {
        removeOverlay()
        CreatorOverlayBridge.detach(this)
        super.onDestroy()
    }

    fun shutdown() {
        removeOverlay()
        if (inForeground) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            inForeground = false
        }
        stopSelf()
    }

    fun render(words: List<String>, activeIndex: Int, playing: Boolean, visible: Boolean) {
        renderScript(words, activeIndex)
        playButton?.apply {
            val labels = CreatorOverlayBridge.labels
            setImageResource(
                if (playing) android.R.drawable.ic_media_pause
                else android.R.drawable.ic_media_play,
            )
            contentDescription = if (playing) labels.pause else labels.play
        }
        overlayView?.visibility = if (visible) View.VISIBLE else View.GONE
    }

    /**
     * Shows the whole script and colors it like the full prompter. The view
     * only scrolls when the active word moves to another line, so the text
     * stays still while a line is read (karaoke style) instead of shifting
     * with every word.
     */
    private fun renderScript(words: List<String>, activeIndex: Int) {
        val text = textView ?: return
        if (words !== renderedWords) {
            renderedWords = words
            val starts = IntArray(words.size)
            val ends = IntArray(words.size)
            val builder = StringBuilder()
            for (i in words.indices) {
                if (i > 0) builder.append(' ')
                starts[i] = builder.length
                builder.append(words[i])
                ends[i] = builder.length
            }
            wordStarts = starts
            wordEnds = ends
            text.setText(SpannableString(builder), TextView.BufferType.SPANNABLE)
            scrolledLine = -1
            scrollView?.scrollTo(0, 0)
        }
        val spannable = text.text as? Spannable ?: return
        spannable.removeSpan(readSpan)
        spannable.removeSpan(activeSpan)
        if (activeIndex !in words.indices) return
        val start = wordStarts[activeIndex]
        if (start > 0) {
            spannable.setSpan(readSpan, 0, start, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        spannable.setSpan(
            activeSpan,
            start,
            wordEnds[activeIndex],
            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
        text.post { scrollToLineOf(start) }
    }

    private fun scrollToLineOf(offset: Int) {
        val text = textView ?: return
        val scroll = scrollView ?: return
        val layout = text.layout ?: return
        fitToLines(scroll, text)
        val line = layout.getLineForOffset(offset)
        if (line == scrolledLine) return
        scrolledLine = line
        val top = layout.getLineTop((line - LINES_BEFORE_ACTIVE).coerceAtLeast(0))
        scroll.smoothScrollTo(0, top + text.paddingTop)
    }

    /** False when the microphone type cannot be used; nothing is shown then. */
    private fun startAsForeground(): Boolean {
        if (!hasMicPermission()) return false
        val notification = buildNotification()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (_: RuntimeException) {
            // SecurityException (no while-in-use access) or a start that the
            // system no longer allows.
            return false
        }
        inForeground = true
        return true
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
        val view = overlayContent()

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
            dp(300),
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

    private fun overlayContent(): View {
        val labels = CreatorOverlayBridge.labels
        val dragListener = View.OnTouchListener { touched, event ->
            dragOverlay(touched, event)
        }

        val play = iconButton(android.R.drawable.ic_media_play, labels.play) {
            CreatorOverlayBridge.dispatch(ACTION_TOGGLE_PLAY)
        }
        val close = iconButton(android.R.drawable.ic_menu_close_clear_cancel, labels.close) {
            CreatorOverlayBridge.dispatch(ACTION_CLOSE)
            returnToApp()
        }
        val handle = View(this).apply { setOnTouchListener(dragListener) }
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(play, LinearLayout.LayoutParams(dp(40), dp(40)))
            addView(handle, LinearLayout.LayoutParams(0, dp(40), 1f))
            addView(close, LinearLayout.LayoutParams(dp(40), dp(40)))
        }
        val text = TextView(this).apply {
            setTextColor(colorUpcoming)
            textSize = 20f
            setLineSpacing(0f, 1.15f)
            includeFontPadding = false
            setPadding(dp(12), 0, dp(12), 0)
            setOnTouchListener(dragListener)
        }
        // Scrolled only by code. Touches go to the text, which drags the window.
        val scroll = object : ScrollView(this) {
            override fun onInterceptTouchEvent(ev: MotionEvent?): Boolean = false

            @android.annotation.SuppressLint("ClickableViewAccessibility")
            override fun onTouchEvent(ev: MotionEvent?): Boolean = false
        }.apply {
            isVerticalScrollBarEnabled = false
            overScrollMode = View.OVER_SCROLL_NEVER
            isFillViewport = true
            addView(text)
        }

        playButton = play
        textView = text
        scrollView = scroll
        renderedWords = null
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(4), dp(4), dp(4), dp(4))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#F20B0C0F"))
                cornerRadius = dp(16).toFloat()
            }
            addView(header)
            addView(
                scroll,
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    visibleTextHeight(text),
                ),
            )
        }
    }

    /** First guess before layout; [fitToLines] corrects it. */
    private fun visibleTextHeight(text: TextView): Int {
        return text.lineHeight * VISIBLE_LINES
    }

    /** Exactly [VISIBLE_LINES] laid-out lines, so a line is never cut. */
    private fun fitToLines(scroll: ScrollView, text: TextView) {
        val layout = text.layout ?: return
        val lines = layout.lineCount.coerceAtMost(VISIBLE_LINES)
        if (lines == 0) return
        val height = layout.getLineTop(lines) + text.paddingTop + text.paddingBottom
        val params = scroll.layoutParams ?: return
        if (params.height == height) return
        params.height = height
        scroll.layoutParams = params
    }

    private fun iconButton(icon: Int, label: String, onTap: () -> Unit): ImageButton {
        return ImageButton(this).apply {
            setImageResource(icon)
            imageTintList = ColorStateList.valueOf(colorActive)
            setBackgroundColor(Color.TRANSPARENT)
            contentDescription = label
            setOnClickListener { onTap() }
        }
    }

    /** Closing the floating prompter brings the full prompter back. */
    private fun returnToApp() {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
            )
        }
        try {
            startActivity(intent)
        } catch (_: RuntimeException) {
            // Background start blocked; the overlay still closes.
        }
    }

    private fun dragOverlay(view: View, event: MotionEvent): Boolean {
        val params = layoutParams ?: return false
        val manager = windowManager ?: return false
        val root = overlayView ?: return false
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
                clampToScreen(params, root)
                manager.updateViewLayout(root, params)
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
        textView = null
        scrollView = null
        renderedWords = null
        playButton = null
        layoutParams = null
        if (manager == null) return
        try {
            manager.removeView(view)
        } catch (_: IllegalArgumentException) {
            // Already detached.
        }
    }

    private fun buildNotification(): Notification {
        val labels = CreatorOverlayBridge.labels
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(
                CHANNEL_ID,
                labels.notificationTitle,
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
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
            .setContentTitle(labels.notificationTitle)
            .setContentText(labels.notificationText)
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

        /** Sent to Flutter when an overlay button is tapped. */
        const val ACTION_TOGGLE_PLAY = "togglePlay"
        const val ACTION_CLOSE = "close"

        private const val NOTIFICATION_ID = 7101
        private const val CHANNEL_ID = "floating_prompter"
        private const val VISIBLE_LINES = 4

        /** Read lines kept above the active one for context. */
        private const val LINES_BEFORE_ACTIVE = 1

        private val colorPast: Int = Color.parseColor("#6BFFFFFF")
        private val colorActive: Int = Color.parseColor("#FFE8B44C")
        private val colorUpcoming: Int = Color.WHITE
    }
}
