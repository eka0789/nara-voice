package id.nara.voice.routines

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import id.nara.voice.MainActivity
import id.nara.voice.R

/**
 * Fires a scheduled routine: posts a tap-to-run notification instead of
 * executing anything silently — NARA never acts in the background without
 * the user's explicit tap. Daily routines re-arm for tomorrow.
 */
class NaraRoutineReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            RoutineScheduler.rescheduleAll(context)
            return
        }

        val id = intent.getStringExtra("id") ?: return
        val title = intent.getStringExtra("title") ?: "Routine"
        val commands = intent.getStringArrayExtra("commands")?.toList().orEmpty()
        if (commands.isEmpty()) return

        postNotification(context, title, commands)
        RoutineScheduler.onFired(context, id)
    }

    private fun postNotification(context: Context, title: String, commands: List<String>) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(
                CHANNEL_ROUTINES,
                "Jadwal rutin NARA",
                NotificationManager.IMPORTANCE_DEFAULT,
            )
            manager.createNotificationChannel(channel)
        }

        val granted = if (Build.VERSION.SDK_INT >= 33) {
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
        if (!granted) return // Honest limitation: no silent background execution.

        val open = PendingIntent.getActivity(
            context,
            REQUEST_RUN,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                .putExtra(EXTRA_ROUTINE_COMMANDS, commands.toTypedArray()),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(context, CHANNEL_ROUTINES)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("NARA — $title")
            .setContentText(commands.joinToString(" • "))
            .setStyle(
                Notification.BigTextStyle().bigText(
                    "Ketuk untuk menjalankan:\n" + commands.joinToString("\n") { "→ $it" },
                ),
            )
            .setContentIntent(open)
            .setAutoCancel(true)

        manager.notify(NOTIFICATION_TAG, REQUEST_RUN, builder.build())
    }

    companion object {
        const val CHANNEL_ROUTINES = "nara_routines"
        const val NOTIFICATION_TAG = "nara_routine"
        const val REQUEST_RUN = 4401
        const val EXTRA_ROUTINE_COMMANDS = "nara_routine_commands"
    }
}
