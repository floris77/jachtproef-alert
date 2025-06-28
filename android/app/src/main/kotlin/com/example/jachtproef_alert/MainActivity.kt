package com.example.jachtproef_alert

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build

class MainActivity: FlutterActivity() {
    private val DEVICE_CHANNEL = "com.example.jachtproef_alert/device_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceModel" -> {
                    result.success(Build.MODEL)
                }
                "getManufacturer" -> {
                    result.success(Build.MANUFACTURER)
                }
                "getProduct" -> {
                    result.success(Build.PRODUCT)
                }
                "getBuildFingerprint" -> {
                    result.success(Build.FINGERPRINT)
                }
                "getDeviceInfo" -> {
                    val deviceInfo = mapOf(
                        "model" to Build.MODEL,
                        "manufacturer" to Build.MANUFACTURER,
                        "product" to Build.PRODUCT,
                        "fingerprint" to Build.FINGERPRINT,
                        "brand" to Build.BRAND,
                        "device" to Build.DEVICE,
                        "board" to Build.BOARD,
                        "hardware" to Build.HARDWARE
                    )
                    result.success(deviceInfo)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
} 