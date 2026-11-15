package id.nara.voice.accessibility

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import id.nara.voice.platform.ChannelRegistry
import id.nara.voice.platform.NaraErrors
import org.json.JSONObject
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * MethodChannel facade over [NaraAccessibilityService]. Every call degrades
 * gracefully to typed errors when the user has not enabled the service.
 */
class AccessibilityHandler(private val context: Context) {

    private val service: NaraAccessibilityService?
        get() = NaraAccessibilityService.instance

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, ChannelRegistry.CHANNEL_ACCESSIBILITY).setMethodCallHandler { call, result ->
            try {
                handle(call, result)
            } catch (e: IllegalArgumentException) {
                result.error(NaraErrors.INVALID_ARGUMENT, e.message, null)
            } catch (e: Exception) {
                result.error(NaraErrors.UNSUPPORTED, e.message ?: "Unexpected accessibility failure", null)
            }
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isEnabled" -> result.success(NaraAccessibilityService.isConnected)
            "openAccessibilitySettings" -> {
                context.startActivity(
                    Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                result.success(mapOf("launched" to true))
            }
            "inspectScreen" -> requireService(result) { service ->
                // The service builds plain Kotlin maps/lists — directly
                // encodable by StandardMessageCodec.
                service.performInspect { snapshot -> result.success(snapshot) }
            }
            "tapElement" -> requireService(result) { service ->
                val element = JSONObject(call.argument<String>("element") ?: "{}")
                service.tapElement(element) { performed -> result.success(mapOf("performed" to performed)) }
            }
            "inputText" -> requireService(result) { service ->
                val element = JSONObject(call.argument<String>("element") ?: "{}")
                val value = call.argument<String>("value") ?: ""
                service.inputText(element, value) { performed -> result.success(mapOf("performed" to performed)) }
            }
            "scroll" -> requireService(result) { service ->
                val forward = call.argument<Boolean>("forward") ?: true
                service.scroll(forward) { performed -> result.success(mapOf("performed" to performed)) }
            }
            "goBack" -> requireService(result) { service ->
                service.goBack { performed -> result.success(mapOf("performed" to performed)) }
            }
            "goHome" -> requireService(result) { service ->
                service.performGlobal(AccessibilityService.GLOBAL_ACTION_HOME) { performed ->
                    result.success(mapOf("performed" to performed))
                }
            }
            "openRecents" -> requireService(result) { service ->
                service.performGlobal(AccessibilityService.GLOBAL_ACTION_RECENTS) { performed ->
                    result.success(mapOf("performed" to performed))
                }
            }
            "openNotificationShade" -> requireService(result) { service ->
                service.performGlobal(AccessibilityService.GLOBAL_ACTION_NOTIFICATIONS) { performed ->
                    result.success(mapOf("performed" to performed))
                }
            }
            "openQuickSettings" -> requireService(result) { service ->
                service.performGlobal(AccessibilityService.GLOBAL_ACTION_QUICK_SETTINGS) { performed ->
                    result.success(mapOf("performed" to performed))
                }
            }
            "takeScreenshot" -> {
                if (Build.VERSION.SDK_INT < 28) {
                    result.error(NaraErrors.UNSUPPORTED, "Screenshot needs Android 9+", null)
                } else {
                    requireService(result) { service ->
                        service.performGlobal(AccessibilityService.GLOBAL_ACTION_TAKE_SCREENSHOT) { performed ->
                            result.success(mapOf("performed" to performed))
                        }
                    }
                }
            }
            "typeText" -> requireService(result) { service ->
                val value = requireText(call.argument<String>("value"))
                service.typeText(value) { performed -> result.success(mapOf("performed" to performed)) }
            }
            "currentApp" -> requireService(result) { service ->
                service.currentApp { pkg -> result.success(mapOf("packageName" to pkg)) }
            }
            else -> result.notImplemented()
        }
    }

    private inline fun requireService(result: MethodChannel.Result, block: (NaraAccessibilityService) -> Unit) {
        val current = service
        if (current == null) {
            result.error(NaraErrors.SERVICE_NOT_ENABLED, "NARA accessibility service is not enabled", null)
            return
        }
        block(current)
    }

    private fun requireText(value: String?): String =
        value?.trim().takeUnless { it.isNullOrEmpty() }
            ?: throw IllegalArgumentException("value is required")

    fun dispose() {
        // The service itself is managed by the OS; nothing to release here.
    }
}
