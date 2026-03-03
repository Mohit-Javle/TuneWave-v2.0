package com.example.tunewave

import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceFragmentActivity() {
    private val CHANNEL = "com.example.tunewave/apk_share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getApkPath") {
                try {
                    val apkPath = packageCodePath
                    result.success(apkPath)
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", "APK path not available.", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
