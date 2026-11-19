package com.lhht.ai_assistant

import android.Manifest
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Add one call from MainActivity.configureFlutterEngine():
 *
 * AssistantV2Channels.register(this, flutterEngine)
 *
 * Keep the existing system_action channel intact.
 */
class AssistantV2Channels private constructor(
    private val activity: Activity,
    flutterEngine: FlutterEngine
) : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != AssistantV2Contract.ACTION_STATE_CHANGED) return
            eventSink?.success(
                mapOf(
                    "state" to intent.getStringExtra(AssistantV2Contract.EXTRA_STATE),
                    "reason" to intent.getStringExtra(AssistantV2Contract.EXTRA_REASON)
                )
            )
        }
    }
    private var receiverRegistered = false

    init {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AssistantV2Contract.CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startWakeService" -> {
                    val permission = ContextCompat.checkSelfPermission(
                        activity, Manifest.permission.RECORD_AUDIO
                    ) == PackageManager.PERMISSION_GRANTED
                    if (!permission) {
                        result.error("MIC_PERMISSION", "Microphone permission is required", null)
                    } else {
                        try {
                            WakeWordForegroundService.start(activity)
                            result.success(true)
                        } catch (t: Throwable) {
                            result.error("START_FAILED", t.message, null)
                        }
                    }
                }
                "stopWakeService" -> {
                    WakeWordForegroundService.stop(activity)
                    result.success(true)
                }
                "endConversation" -> {
                    activity.startService(
                        Intent(activity, WakeWordForegroundService::class.java).apply {
                            action = WakeWordForegroundService.ACTION_END_CONVERSATION
                        }
                    )
                    result.success(true)
                }
                "openAccessibilitySettings" -> {
                    activity.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(true)
                }
                "accessibilityBack" -> result.success(
                    XiaozhiAccessibilityService.instance?.performBack() == true
                )
                "accessibilityHome" -> {
                    val accSuccess = XiaozhiAccessibilityService.instance?.performHome() == true
                    if (accSuccess) {
                        result.success(true)
                    } else {
                        try {
                            val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                                addCategory(Intent.CATEGORY_HOME)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            activity.startActivity(homeIntent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                }
                "accessibilityRecents" -> result.success(
                    XiaozhiAccessibilityService.instance?.openRecents() == true
                )
                "accessibilityScrollForward" -> result.success(
                    XiaozhiAccessibilityService.instance?.scrollForward() == true
                )
                "accessibilityClickText" -> {
                    val label = call.argument<String>("label").orEmpty()
                    result.success(
                        XiaozhiAccessibilityService.instance?.clickVisibleText(label) == true
                    )
                }
                "isAccessibilityEnabled" -> result.success(isAccessibilityEnabled(activity))
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AssistantV2Contract.EVENT_CHANNEL
        ).setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        if (!receiverRegistered) {
            val filter = IntentFilter(AssistantV2Contract.ACTION_STATE_CHANGED)
            if (Build.VERSION.SDK_INT >= 33) {
                activity.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("DEPRECATION")
                activity.registerReceiver(receiver, filter)
            }
            receiverRegistered = true
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        if (receiverRegistered) {
            try {
                activity.unregisterReceiver(receiver)
            } catch (_: IllegalArgumentException) {
            }
            receiverRegistered = false
        }
    }

    companion object {
        @Volatile private var instance: AssistantV2Channels? = null

        fun register(activity: Activity, engine: FlutterEngine) {
            instance = AssistantV2Channels(activity, engine)
        }

        private fun isAccessibilityEnabled(context: Context): Boolean {
            val expected = "${context.packageName}/${XiaozhiAccessibilityService::class.java.name}"
            val enabled = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false
            return enabled.split(':').any { it.equals(expected, ignoreCase = true) }
        }
    }
}
