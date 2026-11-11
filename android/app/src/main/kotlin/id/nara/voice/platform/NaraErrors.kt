package id.nara.voice.platform

/**
 * Stable error codes surfaced to Dart through MethodChannel.error().
 * Dart maps these onto typed NaraPlatformException values.
 */
object NaraErrors {
    const val INVALID_ARGUMENT = "INVALID_ARGUMENT"
    const val NOT_INSTALLED = "NOT_INSTALLED"
    const val NOT_RESOLVED = "NOT_RESOLVED"
    const val APP_NOT_LAUNCHABLE = "APP_NOT_LAUNCHABLE"
    const val LAUNCH_FAILED = "LAUNCH_FAILED"
    const val MIC_PERMISSION = "MIC_PERMISSION"
    const val STT_UNAVAILABLE = "STT_UNAVAILABLE"
    const val TTS_UNAVAILABLE = "TTS_UNAVAILABLE"
    const val SERVICE_NOT_ENABLED = "SERVICE_NOT_ENABLED"
    const val ACTION_TIMEOUT = "ACTION_TIMEOUT"
    const val UNSUPPORTED = "UNSUPPORTED"

    /** Typed throwable for handlers that need to short-circuit with a code. */
    class CodedException(val code: String, message: String) : RuntimeException(message)
}
