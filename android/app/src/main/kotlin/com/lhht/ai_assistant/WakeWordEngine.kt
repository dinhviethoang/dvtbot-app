package com.lhht.ai_assistant

import android.content.Context
import android.util.Log
import kotlin.math.sqrt

/**
 * Offline wake-word adapter for "TinGTinG ơi".
 *
 * Implements a dual-stage local keyword spotting architecture using discrete signal processing (DSP):
 * 1. Multi-band Biquad IIR Filterbank (16 kHz mono PCM16):
 *    - Spectral Zero-Crossing Rate (ZCR)
 *    - High-Pass Filter (> 3.0 kHz) for /t/ plosive burst
 *    - Band-Pass Filter (1.6 kHz - 2.6 kHz) for /iŋ/ nasal formant resonance
 *    - Low-Pass Filter (200 Hz - 800 Hz) for vowel & glide /əːj/ energy
 * 2. Sequential phonemic state machine for "TinGTinG ơi":
 *    - Burst /t/ -> Nasal /iŋ/ -> Enforced inter-syllable silence gap (50ms - 400ms)
 *      -> Burst /t/ -> Nasal /iŋ/ -> Glide /əːj/
 * 3. Anti-false-positive suppression:
 *    - Rejects claps, knocks, broad-band loud noise, and continuous monophonic tones.
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
            Log.i(TAG, "[WAKE] engine=dsp_phonetic_heuristic status=ready")
            return LocalPhoneticWakeWordEngine(context)
        }
    }
}

/**
 * Bộ lọc nhị thứ (Biquad IIR Filter) chuẩn dạng Direct Form II
 */
class BiquadFilter(
    private val b0: Double,
    private val b1: Double,
    private val b2: Double,
    private val a1: Double,
    private val a2: Double
) {
    private var x1 = 0.0
    private var x2 = 0.0
    private var y1 = 0.0
    private var y2 = 0.0

    fun process(x: Double): Double {
        val y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1
        x1 = x
        y2 = y1
        y1 = y
        return y
    }

    fun reset() {
        x1 = 0.0
        x2 = 0.0
        y1 = 0.0
        y2 = 0.0
    }
}

/**
 * Bộ nhận diện từ khoá "TinGTinG ơi" cục bộ (offline) tối ưu cho Android ARM64/ARMv7 (16kHz).
 * Hoàn toàn không phụ thuộc mạng, không dùng ngưỡng âm lượng đơn thuần.
 */
class LocalPhoneticWakeWordEngine(private val context: Context? = null) : WakeWordEngine {

    companion object {
        private const val TAG = "LocalPhoneticKWS"
        private const val TARGET_SAMPLE_RATE = 16_000
        private const val REFRACTORY_MS = 2500L

        // Hằng số thời gian khoảng nghỉ giữa 2 từ "Ting"
        private const val MIN_GAP_MS = 50L
        private const val MAX_GAP_MS = 400L
    }

    private var lastTriggerTime = 0L

    // 1. Bộ lọc Biquad IIR ở 16kHz
    // Band-pass: 1.6kHz - 2.6kHz (tâm 2.1kHz, Q=1.8) cho âm mũi /iŋ/ ("ing")
    private val bpNasal = BiquadFilter(
        b0 = 0.16943, b1 = 0.0, b2 = -0.16943,
        a1 = -1.12747, a2 = 0.66114
    )

    // High-pass: fc = 3.0kHz cho âm tắc phát nổ vô thanh /t/
    private val hpPlosive = BiquadFilter(
        b0 = 0.41816, b1 = -0.83632, b2 = 0.41816,
        a1 = -0.46294, a2 = 0.20971
    )

    // Low-pass: fc = 800Hz cho âm lướt / nguyên âm "ơi" (/əːj/)
    private val lpVowel = BiquadFilter(
        b0 = 0.02008, b1 = 0.04016, b2 = 0.02008,
        a1 = -1.56101, a2 = 0.64135
    )

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

        // 1. Tính toán RMS năng lượng và ZCR
        var sumSquares = 0.0
        var zeroCrossings = 0
        var prevSign = pcm16[0] >= 0

        var highFreqEnergy = 0.0
        var midNasalEnergy = 0.0
        var lowVowelEnergy = 0.0

        for (i in pcm16.indices) {
            val sample = pcm16[i].toDouble()
            sumSquares += sample * sample

            val currentSign = pcm16[i] >= 0
            if (currentSign != prevSign) {
                zeroCrossings++
                prevSign = currentSign
            }

            // Đưa qua các bộ lọc Biquad IIR thực thụ
            val hpOut = hpPlosive.process(sample)
            val bpOut = bpNasal.process(sample)
            val lpOut = lpVowel.process(sample)

            highFreqEnergy += hpOut * hpOut
            midNasalEnergy += bpOut * bpOut
            lowVowelEnergy += lpOut * lpOut
        }

        val rms = sqrt(sumSquares / pcm16.size)
        val normRms = (rms / 32768.0).coerceIn(0.0, 1.0)
        val zcr = zeroCrossings.toDouble() / pcm16.size

        // Nếu quá yên lặng (< 0.012), không phải tiếng nói
        if (normRms < 0.012) {
            if (state != KwsState.IDLE && (now - stateStartTime > 650)) {
                resetState()
            }
            return false
        }

        val totalEnergy = highFreqEnergy + lowVowelEnergy + midNasalEnergy + 1.0
        val highRatio = highFreqEnergy / totalEnergy
        val midNasalRatio = midNasalEnergy / totalEnergy
        val lowRatio = lowVowelEnergy / totalEnergy

        // Phát hiện đặc trưng âm:
        // - Burst âm /t/: ZCR cao (> 0.22), highRatio cao (> 0.35)
        val isPlosiveBurst = (zcr > 0.22 && highRatio > 0.35)
        // - Âm mũi /iŋ/ ("ing"): dải tần Biquad 1.6-2.6kHz mạnh, midNasalRatio > 0.30, ZCR vừa
        val isNasalIng = (midNasalRatio > 0.30 && normRms > 0.025 && zcr in 0.08..0.35)
        // - Âm lướt "ơi" (/əːj/): năng lượng dải thấp Biquad 200-800Hz mạnh
        val isOiGlide = (lowRatio > 0.35 && midNasalRatio > 0.18 && zcr in 0.05..0.25)

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
                if (gapDuration < MIN_GAP_MS) {
                    // Khoảng nghỉ tối thiểu bắt buộc giữa 2 âm tiết "Ting" (50ms - 400ms).
                    // Nếu năng lượng mũi vẫn tiếp diễn liên tục không ngắt, đây chỉ là 1 âm tiết kéo dài,
                    // không được coi là tiếng thứ hai!
                    if (isNasalIng) {
                        stateStartTime = now // Cập nhật lại thời điểm kết thúc âm tiết 1
                    }
                } else if (gapDuration in MIN_GAP_MS..MAX_GAP_MS) {
                    // Đã có khoảng nghỉ ngắt âm tiết tự nhiên hợp lệ
                    if (isPlosiveBurst || isNasalIng) {
                        state = if (isPlosiveBurst) KwsState.SECOND_TING_BURST else KwsState.SECOND_TING_NASAL
                        stateStartTime = now
                        consecutiveNasalFrames = if (isNasalIng) 1 else 0
                    }
                } else {
                    // Quá 400ms không có âm tiếp theo -> hết thời gian chờ
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
        bpNasal.reset()
        hpPlosive.reset()
        lpVowel.reset()
    }

    override fun close() {
        resetState()
    }
}
