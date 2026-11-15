package id.nara.voice.device

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import id.nara.voice.platform.ChannelRegistry
import id.nara.voice.platform.NaraErrors

/**
 * Read-only device facts plus universal device controls (volume, torch).
 */
class DeviceHandler(private val context: Context) {

    private val audio: AudioManager?
        get() = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager

    private val camera: CameraManager?
        get() = context.getSystemService(Context.CAMERA_SERVICE) as? CameraManager

    /** Last torch state we set; systems report no absolute state without a callback. */
    private var torchOn = false

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, ChannelRegistry.CHANNEL_DEVICE).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getDeviceInfo" -> result.success(deviceInfo())
                    "getBattery" -> result.success(batteryStatus())
                    "volumeUp" -> result.success(adjustVolume(AudioManager.ADJUST_RAISE))
                    "volumeDown" -> result.success(adjustVolume(AudioManager.ADJUST_LOWER))
                    "toggleMute" -> result.success(toggleMute())
                    "setTorch" -> result.success(setTorch(call.argument<Boolean>("on") ?: true))
                    "getBrightness" -> result.success(brightness())
                    "setBrightness" -> result.success(
                        setBrightness(call.argument<Number>("level")?.toInt() ?: 50),
                    )
                    "openWriteSettings" -> result.success(openWriteSettings())
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("UNSUPPORTED", e.message ?: "Unexpected device-info failure", null)
            }
        }
    }

    /** Media volume with the system volume HUD so the user sees the change. */
    private fun adjustVolume(direction: Int): Map<String, Any?> {
        val manager = audio ?: throw NaraError("Audio service unavailable")
        manager.adjustStreamVolume(AudioManager.STREAM_MUSIC, direction, AudioManager.FLAG_SHOW_UI)
        val max = manager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val current = manager.getStreamVolume(AudioManager.STREAM_MUSIC)
        return mapOf(
            "performed" to true,
            "level" to if (max > 0) (current * 100 / max) else null,
            "muted" to manager.isStreamMute(AudioManager.STREAM_MUSIC),
        )
    }

    private fun toggleMute(): Map<String, Any?> {
        val manager = audio ?: throw NaraError("Audio service unavailable")
        val direction =
            if (manager.isStreamMute(AudioManager.STREAM_MUSIC)) AudioManager.ADJUST_UNMUTE
            else AudioManager.ADJUST_MUTE
        manager.adjustStreamVolume(AudioManager.STREAM_MUSIC, direction, AudioManager.FLAG_SHOW_UI)
        return mapOf(
            "performed" to true,
            "muted" to manager.isStreamMute(AudioManager.STREAM_MUSIC),
        )
    }

    /** Camera flash torch (normal FLASHLIGHT permission; no user prompt). */
    private fun setTorch(on: Boolean): Map<String, Any?> {
        val manager = camera ?: throw NaraError("Camera service unavailable")
        val torchCamera = manager.cameraIdList.firstOrNull { id ->
            val characteristics = manager.getCameraCharacteristics(id)
            characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true &&
                characteristics.get(CameraCharacteristics.LENS_FACING) ==
                CameraCharacteristics.LENS_FACING_BACK
        } ?: throw NaraError("No flashlight available on this device")
        manager.setTorchMode(torchCamera, on)
        torchOn = on
        return mapOf("performed" to true, "on" to on)
    }

    private class NaraError(override val message: String) : RuntimeException(message)

    // ===== Brightness (WRITE_SETTINGS special access) =====

    private fun brightness(): Map<String, Any?> {
        val canWrite = Settings.System.canWrite(context)
        val current = if (canWrite) {
            Settings.System.getInt(context.contentResolver, Settings.System.SCREEN_BRIGHTNESS, 128)
        } else {
            null
        }
        return mapOf(
            "canWrite" to canWrite,
            "level" to current?.let { (it * 100 / 255) },
        )
    }

    /** [level] is 1-100; mapped onto the 1-255 brightness setting. */
    private fun setBrightness(level: Int): Map<String, Any?> {
        if (!Settings.System.canWrite(context)) {
            throw NaraError("Modify-system-settings access is not granted")
        }
        val clamped = level.coerceIn(1, 100)
        val value = (clamped * 255 / 100).coerceIn(1, 255)
        Settings.System.putInt(
            context.contentResolver,
            Settings.System.SCREEN_BRIGHTNESS,
            value,
        )
        return mapOf("performed" to true, "level" to clamped)
    }

    /** Opens the special-access screen where the user flips "Modify system settings". */
    private fun openWriteSettings(): Map<String, Any?> {
        val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS)
            .setData(Uri.parse("package:${context.packageName}"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        return mapOf("launched" to true)
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
            "torchOn" to torchOn,
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
