package id.nara.voice.device

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import id.nara.voice.platform.ChannelRegistry

/**
 * Read-only device facts used to ground assistant responses.
 */
class DeviceHandler(private val context: Context) {

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, ChannelRegistry.CHANNEL_DEVICE).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceInfo" -> result.success(deviceInfo())
                "getBattery" -> result.success(batteryStatus())
                else -> result.notImplemented()
            }
        }
    }

    private fun deviceInfo(): Map<String, Any?> {
        val packageInfo = try {
            context.packageManager.getPackageInfo(context.packageName, 0)
        } catch (e: Exception) {
            null
        }
        return mapOf(
            "model" to Build.MODEL,
            "manufacturer" to Build.MANUFACTURER,
            "brand" to Build.BRAND,
            "androidRelease" to Build.VERSION.RELEASE,
            "sdkInt" to Build.VERSION.SDK_INT,
            "appVersionName" to packageInfo?.versionName,
            "appVersionCode" to packageInfo?.let {
                if (Build.VERSION.SDK_INT >= 28) it.longVersionCode else it.versionCode.toLong()
            },
            "locale" to context.resources.configuration.locales[0].toLanguageTag(),
        )
    }

    private fun batteryStatus(): Map<String, Any?> {
        val sticky = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = sticky?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = sticky?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
        val status = sticky?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
            status == BatteryManager.BATTERY_STATUS_FULL
        val percent = if (level >= 0 && scale > 0) (level * 100 / scale) else null
        return mapOf("level" to percent, "charging" to charging)
    }
}
