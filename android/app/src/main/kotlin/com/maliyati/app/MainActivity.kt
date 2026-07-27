package com.maliyati.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var floatingInputChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        floatingInputChannel =
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                "maliyati/floating_input",
            ).also { channel ->
                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "hasPermission" -> result.success(Settings.canDrawOverlays(this))
                        "requestPermission" -> {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName"),
                                ),
                            )
                            result.success(null)
                        }
                        "show" -> {
                            val intent =
                                Intent(this, FloatingInputService::class.java)
                                    .setAction(FloatingInputService.ACTION_SHOW)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(null)
                        }
                        "hide" -> {
                            stopService(
                                Intent(this, FloatingInputService::class.java)
                                    .setAction(FloatingInputService.ACTION_HIDE),
                            )
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == FloatingInputService.ACTION_OPEN_INPUT) {
            floatingInputChannel?.invokeMethod("bubbleTapped", null)
            intent.action = null
        }
    }

    override fun onResume() {
        super.onResume()
        if (intent?.action == FloatingInputService.ACTION_OPEN_INPUT) {
            floatingInputChannel?.invokeMethod("bubbleTapped", null)
            intent.action = null
        }
    }
}
