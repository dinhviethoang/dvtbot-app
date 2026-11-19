package com.lhht.ai_assistant

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.lhht.ai_assistant/system_action"
    private lateinit var actionExecutor: AssistantActionExecutor
    private val OVERLAY_PERMISSION_REQ_CODE = 1234

    override fun onCreate(savedInstanceState: Bundle?) {
        // Bỏ qua lỗi chứng chỉ SSL trên Android 7.1.1 cũ (Samsung Galaxy J2 Pro)
        UnsafeSslHelper.enableUnsafeSsl()

        super.onCreate(savedInstanceState)
        // 1. Giữ màn hình luôn sáng suốt thời gian mở app trên Samsung Galaxy J2 Pro
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        actionExecutor = AssistantActionExecutor(applicationContext)
    }

    private fun checkAndRequestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                try {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:$packageName")
                    )
                    startActivityForResult(intent, OVERLAY_PERMISSION_REQ_CODE)
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Lỗi yêu cầu quyền Overlay", e)
                }
            }
        }
    }

    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true // Android < 6.0 luôn được cấp quyền ngầm định
        }
    }

    override fun onPause() {
        super.onPause()
        // Khi app bị đẩy xuống nền, tự động kích hoạt bong bóng nổi FloatingAvatarService
        if (canDrawOverlays()) {
            val intent = Intent(this, FloatingAvatarService::class.java).apply {
                action = FloatingAvatarService.ACTION_START
                putExtra(FloatingAvatarService.EXTRA_STATE, "idle")
            }
            startService(intent)
        }
    }

    override fun onResume() {
        super.onResume()
        // Giữ màn hình luôn sáng
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // Khi app quay lại tiền cảnh, tắt bong bóng nổi
        val intent = Intent(this, FloatingAvatarService::class.java).apply {
            action = FloatingAvatarService.ACTION_STOP
        }
        stopService(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Đăng ký Native Bridge cho Xiaozhi 2.0 (WakeWord Foreground Service & Accessibility)
        AssistantV2Channels.register(this, flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openGoogleMaps" -> {
                    val destination = call.argument<String>("destination") ?: ""
                    result.success(actionExecutor.openGoogleMaps(destination))
                }
                "openYouTube" -> {
                    val query = call.argument<String>("query") ?: ""
                    result.success(actionExecutor.openYouTube(query))
                }
                "openApp" -> {
                    val appName = call.argument<String>("appName") ?: ""
                    result.success(actionExecutor.openApp(appName))
                }
                "makePhoneCall" -> {
                    val phoneNumber = call.argument<String>("phoneNumber") ?: ""
                    result.success(actionExecutor.makePhoneCall(phoneNumber))
                }
                "setVolume" -> {
                    val level = call.argument<Int>("level") ?: 50
                    result.success(actionExecutor.setVolume(level))
                }
                "adjustVolume" -> {
                    val up = call.argument<Boolean>("up") ?: true
                    result.success(actionExecutor.adjustVolume(up))
                }
                "toggleFlashlight" -> {
                    val state = call.argument<Boolean>("state") ?: false
                    result.success(actionExecutor.toggleFlashlight(state))
                }
                "openWifiSettings" -> {
                    result.success(actionExecutor.openWifiSettings())
                }
                "openBluetoothSettings" -> {
                    result.success(actionExecutor.openBluetoothSettings())
                }
                "getSystemStatus" -> {
                    result.success(actionExecutor.getSystemStatus())
                }
                "checkOverlayPermission" -> {
                    result.success(canDrawOverlays())
                }
                "requestOverlayPermission" -> {
                    checkAndRequestOverlayPermission()
                    result.success(true)
                }
                "startFloatingAvatar" -> {
                    val state = call.argument<String>("state") ?: "idle"
                    if (canDrawOverlays()) {
                        val intent = Intent(this, FloatingAvatarService::class.java).apply {
                            action = FloatingAvatarService.ACTION_START
                            putExtra(FloatingAvatarService.EXTRA_STATE, state)
                        }
                        startService(intent)
                        result.success(true)
                    } else {
                        checkAndRequestOverlayPermission()
                        result.success(false)
                    }
                }
                "stopFloatingAvatar" -> {
                    val intent = Intent(this, FloatingAvatarService::class.java).apply {
                        action = FloatingAvatarService.ACTION_STOP
                    }
                    stopService(intent)
                    result.success(true)
                }
                "updateFloatingAvatarState" -> {
                    val state = call.argument<String>("state") ?: "idle"
                    val intent = Intent(this, FloatingAvatarService::class.java).apply {
                        action = FloatingAvatarService.ACTION_UPDATE_STATE
                        putExtra(FloatingAvatarService.EXTRA_STATE, state)
                    }
                    startService(intent)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
