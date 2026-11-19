package com.lhht.ai_assistant

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

/**
 * Foreground microphone service for local wake-word detection.
 *
 * Start this service only from a user-visible, policy-compliant flow after
 * RECORD_AUDIO permission has been granted. On Android 14+, the manifest must
 * declare foregroundServiceType="microphone" and the corresponding permission.
 *
 * This service intentionally refuses to start recording until WakeWordEngine.create()
 * has been implemented with a real local model.
 */
class WakeWordForegroundService : Service() {
    companion object {
        private const val TAG = "XiaozhiWakeService"
        const val ACTION_START = "com.lhht.ai_assistant.WAKE_START"
        const val ACTION_STOP = "com.lhht.ai_assistant.WAKE_STOP"
        const val ACTION_END_CONVERSATION = "com.lhht.ai_assistant.END_CONVERSATION"

        fun start(context: Context) {
            val intent = Intent(context, WakeWordForegroundService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.startService(
                Intent(context, WakeWordForegroundService::class.java).apply {
                    action = ACTION_STOP
                }
            )
        }
    }

    private val running = AtomicBoolean(false)
    private var recorder: AudioRecord? = null
    private var engine: WakeWordEngine? = null
    private var worker: Thread? = null
    private var conversationActive = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopCapture()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_END_CONVERSATION -> {
                conversationActive = false
                try {
                    if (running.get() && recorder?.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                        recorder?.startRecording()
                        Log.i(TAG, "[AUDIO] owner=standby_wake")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Lỗi khởi động lại AudioRecord sau hội thoại", e)
                }
                broadcastState(AssistantV2Contract.STATE_STANDBY, "conversation_ended")
                updateNotification("Đang chờ “TinGTinG ơi”")
            }
            ACTION_START, null -> startCaptureSafely()
        }
        return START_STICKY
    }

    private fun startCaptureSafely() {
        if (running.get()) return

        startForeground(
            AssistantV2Contract.NOTIFICATION_ID,
            buildNotification("Đang chuẩn bị nhận diện câu gọi")
        )

        try {
            // Fails closed until a real offline model is supplied.
            engine = WakeWordEngine.create(applicationContext)
            startAudioLoop()
        } catch (t: Throwable) {
            Log.e(TAG, "Wake-word engine unavailable", t)
            broadcastState(AssistantV2Contract.STATE_ERROR, t.message ?: "wake_model_missing")
            updateNotification("Chưa cài model nhận diện TinGTinG ơi")
            // Do not keep a microphone foreground service running without a working detector.
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    private fun startAudioLoop() {
        val sampleRate = 16_000
        val minBuffer = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        require(minBuffer > 0) { "AudioRecord buffer unsupported: $minBuffer" }

        val bufferSize = maxOf(minBuffer, 4096)
        val audioRecord = AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
        )
        require(audioRecord.state == AudioRecord.STATE_INITIALIZED) {
            "AudioRecord initialization failed"
        }

        recorder = audioRecord
        running.set(true)
        audioRecord.startRecording()
        Log.i(TAG, "[AUDIO] owner=standby_wake")
        broadcastState(AssistantV2Contract.STATE_STANDBY, "wake_word_ready")
        updateNotification("Đang chờ “TinGTinG ơi”")

        worker = thread(name = "XiaozhiWakeWord") {
            val frame = ShortArray(512) // 32 ms at 16 kHz
            try {
                while (running.get()) {
                    if (conversationActive) {
                        try {
                            Thread.sleep(100)
                        } catch (_: InterruptedException) {
                            break
                        }
                        continue
                    }

                    if (audioRecord.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                        try {
                            audioRecord.startRecording()
                        } catch (e: Exception) {
                            Log.w(TAG, "AudioRecord chưa sẵn sàng, thử lại sau...", e)
                            Thread.sleep(150)
                            continue
                        }
                    }

                    val count = audioRecord.read(frame, 0, frame.size)
                    if (count <= 0) continue
                    val chunk = if (count == frame.size) frame else frame.copyOf(count)
                    if (!conversationActive && engine?.processAudio(chunk, sampleRate) == true) {
                        conversationActive = true
                        Log.i(TAG, "[WAKE] phrase_detected=true")
                        try {
                            // Dừng AudioRecord native ngay lập tức để giải phóng hoàn toàn phần cứng Micro cho Flutter
                            audioRecord.stop()
                            Log.i(TAG, "[AUDIO] owner=conversation")
                        } catch (e: Exception) {
                            Log.w(TAG, "Không thể tạm dừng AudioRecord khi chuyển sang hội thoại", e)
                        }
                        broadcastState(
                            AssistantV2Contract.STATE_WAKE_DETECTED,
                            AssistantV2Contract.WAKE_PHRASE_DISPLAY
                        )
                        updateNotification("Đã đánh thức – đang mở phiên trò chuyện")
                    }
                }
            } catch (t: Throwable) {
                Log.e(TAG, "Audio loop failed", t)
                broadcastState(AssistantV2Contract.STATE_ERROR, t.message ?: "audio_loop_error")
            } finally {
                running.set(false)
            }
        }
    }

    private fun stopCapture() {
        running.set(false)
        try {
            recorder?.stop()
        } catch (_: Throwable) {
        }
        try {
            worker?.join(500)
        } catch (_: InterruptedException) {
        }
        try {
            recorder?.release()
        } catch (_: Throwable) {
        }
        recorder = null
        worker = null
        try {
            engine?.close()
        } catch (_: Throwable) {
        }
        engine = null
        conversationActive = false
        broadcastState(AssistantV2Contract.STATE_STOPPED, "user_stopped")
    }

    private fun broadcastState(state: String, reason: String) {
        sendBroadcast(
            Intent(AssistantV2Contract.ACTION_STATE_CHANGED).apply {
                setPackage(packageName)
                putExtra(AssistantV2Contract.EXTRA_STATE, state)
                putExtra(AssistantV2Contract.EXTRA_REASON, reason)
            }
        )
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                AssistantV2Contract.NOTIFICATION_CHANNEL_ID,
                "Xiaozhi Assistant",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Trạng thái trợ lý giọng nói Xiaozhi"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildNotification(message: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentPendingIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this, 2302, it,
                PendingIntent.FLAG_UPDATE_CURRENT or
                    (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
            )
        }

        val stopIntent = PendingIntent.getService(
            this,
            2303,
            Intent(this, WakeWordForegroundService::class.java).apply { action = ACTION_STOP },
            PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        return NotificationCompat.Builder(this, AssistantV2Contract.NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("Xiaozhi đang hoạt động")
            .setContentText(message)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(contentPendingIntent)
            .addAction(0, "Tắt trợ lý", stopIntent)
            .build()
    }

    private fun updateNotification(message: String) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(AssistantV2Contract.NOTIFICATION_ID, buildNotification(message))
    }

    override fun onDestroy() {
        stopCapture()
        super.onDestroy()
    }
}
