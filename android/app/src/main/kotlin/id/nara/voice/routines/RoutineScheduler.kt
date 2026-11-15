package id.nara.voice.routines

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import id.nara.voice.MainActivity
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * Daily/one-shot routine alarms built on [AlarmManager.setAlarmClock] — the
 * alarm-clock privilege path is exact on every supported API level and needs
 * no special-permission grant.
 *
 * Honesty contract: a routine never executes actions silently in the
 * background. When it fires, [NaraRoutineReceiver] posts a notification
 * whose tap opens NARA and runs the stored commands in the foreground.
 */
object RoutineScheduler {

    private const val PREFS = "nara_routines"
    private const val KEY_ROUTINES = "routines"

    fun save(
        context: Context,
        id: String,
        hour: Int,
        minute: Int,
        daily: Boolean,
        title: String,
        commands: List<String>,
    ): Map<String, Any?> {
        require(hour in 0..23 && minute in 0..59) { "Time out of range" }
        require(commands.isNotEmpty()) { "A routine needs at least one command" }

        val store = readStore(context)
        store.put(
            id,
            JSONObject()
                .put("hour", hour)
                .put("minute", minute)
                .put("daily", daily)
                .put("title", title)
                .put("commands", JSONArray(commands)),
        )
        writeStore(context, store)
        scheduleNext(context, id)
        return mapOf("scheduled" to true, "id" to id)
    }

    fun cancel(context: Context, id: String): Map<String, Any?> {
        val store = readStore(context)
        store.remove(id)
        writeStore(context, store)
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        alarm?.cancel(fireIntent(context, id, emptyList(), ""))
        return mapOf("cancelled" to true)
    }

    /** Re-arms every stored routine (app start / device reboot). */
    fun rescheduleAll(context: Context) {
        for (id in readStore(context).keys()) {
            scheduleNext(context, id)
        }
    }

    /** Schedules the next occurrence for one routine. */
    private fun scheduleNext(context: Context, id: String) {
        val entry = readStore(context).optJSONObject(id) ?: return
        val hour = entry.getInt("hour")
        val minute = entry.getInt("minute")
        val daily = entry.getBoolean("daily")

        val alarm = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val title = entry.optString("title", "Routine")
        val commands = entry.optJSONArray("commands").orEmptyToList()

        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }
        if (!daily && next.timeInMillis > System.currentTimeMillis() + 366L * 24 * 3600 * 1000) {
            // One-shot older than a year in the future: drop it.
            return
        }

        val fire = fireIntent(context, id, commands, title)
        val open = PendingIntent.getActivity(
            context,
            id.hashCode(),
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarm.setAlarmClock(AlarmManager.AlarmClockInfo(next.timeInMillis, open), fire)
    }

    private fun fireIntent(
        context: Context,
        id: String,
        commands: List<String>,
        title: String,
    ): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            Intent(context, NaraRoutineReceiver::class.java)
                .putExtra("id", id)
                .putExtra("title", title)
                .putExtra("commands", commands.toTypedArray()),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    /** Called by the receiver after a fire: re-arm daily, drop one-shot. */
    fun onFired(context: Context, id: String) {
        val entry = readStore(context).optJSONObject(id) ?: return
        if (entry.getBoolean("daily")) {
            scheduleNext(context, id)
        } else {
            cancel(context, id)
        }
    }

    private fun readStore(context: Context): JSONObject {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return JSONObject(prefs.getString(KEY_ROUTINES, "{}") ?: "{}")
    }

    private fun writeStore(context: Context, store: JSONObject) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_ROUTINES, store.toString())
            .apply()
    }

    private fun JSONArray.orEmptyToList(): List<String> {
        val result = ArrayList<String>(length())
        for (i in 0 until length()) result.add(optString(i))
        return result
    }
}
