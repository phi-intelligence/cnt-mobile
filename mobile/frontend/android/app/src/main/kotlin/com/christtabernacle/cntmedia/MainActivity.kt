package com.christtabernacle.cntmedia

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val securityChannel = "com.christtabernacle.cntmedia/security"
    private val tokenStorageChannel = "com.christtabernacle.cntmedia/token_storage"
    private val authPrefsName = "cnt_auth"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, securityChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enableScreenProtection" -> {
                        window.setFlags(
                            WindowManager.LayoutParams.FLAG_SECURE,
                            WindowManager.LayoutParams.FLAG_SECURE
                        )
                        result.success(null)
                    }
                    "disableScreenProtection" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Native token storage — same role as web localStorage; avoids broken
        // flutter_secure_storage / shared_preferences pigeon channels in release.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, tokenStorageChannel)
            .setMethodCallHandler { call, result ->
                val prefs = getSharedPreferences(authPrefsName, MODE_PRIVATE)
                when (call.method) {
                    "write" -> {
                        val key = call.argument<String>("key")
                        if (key.isNullOrEmpty()) {
                            result.error("invalid_args", "key is required", null)
                            return@setMethodCallHandler
                        }
                        val value = call.argument<String>("value")
                        val editor = prefs.edit()
                        if (value == null) {
                            editor.remove(key)
                        } else {
                            editor.putString(key, value)
                        }
                        editor.apply()
                        result.success(null)
                    }
                    "read" -> {
                        val key = call.argument<String>("key")
                        if (key.isNullOrEmpty()) {
                            result.error("invalid_args", "key is required", null)
                            return@setMethodCallHandler
                        }
                        result.success(prefs.getString(key, null))
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
