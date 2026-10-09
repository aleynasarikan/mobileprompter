package app.cueline.teleprompter

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var speech: ContinuousSpeech? = null
    private var speechChannel: MethodChannel? = null
    private var speechEvents: EventChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val overlayChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        overlayChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "canDrawOverlays" -> result.success(canDrawOverlays())
                "isRunning" -> result.success(CreatorOverlayBridge.isRunning())
                "openOverlaySettings" -> openOverlaySettings(result)
                "show" -> showOverlay(call, result)
                "update" -> updateOverlay(call, result)
                "setPlaying" -> {
                    CreatorOverlayBridge.setPlaying(call.argument<Boolean>("playing") ?: false)
                    result.success(null)
                }
                "setVisible" -> {
                    CreatorOverlayBridge.setVisible(call.argument<Boolean>("visible") ?: true)
                    result.success(null)
                }
                "moveAppToBack" -> result.success(moveTaskToBack(true))
                "hide" -> hideOverlay(result)
                else -> result.notImplemented()
            }
        }
        channel = overlayChannel
        configureSpeech(flutterEngine)
        // Overlay buttons run on the main thread, like the channel.
        CreatorOverlayBridge.onAction = { action ->
            channel?.invokeMethod("onAction", action)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        CreatorOverlayBridge.onAction = null
        channel?.setMethodCallHandler(null)
        channel = null
        speechChannel?.setMethodCallHandler(null)
        speechChannel = null
        speechEvents?.setStreamHandler(null)
        speechEvents = null
        speech?.dispose()
        speech = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        // The overlay mirrors this activity's prompter. Without it there is
        // nothing to follow, so it must not linger.
        if (isFinishing) CreatorOverlayBridge.stop()
        super.onDestroy()
    }

    /** See [ContinuousSpeech]; Dart side is `NativeContinuousSpeech`. */
    private fun configureSpeech(flutterEngine: FlutterEngine) {
        val recognizer = ContinuousSpeech(applicationContext)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val methods = MethodChannel(messenger, SPEECH_CHANNEL)
        methods.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> recognizer.start(call.argument<String>("localeId"))
                "stop" -> recognizer.stop()
                "cancel" -> recognizer.cancel()
                else -> return@setMethodCallHandler result.notImplemented()
            }
            result.success(null)
        }
        val events = EventChannel(messenger, "$SPEECH_CHANNEL/events")
        events.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    recognizer.sink = sink
                }

                override fun onCancel(arguments: Any?) {
                    recognizer.sink = null
                }
            },
        )
        speech = recognizer
        speechChannel = methods
        speechEvents = events
    }

    private fun canDrawOverlays(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && Settings.canDrawOverlays(this)
    }

    private fun openOverlaySettings(result: MethodChannel.Result) {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName"),
        )
        try {
            startActivity(intent)
            result.success(null)
        } catch (_: ActivityNotFoundException) {
            result.error(
                "overlay_settings_unavailable",
                "Android overlay settings could not be opened.",
                null,
            )
        }
    }

    private fun showOverlay(call: MethodCall, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.error(
                "overlay_unsupported",
                "Floating overlay requires Android 8 or newer.",
                null,
            )
            return
        }
        if (!Settings.canDrawOverlays(this)) {
            result.error(
                "overlay_permission_denied",
                "Display over other apps is not allowed.",
                null,
            )
            return
        }
        if (checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.error(
                "microphone_permission_denied",
                "The floating prompter follows speech and needs the microphone.",
                null,
            )
            return
        }
        CreatorOverlayBridge.prepare(
            words = stringList(call, "words"),
            index = call.argument<Int>("activeWordIndex") ?: -1,
            labels = OverlayLabels.from(call.argument<Map<*, *>>("labels")),
        )
        if (CreatorOverlayBridge.isRunning()) {
            result.success(null)
            return
        }
        try {
            val intent = Intent(this, CreatorOverlayService::class.java).apply {
                action = CreatorOverlayService.ACTION_SHOW
            }
            // Started while this activity is resumed: a microphone foreground
            // service cannot be created from the background (Android 14+).
            // Later updates go straight to the running service.
            startForegroundService(intent)
            result.success(null)
        } catch (error: RuntimeException) {
            result.error("overlay_start_failed", error.message, null)
        }
    }

    private fun updateOverlay(call: MethodCall, result: MethodChannel.Result) {
        val index = call.argument<Int>("activeWordIndex") ?: -1
        if (!CreatorOverlayBridge.update(index)) {
            result.error(
                "overlay_not_running",
                "Floating prompter is not running.",
                null,
            )
            return
        }
        result.success(null)
    }

    private fun hideOverlay(result: MethodChannel.Result) {
        CreatorOverlayBridge.stop()
        result.success(null)
    }

    private fun stringList(call: MethodCall, key: String): List<String> {
        val raw = call.argument<List<*>>(key) ?: return emptyList()
        return raw.mapNotNull { it as? String }
    }

    companion object {
        private const val CHANNEL =
            "app.cueline.teleprompter/creator_overlay"
        private const val SPEECH_CHANNEL =
            "app.cueline.teleprompter/continuous_speech"
    }
}
