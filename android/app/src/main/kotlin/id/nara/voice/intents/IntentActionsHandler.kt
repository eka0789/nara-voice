package id.nara.voice.intents

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.CalendarContract
import android.provider.ContactsContract
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import id.nara.voice.MainActivity
import id.nara.voice.platform.ChannelRegistry
import id.nara.voice.platform.NaraErrors
import java.util.Locale

/**
 * App Integration Engine — executes cross-application actions exclusively
 * through public Android intents (deep links, share sheet, mailto, geo, etc.).
 *
 * Every method reports what actually happened: either an intent resolved and
 * was handed off to the OS, or a typed failure is returned. Handoff to the
 * target application is the documented boundary — NARA never claims an action
 * *inside* another app completed.
 */
class IntentActionsHandler(
    private val context: Context,
    private val activity: MainActivity,
) {

    private var contactCallback: MethodChannel.Result? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, ChannelRegistry.CHANNEL_INTENTS).setMethodCallHandler { call, result ->
            try {
                handle(call, result)
            } catch (e: IllegalArgumentException) {
                result.error(NaraErrors.INVALID_ARGUMENT, e.message, null)
            } catch (e: NaraIntentException) {
                result.error(e.code, e.message, null)
            } catch (e: Exception) {
                result.error(NaraErrors.UNSUPPORTED, e.message ?: "Unexpected intent failure", null)
            }
        }
    }

    fun onContactPicked(approved: Boolean, uri: Uri?) {
        val callback = contactCallback ?: return
        contactCallback = null
        if (!approved || uri == null) {
            callback.success(mapOf("picked" to false))
            return
        }
        val projection = arrayOf(
            ContactsContract.Contacts.DISPLAY_NAME,
            ContactsContract.Contacts._ID,
        )
        val outcome: Map<String, Any?> = try {
            context.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val id = cursor.getString(1)
                    val name = cursor.getString(0) ?: ""
                    var phone: String? = null
                    context.contentResolver.query(
                        ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                        arrayOf(ContactsContract.CommonDataKinds.Phone.NUMBER),
                        "${ContactsContract.CommonDataKinds.Phone.CONTACT_ID} = ?",
                        arrayOf(id),
                        null,
                    )?.use { phoneCursor ->
                        if (phoneCursor.moveToFirst()) phone = phoneCursor.getString(0)
                    }
                    mapOf("picked" to true, "name" to name, "phone" to phone)
                } else {
                    mapOf("picked" to false)
                }
            } ?: mapOf("picked" to false)
        } catch (e: SecurityException) {
            // The user revoked contacts access between pick and query — treat as cancel.
            mapOf("picked" to false)
        }
        callback.success(outcome)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openUrl" -> result.success(openExternal(call.argument<String>("url")))
            "openDeepLink" -> result.success(openExternal(call.argument<String>("url"), allowNonWeb = true))
            "shareText" -> result.success(
                shareText(
                    requireText(call.argument("text")),
                    call.argument<String>("title") ?: "NARA Voice",
                    call.argument<String>("packageName"),
                ),
            )
            "composeWhatsApp" -> result.success(composeWhatsApp(call.argument<String>("phone"), call.argument<String>("text")))
            "composeEmail" -> result.success(composeEmail(call.argument<String>("to"), call.argument<String>("subject"), call.argument<String>("body")))
            "openMaps" -> result.success(openMaps(call.argument<String>("query"), call.argument<String>("mode")))
            "openYouTubeSearch" -> result.success(openYouTubeSearch(requireText(call.argument("query"))))
            "openSpotify" -> result.success(openSpotify(call.argument<String>("query")))
            "openSettings" -> result.success(openSettings(call.argument<String>("screen") ?: "main", call.argument<String>("packageName")))
            "openAppDetails" -> result.success(openAppDetails(requireText(call.argument("packageName"))))
            "insertCalendarEvent" -> result.success(
                insertCalendarEvent(
                    title = requireText(call.argument("title")),
                    description = call.argument<String>("description"),
                    beginMillis = call.argument<Double>("beginMillis")?.toLong(),
                    endMillis = call.argument<Double>("endMillis")?.toLong(),
                    allDay = call.argument<Boolean>("allDay") ?: false,
                ),
            )
            "pickContact" -> {
                if (contactCallback != null) {
                    result.error(NaraErrors.UNSUPPORTED, "A contact pick is already in progress", null)
                    return
                }
                contactCallback = result
                val intent = Intent(Intent.ACTION_PICK, ContactsContract.Contacts.CONTENT_URI)
                try {
                    activity.startActivityForResult(intent, MainActivity.REQUEST_PICK_CONTACT)
                } catch (e: ActivityNotFoundException) {
                    contactCallback = null
                    result.error(NaraErrors.NOT_RESOLVED, "No contacts application available", null)
                } catch (e: SecurityException) {
                    contactCallback = null
                    result.error(NaraErrors.NOT_RESOLVED, "Contacts access blocked by Android", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private class NaraIntentException(val code: String, override val message: String) : Exception(message)

    private fun requireText(value: String?, name: String = "text"): String =
        value?.trim().takeUnless { it.isNullOrEmpty() } ?: throw IllegalArgumentException("$name is required")

    /** Opens a VIEW intent and reports which package handled it. */
    private fun openExternal(url: String?, allowNonWeb: Boolean = false): Map<String, Any?> {
        if (url.isNullOrBlank()) throw IllegalArgumentException("url is required")
        val uri = Uri.parse(url)
        val scheme = uri.scheme?.lowercase(Locale.ROOT)
        if (scheme.isNullOrEmpty()) {
            throw NaraIntentException(NaraErrors.INVALID_ARGUMENT, "URL has no scheme: $url")
        }
        if (allowNonWeb) {
            // Deep links may target any app scheme, but local-file and script
            // schemes are never legitimate assistant actions.
            if (scheme == "file" || scheme == "content" || scheme == "javascript") {
                throw NaraIntentException(NaraErrors.INVALID_ARGUMENT, "Scheme blocked for safety: $scheme")
            }
        } else if (scheme != "http" && scheme != "https") {
            throw NaraIntentException(NaraErrors.INVALID_ARGUMENT, "Only http(s) URLs allowed here: $url")
        }
        val intent = Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return start(intent, "deep link $url")
    }

    private fun shareText(text: String, title: String, restrictToPackage: String?): Map<String, Any?> {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
            putExtra(Intent.EXTRA_TITLE, title)
            if (restrictToPackage != null) setPackage(restrictToPackage)
        }
        val chooser = Intent.createChooser(intent, title).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return start(chooser, "share sheet")
    }

    private fun composeWhatsApp(phone: String?, text: String?): Map<String, Any?> {
        val normalizedPhone = phone?.filter { it.isDigit() }
        val intent: Intent = when {
            !normalizedPhone.isNullOrEmpty() -> {
                val builder = Uri.parse("https://wa.me/$normalizedPhone").buildUpon()
                if (!text.isNullOrBlank()) builder.appendQueryParameter("text", text)
                Intent(Intent.ACTION_VIEW, builder.build())
            }
            else -> {
                // No recipient: hand off through WhatsApp's own share target so the
                // user picks the conversation inside WhatsApp.
                Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    setPackage("com.whatsapp")
                    if (!text.isNullOrBlank()) putExtra(Intent.EXTRA_TEXT, text)
                }
            }
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return start(intent, "WhatsApp compose")
    }

    private fun composeEmail(to: String?, subject: String?, body: String?): Map<String, Any?> {
        val builder = Uri.parse("mailto:").buildUpon()
        if (!to.isNullOrBlank()) {
            builder.appendQueryParameter("to", to.split(",", ";").map { it.trim() }.filter { it.isNotEmpty() }.joinToString(","))
        }
        if (!subject.isNullOrBlank()) builder.appendQueryParameter("subject", subject)
        if (!body.isNullOrBlank()) builder.appendQueryParameter("body", body)
        val intent = Intent(Intent.ACTION_SENDTO, builder.build()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return start(intent, "email compose")
    }

    private fun openMaps(query: String?, mode: String?): Map<String, Any?> {
        val mapsPackage = "com.google.android.apps.maps"
        val installed = try {
            context.packageManager.getPackageInfo(mapsPackage, 0)
            true
        } catch (e: Exception) {
            false
        }
        val intent = when {
            mode == "directions" && !query.isNullOrBlank() -> {
                val uri = Uri.parse("google.navigation:q=${Uri.encode(query)}")
                Intent(Intent.ACTION_VIEW, uri).apply { if (installed) setPackage(mapsPackage) }
            }
            !query.isNullOrBlank() -> {
                val uri = Uri.parse("geo:0,0?q=${Uri.encode(query)}")
                Intent(Intent.ACTION_VIEW, uri).apply { if (installed) setPackage(mapsPackage) }
            }
            installed -> Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0")).apply { setPackage(mapsPackage) }
            else -> throw NaraIntentException(NaraErrors.NOT_RESOLVED, "No maps application is available")
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return start(intent, "maps")
    }

    private fun openYouTubeSearch(query: String): Map<String, Any?> {
        val webUri = Uri.parse("https://www.youtube.com/results?search_query=${Uri.encode(query)}")
        val appUri = Uri.parse("vnd.youtube://results?search_query=${Uri.encode(query)}")
        val appIntent = Intent(Intent.ACTION_VIEW, appUri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val intent = if (context.packageManager.resolveActivity(appIntent, 0) != null) appIntent else {
            Intent(Intent.ACTION_VIEW, webUri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return start(intent, "YouTube search")
    }

    private fun openSpotify(query: String?): Map<String, Any?> {
        val intent = if (query.isNullOrBlank()) {
            Intent(Intent.ACTION_VIEW, Uri.parse("spotify:"))
        } else {
            Intent(Intent.ACTION_VIEW, Uri.parse("spotify:search:${Uri.encode(query)}"))
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (context.packageManager.resolveActivity(intent, 0) == null) {
            // Fall back to the web player rather than failing outright.
            val web = Intent(
                Intent.ACTION_VIEW,
                Uri.parse("https://open.spotify.com/search/${Uri.encode(query ?: "")}"),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            return start(web, "Spotify (web)")
        }
        return start(intent, "Spotify")
    }

    private fun openSettings(screen: String, packageName: String?): Map<String, Any?> {
        val action: String = when (screen) {
            "main", "settings" -> Settings.ACTION_SETTINGS
            "wifi" -> Settings.ACTION_WIFI_SETTINGS
            "bluetooth" -> Settings.ACTION_BLUETOOTH_SETTINGS
            "display" -> Settings.ACTION_DISPLAY_SETTINGS
            "sound" -> Settings.ACTION_SOUND_SETTINGS
            "battery" -> Settings.ACTION_BATTERY_SAVER_SETTINGS
            "accessibility" -> Settings.ACTION_ACCESSIBILITY_SETTINGS
            // ACTION_NOTIFICATION_SETTINGS resolves ambiguously across SDK
            // jars in some toolchains — the literal action is identical.
            "notifications" -> "android.settings.NOTIFICATION_SETTINGS"
            "apps" -> Settings.ACTION_APPLICATION_SETTINGS
            "security" -> Settings.ACTION_SECURITY_SETTINGS
            "locale" -> Settings.ACTION_LOCALE_SETTINGS
            "date" -> Settings.ACTION_DATE_SETTINGS
            "storage" -> Settings.ACTION_INTERNAL_STORAGE_SETTINGS
            "dataUsage" -> Settings.ACTION_DATA_ROAMING_SETTINGS
            "appDetails" -> {
                if (packageName.isNullOrBlank()) {
                    throw IllegalArgumentException("packageName is required for appDetails")
                }
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS
            }
            else -> throw NaraIntentException(NaraErrors.UNSUPPORTED, "Unsupported settings screen: $screen")
        }
        val intent = Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (action == Settings.ACTION_APPLICATION_DETAILS_SETTINGS) {
            intent.data = Uri.fromParts("package", packageName, null)
        }
        return start(intent, "settings:$screen")
    }

    private fun openAppDetails(packageName: String): Map<String, Any?> = openSettings("appDetails", packageName)

    private fun insertCalendarEvent(
        title: String,
        description: String?,
        beginMillis: Long?,
        endMillis: Long?,
        allDay: Boolean,
    ): Map<String, Any?> {
        val intent = Intent(Intent.ACTION_INSERT)
            .setData(CalendarContract.Events.CONTENT_URI)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            .putExtra(CalendarContract.Events.TITLE, title)
        if (!description.isNullOrBlank()) intent.putExtra(CalendarContract.Events.DESCRIPTION, description)
        if (beginMillis != null) intent.putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, beginMillis)
        if (endMillis != null) intent.putExtra(CalendarContract.EXTRA_EVENT_END_TIME, endMillis)
        if (allDay) intent.putExtra(CalendarContract.EXTRA_EVENT_ALL_DAY, true)
        return start(intent, "calendar insert")
    }

    /** Starts an activity and honestly reports which application received it. */
    private fun start(intent: Intent, description: String): Map<String, Any?> {
        val resolved = context.packageManager.resolveActivity(intent, 0)
        try {
            context.startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            throw NaraIntentException(NaraErrors.NOT_RESOLVED, "No application can handle $description")
        } catch (e: SecurityException) {
            throw NaraIntentException(NaraErrors.LAUNCH_FAILED, "Android blocked $description")
        }
        return mapOf(
            "launched" to true,
            "handler" to resolved?.activityInfo?.packageName,
            "description" to description,
        )
    }
}
