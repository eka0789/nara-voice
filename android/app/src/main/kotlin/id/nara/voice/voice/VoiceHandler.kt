package id.nara.voice.voice

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import id.nara.voice.platform.ChannelRegistry
import id.nara.voice.platform.NaraErrors
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Voice engine: streaming speech-to-text (with partial results) and
 * text-to-speech, both driven through [ChannelRegistry.CHANNEL_VOICE] with
 * progress/arrival events on [ChannelRegistry.CHANNEL_VOICE_EVENTS].
 */
class VoiceHandler(private val context: Context) {

    private var eventSink: EventChannel.EventSink? = null
    private var recognizer: SpeechRecognizer? = null
    private var listening = AtomicBoolean(false)

    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var ttsInitResult = TextToSpeech.LANG_NOT_SUPPORTED
    private var ttsLanguage = Locale.US

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, ChannelRegistry.CHANNEL_VOICE).setMethodCallHandler { call, result ->
            try {
                handle(call, result)
            } catch (e: IllegalArgumentException) {
                result.error(NaraErrors.INVALID_ARGUMENT, e.message, null)
            } catch (e: VoiceException) {
                result.error(e.code, e.message, null)
            } catch (e: Exception) {
                result.error(NaraErrors.UNSUPPORTED, e.message ?: "Unexpected voice failure", null)
            }
        }
        EventChannel(messenger, ChannelRegistry.CHANNEL_VOICE_EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )
    }

    private class VoiceException(val code: String, override val message: String) : Exception(message)

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSttAvailable" -> result.success(isSttAvailable())
            "startStt" -> {
                val localeTag = call.argument<String>("locale") ?: "en-US"
                result.success(startStt(localeTag))
            }
            "stopStt" -> {
                stopStt(flush = true)
                result.success(mapOf("stopped" to true))
            }
            "cancelStt" -> {
                stopStt(flush = false)
                result.success(mapOf("cancelled" to true))
            }
            "ttsInit" -> result.success(ttsInit())
            "ttsSpeak" -> result.success(
                ttsSpeak(
                    id = call.argument<String>("id") ?: "utt",
                    text = call.argument<String>("text") ?: "",
                    localeTag = call.argument<String>("locale") ?: "en-US",
                    pitch = (call.argument<Double>("pitch") ?: 1.0).toFloat(),
                    rate = (call.argument<Double>("rate") ?: 1.0).toFloat(),
                ),
            )
            "ttsStop" -> {
                tts?.stop()
                result.success(mapOf("stopped" to true))
            }
            else -> result.notImplemented()
        }
    }

    private fun isSttAvailable(): Boolean =
        SpeechRecognizer.isRecognitionAvailable(context) &&
            context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    private fun startStt(localeTag: String): Map<String, Any?> {
        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            throw VoiceException(NaraErrors.STT_UNAVAILABLE, "Speech recognition is not available on this device")
        }
        if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            throw VoiceException(NaraErrors.MIC_PERMISSION, "Microphone permission has not been granted")
        }
        stopStt(flush = false)

        recognizer = if (BuildSupport.supportsOnDeviceStt()) {
            SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
        } else {
            SpeechRecognizer.createSpeechRecognizer(context)
        }
        listening.set(true)

        val listener = object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                emit("stt", "ready", null)
            }

            override fun onBeginningOfSpeech() {
                emit("stt", "begin", null)
            }

            override fun onRmsChanged(rmsdB: Float) {
                eventSink?.success(mapOf("kind" to "stt", "event" to "volume", "volume" to rmsdB))
            }

            override fun onBufferReceived(buffer: ByteArray?) {}

            override fun onEndOfSpeech() {
                emit("stt", "end", null)
            }

            override fun onError(error: Int) {
                listening.set(false)
                if (error == SpeechRecognizer.ERROR_NO_MATCH || error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) {
                    emit("stt", "final", null)
                    return
                }
                emit("stt", "error", sttErrorName(error))
            }

            override fun onResults(results: Bundle?) {
                listening.set(false)
                val text = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()
                emit("stt", "final", text)
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val text = partialResults
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull()
                if (!text.isNullOrEmpty()) emit("stt", "partial", text)
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        }

        val recognizerIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, localeTag)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, localeTag)
        }
        recognizer?.setRecognitionListener(listener)
        recognizer?.startListening(recognizerIntent)
        return mapOf("started" to true, "onDevice" to BuildSupport.supportsOnDeviceStt())
    }

    private fun sttErrorName(error: Int): String = when (error) {
        SpeechRecognizer.ERROR_AUDIO -> "AUDIO"
        SpeechRecognizer.ERROR_CLIENT -> "CLIENT"
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "PERMISSIONS"
        SpeechRecognizer.ERROR_NETWORK -> "NETWORK"
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "NETWORK_TIMEOUT"
        SpeechRecognizer.ERROR_SERVER -> "SERVER"
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "BUSY"
        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED -> "LANGUAGE_NOT_SUPPORTED"
        SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "LANGUAGE_UNAVAILABLE"
        else -> "UNKNOWN"
    }

    private fun stopStt(flush: Boolean) {
        val current = recognizer ?: return
        listening.set(false)
        try {
            if (flush) current.stopListening() else current.cancel()
            current.destroy()
        } catch (e: Exception) {
            // Destroying an already-dead recognizer must not crash the engine.
        }
        recognizer = null
    }

    private fun emit(kind: String, event: String, text: String?) {
        val payload = HashMap<String, Any?>()
        payload["kind"] = kind
        payload["event"] = event
        if (text != null) payload["text"] = text
        eventSink?.success(payload)
    }

    private fun ttsInit(): Map<String, Any?> {
        if (tts != null && ttsReady) {
            return mapOf("ready" to true, "language" to ttsLanguage.toLanguageTag())
        }
        ttsReady = false
        tts = TextToSpeech(context.applicationContext) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            if (ttsReady) {
                tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) {
                        emit("tts", "start", utteranceId)
                    }

                    override fun onDone(utteranceId: String?) {
                        emit("tts", "done", utteranceId)
                    }

                    @Deprecated("Deprecated in Java")
                    override fun onError(utteranceId: String?) {
                        emit("tts", "error", utteranceId)
                    }
                })
            }
            emit("tts", if (ttsReady) "ready" else "init_failed", null)
        }
        return mapOf("ready" to false)
    }

    private fun ttsSpeak(id: String, text: String, localeTag: String, pitch: Float, rate: Float): Map<String, Any?> {
        val engine = tts ?: throw VoiceException(NaraErrors.TTS_UNAVAILABLE, "Text-to-speech is not initialised")
        if (!ttsReady || text.isBlank()) {
            throw VoiceException(NaraErrors.TTS_UNAVAILABLE, if (ttsReady) "Nothing to speak" else "TTS engine is not ready yet")
        }
        val locale = Locale.forLanguageTag(localeTag)
        ttsLanguage = if (engine.isLanguageAvailable(locale) >= TextToSpeech.LANG_AVAILABLE) locale else Locale.US
        engine.language = ttsLanguage
        engine.setPitch(pitch)
        engine.setSpeechRate(rate)
        val result = engine.speak(text, TextToSpeech.QUEUE_FLUSH, Bundle.EMPTY, id)
        if (result != TextToSpeech.SUCCESS) {
            throw VoiceException(NaraErrors.TTS_UNAVAILABLE, "TTS rejected the utterance")
        }
        return mapOf("speaking" to true, "language" to ttsLanguage.toLanguageTag())
    }

    fun dispose() {
        stopStt(flush = false)
        tts?.stop()
        tts?.shutdown()
        tts = null
        ttsReady = false
        eventSink = null
    }
}

/** Version gates kept in one place. */
private object BuildSupport {
    fun supportsOnDeviceStt(): Boolean = android.os.Build.VERSION.SDK_INT >= 31
}
