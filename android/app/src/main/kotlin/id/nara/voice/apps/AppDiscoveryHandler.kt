package id.nara.voice.apps

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import id.nara.voice.platform.ChannelRegistry
import id.nara.voice.platform.NaraErrors
import java.io.ByteArrayOutputStream
import java.util.Locale

/**
 * App Discovery Engine.
 *
 * Discovers launchable applications through the MAIN/LAUNCHER intent query
 * (honouring Android package-visibility rules — no QUERY_ALL_PACKAGES),
 * exposes icons as PNG bytes, and launches apps through their launch intents.
 */
class AppDiscoveryHandler(private val context: Context) {

    private val packageManager: PackageManager = context.packageManager

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, ChannelRegistry.CHANNEL_APPS).setMethodCallHandler { call, result ->
            try {
                handle(call, result)
            } catch (e: PackageManager.NameNotFoundException) {
                result.error(NaraErrors.NOT_INSTALLED, "Package is not visible or not installed", null)
            } catch (e: IllegalArgumentException) {
                result.error(NaraErrors.INVALID_ARGUMENT, e.message, null)
            } catch (e: NaraErrors.CodedException) {
                result.error(e.code, e.message, null)
            } catch (e: Exception) {
                result.error(NaraErrors.UNSUPPORTED, e.message ?: "Unexpected discovery failure", null)
            }
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInstalledApps" -> result.success(discoverApps())
            "getAppDetails" -> {
                val packageName = requirePackage(call)
                result.success(appDetails(packageName) ?: throw PackageManager.NameNotFoundException(packageName))
            }
            "getAppIcon" -> {
                val packageName = requirePackage(call)
                val size = (call.argument<Int>("size") ?: 96).coerceIn(16, 512)
                val bytes = iconBytes(packageName, size)
                if (bytes == null) {
                    result.error(NaraErrors.NOT_INSTALLED, "No icon for $packageName", null)
                } else {
                    result.success(bytes)
                }
            }
            "launchApp" -> {
                val packageName = requirePackage(call)
                result.success(launchApp(packageName))
            }
            "isAppInstalled" -> {
                val packageName = requirePackage(call)
                result.success(launchIntent(packageName) != null || appDetails(packageName) != null)
            }
            "canHandleUrl" -> {
                val url = call.argument<String>("url")?.trim()
                if (url.isNullOrEmpty()) throw IllegalArgumentException("url is required")
                result.success(canHandleUrl(url))
            }
            else -> result.notImplemented()
        }
    }

    private fun requirePackage(call: MethodCall): String =
        call.argument<String>("packageName")?.trim().takeUnless { it.isNullOrEmpty() }
            ?: throw IllegalArgumentException("packageName is required")

    /** Launchable activities of every visible application, de-duplicated. */
    private fun launchableResolveInfos(): List<ResolveInfo> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return packageManager.queryIntentActivities(intent, PackageManager.MATCH_ALL)
    }

    private fun discoverApps(): List<Map<String, Any?>> {
        val apps = LinkedHashMap<String, MutableMap<String, Any?>>()

        for (info in launchableResolveInfos()) {
            val packageName = info.activityInfo.packageName ?: continue
            if (apps.containsKey(packageName)) continue
            val appInfo = info.activityInfo.applicationInfo ?: continue
            apps[packageName] = mutableMapOf(
                "appName" to (info.loadLabel(packageManager)?.toString() ?: packageName),
                "packageName" to packageName,
                "launchable" to true,
                "enabled" to appInfo.enabled,
                "isSystem" to ((appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                "category" to applicationCategory(appInfo),
                "versionName" to null,
                "versionCode" to null,
            )
        }

        // Packages visible without a launcher entry (system components, services).
        for (info in packageManager.getInstalledPackages(0)) {
            val packageName = info.packageName ?: continue
            val existing = apps[packageName]
            if (existing == null) {
                apps[packageName] = mutableMapOf(
                    "appName" to (info.applicationInfo?.loadLabel(packageManager)?.toString() ?: packageName),
                    "packageName" to packageName,
                    "launchable" to false,
                    "enabled" to (info.applicationInfo?.enabled ?: false),
                    "isSystem" to (((info.applicationInfo?.flags ?: 0) and ApplicationInfo.FLAG_SYSTEM) != 0),
                    "category" to info.applicationInfo?.let { applicationCategory(it) },
                    "versionName" to info.versionName,
                    "versionCode" to if (android.os.Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong(),
                )
            } else {
                existing["versionName"] = info.versionName
                existing["versionCode"] = if (android.os.Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
            }
        }

        return apps.values.toList()
    }

    private fun applicationCategory(info: ApplicationInfo): String? {
        if (android.os.Build.VERSION.SDK_INT >= 26) {
            val category = info.category
            if (category != ApplicationInfo.CATEGORY_UNDEFINED) return category.toString()
        }
        return null
    }

    private fun appDetails(packageName: String): Map<String, Any?>? = try {
        val info = packageManager.getPackageInfo(packageName, 0)
        val appInfo = info.applicationInfo
        mapOf(
            "appName" to appInfo?.loadLabel(packageManager)?.toString().let { it ?: packageName },
            "packageName" to packageName,
            "launchable" to (launchIntent(packageName) != null),
            "enabled" to (appInfo?.enabled ?: false),
            "isSystem" to (((appInfo?.flags ?: 0) and ApplicationInfo.FLAG_SYSTEM) != 0),
            "category" to appInfo?.let { applicationCategory(it) },
            "versionName" to info.versionName,
            "versionCode" to if (android.os.Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong(),
        )
    } catch (e: PackageManager.NameNotFoundException) {
        null
    }

    private fun launchIntent(packageName: String) = packageManager.getLaunchIntentForPackage(packageName)

    private fun iconBytes(packageName: String, sizePx: Int): ByteArray? = try {
        val drawable: Drawable = packageManager.getApplicationIcon(packageName)
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, sizePx, sizePx)
        drawable.draw(canvas)
        val output = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
        bitmap.recycle()
        output.toByteArray()
    } catch (e: PackageManager.NameNotFoundException) {
        null
    } catch (e: Exception) {
        null
    }

    private fun launchApp(packageName: String): Map<String, Any?> {
        val launch = launchIntent(packageName)
            ?: throw NaraErrors.CodedException(
                NaraErrors.APP_NOT_LAUNCHABLE, "Application $packageName has no launchable activity",
            )
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            context.startActivity(launch)
            val resolved = packageManager.resolveActivity(launch, 0)
            mapOf("launched" to true, "handler" to (resolved?.activityInfo?.packageName ?: packageName))
        } catch (e: SecurityException) {
            throw NaraErrors.CodedException(NaraErrors.LAUNCH_FAILED, "Android blocked launching $packageName")
        } catch (e: android.content.ActivityNotFoundException) {
            throw NaraErrors.CodedException(NaraErrors.NOT_RESOLVED, "No activity found for $packageName")
        }
    }

    private fun canHandleUrl(url: String): Boolean {
        val uri = Uri.parse(url) ?: return false
        if (uri.scheme.isNullOrEmpty()) return false
        val intent = Intent(Intent.ACTION_VIEW, uri)
        return packageManager.resolveActivity(intent, 0) != null
    }
}
