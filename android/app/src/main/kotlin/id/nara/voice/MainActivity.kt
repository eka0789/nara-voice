package id.nara.voice

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import id.nara.voice.platform.ChannelRegistry

/**
 * Flutter entry point. All native functionality is exposed through the channels
 * registered by [ChannelRegistry]; the activity itself stays thin.
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ChannelRegistry.register(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
            this,
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        ChannelRegistry.teardown()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_PICK_CONTACT) {
            ChannelRegistry.intentActions?.onContactPicked(
                approved = resultCode == RESULT_OK,
                uri = data?.data,
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        ChannelRegistry.permissionsHandler?.onRequestPermissionsResult(requestCode, grantResults)
    }

    companion object {
        const val REQUEST_PICK_CONTACT: Int = 4201
    }
}
