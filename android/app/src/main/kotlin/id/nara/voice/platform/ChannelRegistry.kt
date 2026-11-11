package id.nara.voice.platform

import android.content.Context
import id.nara.voice.MainActivity
import id.nara.voice.accessibility.AccessibilityHandler
import id.nara.voice.apps.AppDiscoveryHandler
import id.nara.voice.device.DeviceHandler
import id.nara.voice.intents.IntentActionsHandler
import id.nara.voice.notifications.NotificationHandler
import id.nara.voice.permissions.PermissionsHandler
import id.nara.voice.voice.VoiceHandler
import io.flutter.plugin.common.BinaryMessenger

/**
 * Owns the lifecycle of every platform channel exposed to Flutter.
 * A single registry instance is alive per Flutter engine.
 */
object ChannelRegistry {
    const val CHANNEL_APPS = "nara/apps"
    const val CHANNEL_INTENTS = "nara/intents"
    const val CHANNEL_VOICE = "nara/voice"
    const val CHANNEL_VOICE_EVENTS = "nara/voice/events"
    const val CHANNEL_ACCESSIBILITY = "nara/accessibility"
    const val CHANNEL_NOTIFICATIONS = "nara/notifications"
    const val CHANNEL_PERMISSIONS = "nara/permissions"
    const val CHANNEL_DEVICE = "nara/device"

    var voiceHandler: VoiceHandler? = null
        private set

    var intentActions: IntentActionsHandler? = null
        private set

    private var accessibilityHandler: AccessibilityHandler? = null
    private var appsHandler: AppDiscoveryHandler? = null
    private var notificationsHandler: NotificationHandler? = null
    private var deviceHandler: DeviceHandler? = null

    /** Mutable-public for [MainActivity.onRequestPermissionsResult]. */
    var permissionsHandler: PermissionsHandler? = null
        private set

    @Synchronized
    fun register(context: Context, messenger: BinaryMessenger, activity: MainActivity) {
        teardown()

        appsHandler = AppDiscoveryHandler(context).also { it.register(messenger) }
        intentActions = IntentActionsHandler(context, activity).also { it.register(messenger) }
        voiceHandler = VoiceHandler(context).also { it.register(messenger) }
        accessibilityHandler = AccessibilityHandler(context).also { it.register(messenger) }
        notificationsHandler = NotificationHandler(context).also { it.register(messenger) }
        deviceHandler = DeviceHandler(context).also { it.register(messenger) }
        permissionsHandler = PermissionsHandler(context, activity).also { it.register(messenger) }
    }

    @Synchronized
    fun teardown() {
        voiceHandler?.dispose()
        voiceHandler = null
        intentActions = null
        accessibilityHandler?.dispose()
        accessibilityHandler = null
        appsHandler = null
        notificationsHandler = null
        deviceHandler = null
    }
}
