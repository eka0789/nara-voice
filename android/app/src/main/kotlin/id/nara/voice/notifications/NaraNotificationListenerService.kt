package id.nara.voice.notifications

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Optional notification listener. Keeps a small in-memory ring buffer of
 * recent visible notifications so the assistant can answer
 * "what are my notifications". Nothing is persisted, logged, or uploaded;
 * NARA's own notifications are excluded.
 */
class NaraNotificationListenerService : NotificationListenerService() {

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
    }

    override fun onListenerDisconnected() {
        if (instance === this) instance = null
        super.onListenerDisconnected()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val notification = sbn ?: return
        val packageName = notification.packageName ?: return
        if (packageName == applicationContext.packageName) return
        val extras = notification.notification?.extras ?: return

        val title = extras.getCharSequence(android.app.Notification.EXTRA_TITLE)?.toString()
        val text = extras.getCharSequence(android.app.Notification.EXTRA_TEXT)?.toString()
        val bigText = extras.getCharSequence(android.app.Notification.EXTRA_BIG_TEXT)?.toString()
        if (title.isNullOrBlank() && text.isNullOrBlank()) return
        if (notification.isOngoing) return

        synchronized(buffer) {
            buffer.removeAll { it["key"] == sbn.key }
            buffer.addFirst(
                linkedMapOf(
                    "key" to sbn.key,
                    "packageName" to packageName,
                    "title" to title,
                    "text" to (bigText ?: text),
                    "postedAt" to notification.postTime,
                    "clearable" to notification.isClearable,
                ),
            )
            while (buffer.size > BUFFER_LIMIT) {
                buffer.removeLast()
            }
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        val key = sbn?.key ?: return
        synchronized(buffer) {
            buffer.removeAll { it["key"] == key }
        }
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        synchronized(buffer) { buffer.clear() }
        super.onDestroy()
    }

    companion object {
        private const val BUFFER_LIMIT = 20
        private val buffer = ArrayDeque<Map<String, Any?>>()

        @Volatile
        var instance: NaraNotificationListenerService? = null
            private set

        val isConnected: Boolean get() = instance != null

        fun recentNotifications(limit: Int): List<Map<String, Any?>> = synchronized(buffer) {
            buffer.take(limit.coerceIn(1, BUFFER_LIMIT)).toList()
        }
    }
}
