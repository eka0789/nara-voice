package id.nara.voice.notifications

import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import id.nara.voice.platform.ChannelRegistry
import id.nara.voice.platform.NaraErrors

/**
 * MethodChannel facade over [NaraNotificationListenerService].
 */
class NotificationHandler(private val context: Context) {

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, ChannelRegistry.CHANNEL_NOTIFICATIONS).setMethodCallHandler { call, result ->
            when (call.method) {
                "isEnabled" -> result.success(NaraNotificationListenerService.isConnected)
                "openListenerSettings" -> {
                    context.startActivity(
                        Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success(mapOf("launched" to true))
                }
                "getRecent" -> {
                    if (!NaraNotificationListenerService.isConnected) {
                        result.error(NaraErrors.SERVICE_NOT_ENABLED, "Notification listener access is not granted", null)
                        return@setMethodCallHandler
                    }
                    val limit = (call.argument<Int>("limit") ?: 10).coerceIn(1, 20)
                    result.success(NaraNotificationListenerService.recentNotifications(limit))
                }
                else -> result.notImplemented()
            }
        }
    }
}
