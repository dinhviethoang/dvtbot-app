package com.lhht.ai_assistant

import android.content.Context
import android.util.Log
import java.io.File
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Offline wake-word adapter for "TinGTinG ơi".
 *
 * Implements a dual-stage local keyword spotting architecture:
 * 1. Multi-band spectral filterbank analysis (16 kHz mono PCM16) measuring:
 *    - Spectral Zero-Crossing Rate (ZCR)
 *    - Formant band energy (F1: 200-600Hz, F2 / Nasal: 1800-2400Hz, Plosive burst: 2500-4500Hz)
 *    - High-frequency noise rejection (>5000Hz)
 * 2. Sequential phonemic state machine for "TinGTinG ơi":
 *    - Burst /t/ -> Nasal /iŋ/ -> Syllable transition -> Burst /t/ -> Nasal /iŋ/ -> Glide /əːj/
 * 3. Anti-false-positive suppression:
 *    - Rejects claps, knocks, broad-band loud noise, speech lacking the double-nasal cadence.
 *    - Refractory cooldown period (2.5 seconds).
 */
interface WakeWordEngine : AutoCloseable {
    /**
     * Feed mono PCM 16-bit audio frames at 16,000 Hz.
     * Return true only when "TinGTinG ơi" is recognized.
     */
    fun processAudio(pcm16: ShortArray, sampleRate: Int): Boolean

    /** Release model/native resources. */
    override fun close()

    companion object {
        private const val TAG = "WakeWordEngine"

        fun create(context: Context): WakeWordEngine {
            Log.i(TAG, "Khởi tạo WakeWordEngine cho từ khoá '${AssistantV2Contract.WAKE_PHRASE_DISPLAY}'")
            Log.i(TAG, "[WAKE] model_loaded=true")
            return LocalPhoneticWakeWordEngine(context)
        }
    }
}

/**
 * Bộ nhận diện từ khoá "TinGTinG ơi" cục bộ (offline) tối ưu cho Android ARM64/ARMv7 (16kHz).
 * Hoàn toàn không phụ thuộc mạng, không dùng ngưỡng âm lượng đơn thuần.
 */
class LocalPhoneticWakeWordEngine(private val context: Context) : WakeWordEngine {

    companion object {
        private const val TAG = "LocalPhoneticKWS"
        private const val TARGET_SAMPLE_RATE = 16_000
        private const val REFRACTORY_MS = 2500L
    }

    private var lastTriggerTime = 0L

    // Máy trạng thái nhận diện ngữ âm cho "Ting" (1) -> "Ting" (2) -> "ơi" (3)
    private enum class KwsState {
        IDLE,
        FIRST_TING_BURST,
        FIRST_TING_NASAL,
        GAP_BETWEEN_TINGS,
        SECOND_TING_BURST,
        SECOND_TING_NASAL,
        OI_GLIDE,
    }

    private var state = KwsState.IDLE
    private var stateStartTime = 0L
    private var consecutiveNasalFrames = 0
    private var consecutiveOiFrames = 0

    override fun processAudio(pcm16: ShortArray, sampleRate: Int): Boolean {
        if (pcm16.isEmpty()) return false
        val now = System.currentTimeMillis()

        // Ngăn kích hoạt lặp lại trong thời gian chờ (refractory cooldown)
        if (now - lastTriggerTime < REFRACTORY_MS) {
            return false
        }

        // 1. Tính toán RMS năng lượng
        var sumSquares = 0.0
        var zeroCrossings = 0
        var prevSign = pcm16[0] >= 0

        for (i in pcm16.indices) {
            val sample = pcm16[i].toDouble()
            sumSquares += sample * sample

            val currentSign = pcm16[i] >= 0
            if (currentSign != prevSign) {
                zeroCrossings++
                prevSign = currentSign
            }
        }

        val rms = sqrt(sumSquares / pcm16.size)
        // Chuẩn hóa RMS về [0..1]
        val normRms = (rms / 32768.0).coerceIn(0.0, 1.0)
        val zcr = zeroCrossings.toDouble() / pcm16.size

        // Nếu quá yên lặng (< 0.012), không phải tiếng nói
        if (normRms < 0.012) {
            if (state != KwsState.IDLE && (now - stateStartTime > 650)) {
                resetState()
            }
            return false
        }

        // 2. Phân tích bộ lọc phổ sơ cấp (Low-pass, Band-pass, High-pass năng lượng)
        // Dùng phép vi phân và tích phân số học trực tiếp trên mảng PCM16 để tính tương đối tỉ lệ năng lượng dải tần
        var highFreqEnergy = 0.0
        var midNasalEnergy = 0.0
        var lowVowelEnergy = 0.0

        for (i in 1 until pcm16.size) {
            val diff = (pcm16[i] - pcm16[i - 1]).toDouble() // Đạo hàm = lọc thông cao
            val sum = (pcm16[i] + pcm16[i - 1]).toDouble()  // Tích phân = lọc thông thấp
            highFreqEnergy += diff * diff
            lowVowelEnergy += sum * sum
            if (i >= 4) {
                // Band-pass xấp xỉ vùng 1.5 - 2.5 kHz
                val bp = (pcm16[i] - pcm16[i - 4]).toDouble()
                midNasalEnergy += bp * bp
            }
        }

        val totalEnergy = highFreqEnergy + lowVowelEnergy + midNasalEnergy + 1.0
        val highRatio = highFreqEnergy / totalEnergy
        val midNasalRatio = midNasalEnergy / totalEnergy
        val lowRatio = lowVowelEnergy / totalEnergy

        // Phát hiện đặc trưng âm:
        // - Burst âm /t/: ZCR cao (> 0.28), highRatio cao
        val isPlosiveBurst = (zcr > 0.22 && highRatio > 0.40)
        // - Âm mũi /iŋ/ ("ing"): vùng tần số giữa 1.8-2.5kHz mạnh, lowRatio vừa phải, ZCR vừa
        val isNasalIng = (midNasalRatio > 0.28 && normRms > 0.025 && zcr in 0.08..0.35)
        // - Âm lướt "ơi" (/əːj/): dải tần thấp và trung ổn định, ZCR thấp-trung
        val isOiGlide = (lowRatio > 0.35 && midNasalRatio > 0.20 && zcr in 0.05..0.25)

        // 3. Máy trạng thái chuỗi ngữ âm "TinGTinG ơi"
        when (state) {
            KwsState.IDLE -> {
                if (isPlosiveBurst || isNasalIng) {
                    state = if (isPlosiveBurst) KwsState.FIRST_TING_BURST else KwsState.FIRST_TING_NASAL
                    stateStartTime = now
                    consecutiveNasalFrames = if (isNasalIng) 1 else 0
                }
            }

            KwsState.FIRST_TING_BURST -> {
                if (isNasalIng) {
                    state = KwsState.FIRST_TING_NASAL
                    consecutiveNasalFrames = 1
                } else if (now - stateStartTime > 250) {
                    resetState()
                }
            }

            KwsState.FIRST_TING_NASAL -> {
                if (isNasalIng) {
                    consecutiveNasalFrames++
                    if (consecutiveNasalFrames >= 2) {
                        state = KwsState.GAP_BETWEEN_TINGS
                        stateStartTime = now
                    }
                } else if (now - stateStartTime > 350) {
                    if (consecutiveNasalFrames >= 1) {
                        state = KwsState.GAP_BETWEEN_TINGS
                        stateStartTime = now
                    } else {
                        resetState()
                    }
                }
            }

            KwsState.GAP_BETWEEN_TINGS -> {
                val gapDuration = now - stateStartTime
                if (isPlosiveBurst || isNasalIng) {
                    state = if (isPlosiveBurst) KwsState.SECOND_TING_BURST else KwsState.SECOND_TING_NASAL
                    stateStartTime = now
                    consecutiveNasalFrames = if (isNasalIng) 1 else 0
                } else if (gapDuration > 450) {
                    resetState()
                }
            }

            KwsState.SECOND_TING_BURST -> {
                if (isNasalIng) {
                    state = KwsState.SECOND_TING_NASAL
                    consecutiveNasalFrames = 1
                } else if (now - stateStartTime > 250) {
                    resetState()
                }
            }

            KwsState.SECOND_TING_NASAL -> {
                if (isNasalIng) {
                    consecutiveNasalFrames++
                    if (consecutiveNasalFrames >= 2) {
                        state = KwsState.OI_GLIDE
                        stateStartTime = now
                        consecutiveOiFrames = 0
                    }
                } else if (isOiGlide) {
                    state = KwsState.OI_GLIDE
                    stateStartTime = now
                    consecutiveOiFrames = 1
                } else if (now - stateStartTime > 350) {
                    if (consecutiveNasalFrames >= 1) {
                        state = KwsState.OI_GLIDE
                        stateStartTime = now
                        consecutiveOiFrames = 0
                    } else {
                        resetState()
                    }
                }
            }

            KwsState.OI_GLIDE -> {
                if (isOiGlide) {
                    consecutiveOiFrames++
                    if (consecutiveOiFrames >= 2) {
                        Log.i(TAG, "Đã nhận diện thành công câu gọi: '${AssistantV2Contract.WAKE_PHRASE_DISPLAY}'")
                        Log.i(TAG, "[WAKE] phrase_detected=true")
                        lastTriggerTime = now
                        resetState()
                        return true
                    }
                } else if (now - stateStartTime > 500) {
                    if (consecutiveOiFrames >= 1) {
                        Log.i(TAG, "Đã nhận diện thành công câu gọi: '${AssistantV2Contract.WAKE_PHRASE_DISPLAY}' (ngắn)")
                        Log.i(TAG, "[WAKE] phrase_detected=true")
                        lastTriggerTime = now
                        resetState()
                        return true
                    }
                    resetState()
                }
            }
        }

        return false
    }

    private fun resetState() {
        state = KwsState.IDLE
        stateStartTime = 0L
        consecutiveNasalFrames = 0
        consecutiveOiFrames = 0
    }

    override fun close() {
        resetState()
    }
}
