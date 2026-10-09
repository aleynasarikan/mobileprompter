package app.cueline.teleprompter

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.EventChannel

/**
 * One continuous listening run on top of Android's [SpeechRecognizer].
 *
 * The platform recognizer ends after every utterance and plays its start
 * earcon on each new session, so restarting it from Dart made the
 * microphone beep and blink after every sentence. This class keeps the run
 * open on the native side instead:
 *
 * - Android 13+: a segmented session ([RecognizerIntent.EXTRA_SEGMENTED_SESSION])
 *   delivers each sentence via [onSegmentResults] without ending the session.
 * - Otherwise, or when the recognizer ignores segmentation, the session is
 *   restarted right here on the main thread, with the earcon streams muted
 *   for the restart.
 *
 * Silence timeouts and transient errors are retried silently. Dart sees one
 * session: `listening` once, results, and `done` only after [stop],
 * [cancel] or a fatal error.
 */
class ContinuousSpeech(private val context: Context) : RecognitionListener {
    var sink: EventChannel.EventSink? = null

    private val main = Handler(Looper.getMainLooper())
    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var recognizer: SpeechRecognizer? = null
    private var languageTag: String? = null

    /** True between [start] and [stop]/[cancel]/fatal error. */
    private var active = false

    /** A [stop] is waiting for the last result before reporting `done`. */
    private var stopping = false
    private var announcedListening = false
    private var readyInSession = false
    private var segmented = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
    private var failures = 0
    private var silences = 0
    private val mutedStreams = mutableListOf<Int>()

    private val unmute = Runnable { restoreEarconStreams() }
    private val finishStop = Runnable { finish() }

    fun start(localeId: String?) {
        main.removeCallbacks(finishStop)
        languageTag = localeId?.replace('_', '-')
        active = true
        stopping = false
        announcedListening = false
        failures = 0
        silences = 0
        listen()
    }

    /** Ends the run; a pending result of the current sentence is still sent. */
    fun stop() {
        if (!active) return
        active = false
        stopping = true
        recognizer?.stopListening()
        // Some recognizers send nothing after stopListening.
        main.postDelayed(finishStop, STOP_GRACE_MS)
    }

    /** Ends the run at once and drops any pending result. */
    fun cancel() {
        active = false
        recognizer?.cancel()
        finish()
    }

    fun dispose() {
        active = false
        main.removeCallbacksAndMessages(null)
        destroyRecognizer()
        restoreEarconStreams()
        sink = null
    }

    private fun listen() {
        if (!active) return
        val current = recognizer ?: SpeechRecognizer.createSpeechRecognizer(context).also {
            it.setRecognitionListener(this)
            recognizer = it
        }
        readyInSession = false
        silenceEarcon()
        try {
            current.startListening(recognizerIntent())
        } catch (error: RuntimeException) {
            fail("error_client", error.message)
        }
    }

    private fun recognizerIntent(): Intent {
        return Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
            languageTag?.let { putExtra(RecognizerIntent.EXTRA_LANGUAGE, it) }
            if (segmented && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                putExtra(
                    RecognizerIntent.EXTRA_SEGMENTED_SESSION,
                    RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS,
                )
                putExtra(
                    RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS,
                    SEGMENTED_SESSION_MS,
                )
            }
        }
    }

    /** Next session as soon as the recognizer is free, without a gap. */
    private fun restart(delayMs: Long = 0) {
        if (!active) return
        if (delayMs == 0L) {
            main.post { listen() }
        } else {
            main.postDelayed({ listen() }, delayMs)
        }
    }

    /** Reports `done` once; called after stop, cancel or a fatal error. */
    private fun finish() {
        main.removeCallbacks(finishStop)
        stopping = false
        destroyRecognizer()
        main.removeCallbacks(unmute)
        restoreEarconStreams()
        if (announcedListening) {
            announcedListening = false
            emitStatus("notListening")
        }
        emitStatus("done")
    }

    private fun fail(code: String, message: String?) {
        active = false
        emit(mapOf("type" to "error", "code" to code, "message" to (message ?: code)))
        finish()
    }

    private fun destroyRecognizer() {
        val current = recognizer ?: return
        recognizer = null
        try {
            current.destroy()
        } catch (_: RuntimeException) {
            // Already gone.
        }
    }

    // Google's recognizer plays its start earcon as a notification event.
    // Media is left alone so a video playing in another app keeps its sound.
    // Muted only around startListening.
    private fun silenceEarcon() {
        main.removeCallbacks(unmute)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        if (mutedStreams.isEmpty()) {
            for (stream in EARCON_STREAMS) {
                try {
                    if (!audio.isStreamMute(stream)) {
                        audio.adjustStreamVolume(stream, AudioManager.ADJUST_MUTE, 0)
                        mutedStreams.add(stream)
                    }
                } catch (_: SecurityException) {
                    // Do Not Disturb can forbid changing some streams.
                }
            }
        }
        main.postDelayed(unmute, EARCON_MUTE_MS)
    }

    private fun restoreEarconStreams() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        for (stream in mutedStreams) {
            try {
                audio.adjustStreamVolume(stream, AudioManager.ADJUST_UNMUTE, 0)
            } catch (_: SecurityException) {
                // See silenceEarcon.
            }
        }
        mutedStreams.clear()
    }

    private fun emitStatus(status: String) {
        emit(mapOf("type" to "status", "status" to status))
    }

    private fun emitResult(results: Bundle?, isFinal: Boolean) {
        val texts = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        val text = texts?.firstOrNull()?.trim().orEmpty()
        if (text.isEmpty()) return
        val confidence = results?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
            ?.firstOrNull()?.toDouble() ?: -1.0
        failures = 0
        silences = 0
        emit(
            mapOf(
                "type" to "result",
                "text" to text,
                "final" to isFinal,
                "confidence" to confidence,
            ),
        )
    }

    private fun emit(event: Map<String, Any?>) {
        sink?.success(event)
    }

    override fun onReadyForSpeech(params: Bundle?) {
        readyInSession = true
        if (!announcedListening && (active || stopping)) {
            announcedListening = true
            emitStatus("listening")
        }
    }

    override fun onBeginningOfSpeech() {}

    override fun onRmsChanged(rmsdB: Float) {
        emit(mapOf("type" to "level", "level" to rmsdB.toDouble()))
    }

    override fun onBufferReceived(buffer: ByteArray?) {}

    override fun onEndOfSpeech() {}

    override fun onPartialResults(partialResults: Bundle?) {
        if (!active && !stopping) return
        emitResult(partialResults, isFinal = false)
    }

    override fun onSegmentResults(segmentResults: Bundle) {
        if (!active && !stopping) return
        emitResult(segmentResults, isFinal = true)
    }

    override fun onEndOfSegmentedSession() {
        if (stopping) return finish()
        restart()
    }

    override fun onResults(results: Bundle?) {
        if (stopping) {
            emitResult(results, isFinal = true)
            return finish()
        }
        if (!active) return
        emitResult(results, isFinal = true)
        restart()
    }

    override fun onError(error: Int) {
        if (stopping) return finish()
        if (!active) return
        when (error) {
            SpeechRecognizer.ERROR_NO_MATCH,
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> {
                // Nobody spoke. Keep listening; back off a little so a long
                // pause does not spin the recognizer.
                silences++
                restart(if (silences <= 2) 0 else SILENCE_BACKOFF_MS)
            }
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS ->
                fail("error_permission", null)
            SpeechRecognizer.ERROR_AUDIO -> fail("error_audio_error", null)
            SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED ->
                fail("error_language_not_supported", null)
            SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE ->
                fail("error_language_unavailable", null)
            else -> {
                // A recognizer that rejects segmented sessions fails before it
                // ever gets ready. Fall back to plain sessions.
                if (segmented && !readyInSession) segmented = false
                failures++
                if (failures > MAX_FAILURES) {
                    fail(errorCode(error), null)
                    return
                }
                // Busy and client errors need a fresh recognizer instance.
                destroyRecognizer()
                restart(RETRY_DELAY_MS * failures)
            }
        }
    }

    override fun onEvent(eventType: Int, params: Bundle?) {}

    companion object {
        private const val SEGMENTED_SESSION_MS = 5 * 60 * 1000
        private const val STOP_GRACE_MS = 1500L
        private const val EARCON_MUTE_MS = 700L
        private const val SILENCE_BACKOFF_MS = 250L
        private const val RETRY_DELAY_MS = 300L
        private const val MAX_FAILURES = 5

        private val EARCON_STREAMS = listOf(
            AudioManager.STREAM_NOTIFICATION,
            AudioManager.STREAM_SYSTEM,
        )

        /** Same codes as the speech_to_text plugin, which Dart already maps. */
        fun errorCode(error: Int): String = when (error) {
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "error_network_timeout"
            SpeechRecognizer.ERROR_NETWORK -> "error_network"
            SpeechRecognizer.ERROR_AUDIO -> "error_audio_error"
            SpeechRecognizer.ERROR_SERVER -> "error_server"
            SpeechRecognizer.ERROR_CLIENT -> "error_client"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "error_speech_timeout"
            SpeechRecognizer.ERROR_NO_MATCH -> "error_no_match"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "error_busy"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "error_permission"
            SpeechRecognizer.ERROR_TOO_MANY_REQUESTS -> "error_too_many_requests"
            SpeechRecognizer.ERROR_SERVER_DISCONNECTED -> "error_server_disconnected"
            SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED -> "error_language_not_supported"
            SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "error_language_unavailable"
            else -> "error_unknown"
        }
    }
}
