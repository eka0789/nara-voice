package id.nara.voice.routines

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import id.nara.voice.platform.ChannelRegistry
import id.nara.voice.platform.NaraErrors

/**
 * MethodChannel facade over [RoutineScheduler]. Routines never auto-run:
 * they post tap-to-run notifications, and the stored commands replay inside
 * NARA only after the user taps.
 */
class RoutineHandler(private val context: Context) {

    /** Commands queued by a fired routine, waiting for the app to consume. */
    private val pendingCommands = ArrayDeque<List<String>>()

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, ChannelRegistry.CHANNEL_ROUTINES).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "save" -> result.success(
                        RoutineScheduler.save(
                            context,
                            id = requireText(call.argument("id"), name = "id"),
                            hour = call.argument<Number>("hour")?.toInt() ?: 7,
                            minute = call.argument<Number>("minute")?.toInt() ?: 0,
                            daily = call.argument<Boolean>("daily") ?: true,
                            title = call.argument<String>("title") ?: "Routine",
                            commands = call.argument<List<String>>("commands") ?: emptyList(),
                        ),
                    )
                    "cancel" -> result.success(
                        RoutineScheduler.cancel(context, requireText(call.argument("id"), name = "id")),
                    )
                    "rescheduleAll" -> {
                        RoutineScheduler.rescheduleAll(context)
                        result.success(mapOf("scheduled" to true))
                    }
                    "consumePending" -> {
                        val drained = ArrayList<List<String>>(pendingCommands.size)
                        while (pendingCommands.isNotEmpty()) drained.add(pendingCommands.removeFirst())
                        result.success(mapOf("commands" to drained))
                    }
                    else -> result.notImplemented()
                }
            } catch (e: IllegalArgumentException) {
                result.error(NaraErrors.INVALID_ARGUMENT, e.message, null)
            } catch (e: Exception) {
                result.error(NaraErrors.UNSUPPORTED, e.message ?: "Unexpected routine failure", null)
            }
        }
    }

    /** Queues commands delivered by [NaraRoutineReceiver] via MainActivity. */
    fun enqueueRoutine(commands: List<String>) {
        if (commands.isNotEmpty()) pendingCommands.add(commands)
    }

    private fun requireText(value: String?, name: String): String =
        value?.trim().takeUnless { it.isNullOrEmpty() }
            ?: throw IllegalArgumentException("$name is required")

    fun dispose() {
        pendingCommands.clear()
    }
}
