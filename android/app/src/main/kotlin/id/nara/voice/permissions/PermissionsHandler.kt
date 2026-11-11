package id.nara.voice.permissions

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import id.nara.voice.MainActivity
import id.nara.voice.platform.ChannelRegistry

/**
 * Runtime permissions bridge. Replaces the third-party permission plugin so
 * NARA controls its own minimal permission surface (RECORD_AUDIO and
 * POST_NOTIFICATIONS only). System-service toggles (accessibility,
 * notification listener) are handled by their own channels.
 */
class PermissionsHandler(
    private val context: Context,
    private val activity: MainActivity,
) {

    private var pendingResult: MethodChannel.Result? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, ChannelRegistry.CHANNEL_PERMISSIONS).setMethodCallHandler { call, result ->
            try {
                handle(call, result)
            } catch (e: Exception) {
                result.error("UNSUPPORTED", e.message ?: "Unexpected permission failure", null)
            }
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStatus" -> result.success(
                mapOf(
                    "microphone" to isGranted(Manifest.permission.RECORD_AUDIO),
                    "notifications" to notificationsGranted(),
                ),
            )
            "requestMicrophone" -> request(
                Manifest.permission.RECORD_AUDIO,
                REQUEST_MIC,
                result,
            )
            "requestNotifications" -> {
                if (Build.VERSION.SDK_INT >= 33) {
                    request("android.permission.POST_NOTIFICATIONS", REQUEST_NOTIF, result)
                } else {
                    // Pre-13: notifications are granted with the app install.
                    result.success(mapOf("granted" to true))
                }
            }
            "openAppSettings" -> {
                val intent = Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.fromParts("package", context.packageName, null),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                result.success(mapOf("launched" to true))
            }
            else -> result.notImplemented()
        }
    }

    private fun notificationsGranted(): Boolean =
        Build.VERSION.SDK_INT < 33 || isGranted("android.permission.POST_NOTIFICATIONS")

    private fun isGranted(permission: String): Boolean =
        context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun request(permission: String, code: Int, result: MethodChannel.Result) {
        if (isGranted(permission)) {
            result.success(mapOf("granted" to true))
            return
        }
        val existing = pendingResult
        if (existing != null) {
            result.error("BUSY", "A permission request is already in progress", null)
            return
        }
        pendingResult = result
        activity.requestPermissions(arrayOf(permission), code)
    }

    /** Called by MainActivity when the system dialog resolves. */
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        val result = pendingResult ?: return
        pendingResult = null
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        result.success(mapOf("granted" to granted))
    }

    companion object {
        const val REQUEST_MIC = 4301
        const val REQUEST_NOTIF = 4302
    }
}
