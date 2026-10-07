package app.cueline.teleprompter

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canDrawOverlays" -> result.success(Settings.canDrawOverlays(this))
                    "isRunning" -> result.success(CreatorOverlayBridge.isRunning())
                    "openOverlaySettings" -> openOverlaySettings(result)
                    "show" -> showOverlay(call, result)
                    "update" -> updateOverlay(call, result)
                    "hide" -> hideOverlay(result)
                    else -> result.notImplemented()
                }
            }
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
        CreatorOverlayBridge.prepare(
            words = stringList(call, "words"),
            index = call.argument<Int>("activeWordIndex") ?: -1,
            useMicrophone = call.argument<Boolean>("useMicrophone") ?: false,
        )
        if (CreatorOverlayBridge.isRunning()) {
            result.success(null)
            return
        }
        try {
            val intent = Intent(this, CreatorOverlayService::class.java).apply {
                action = CreatorOverlayService.ACTION_SHOW
            }
            // The button is pressed while this activity is resumed, so the
            // foreground service is allowed to start. Later word updates go
            // straight to the running service and do not start it again.
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
                "Creator overlay is not running.",
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
    }
}
