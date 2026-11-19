package com.lhht.ai_assistant

import org.junit.Assert.*
import org.junit.Test
import kotlin.math.PI
import kotlin.math.sin

class WakeWordEngineTest {

    @Test
    fun testBiquadFilterFrequencyResponse() {
        // High-pass filter (> 3.0 kHz at 16 kHz)
        val hp = BiquadFilter(
            b0 = 0.41816, b1 = -0.83632, b2 = 0.41816,
            a1 = -0.46294, a2 = 0.20971
        )
        // Band-pass filter (1.6 kHz - 2.6 kHz at 16 kHz)
        val bp = BiquadFilter(
            b0 = 0.16943, b1 = 0.0, b2 = -0.16943,
            a1 = -1.12747, a2 = 0.66114
        )
        // Low-pass filter (< 800 Hz at 16 kHz)
        val lp = BiquadFilter(
            b0 = 0.02008, b1 = 0.04016, b2 = 0.02008,
            a1 = -1.56101, a2 = 0.64135
        )

        val sampleRate = 16000
        val nSamples = 320 // 20ms frame

        // Low frequency tone (300 Hz)
        var lpEnergyLow = 0.0
        var hpEnergyLow = 0.0
        for (i in 0 until nSamples) {
            val sample = sin(2.0 * PI * 300.0 * i / sampleRate) * 10000.0
            val lOut = lp.process(sample)
            val hOut = hp.process(sample)
            lpEnergyLow += lOut * lOut
            hpEnergyLow += hOut * hOut
        }
        // Low-pass output must be significantly higher than high-pass output for 300Hz
        assertTrue("LP filter should pass 300Hz better than HP", lpEnergyLow > hpEnergyLow * 5)

        // High frequency tone (4000 Hz)
        hp.reset()
        lp.reset()
        var lpHighenergy = 0.0
        var hpHighenergy = 0.0
        for (i in 0 until nSamples) {
            val sample = sin(2.0 * PI * 4000.0 * i / sampleRate) * 10000.0
            val lOut = lp.process(sample)
            val hOut = hp.process(sample)
            lpHighenergy += lOut * lOut
            hpHighenergy += hOut * hOut
        }
        // High-pass output must be significantly higher than low-pass output for 4000Hz
        assertTrue("HP filter should pass 4000Hz better than LP", hpHighenergy > lpHighenergy * 5)

        // Mid frequency tone (2100 Hz resonant nasal)
        bp.reset()
        var bpMidEnergy = 0.0
        for (i in 0 until nSamples) {
            val sample = sin(2.0 * PI * 2100.0 * i / sampleRate) * 10000.0
            val bOut = bp.process(sample)
            bpMidEnergy += bOut * bOut
        }
        assertTrue("BP filter should resonate at 2100Hz", bpMidEnergy > 1000.0)
    }

    @Test
    fun testSilenceDoesNotTriggerWakeWord() {
        val engine = LocalPhoneticWakeWordEngine()
        val silenceFrame = ShortArray(640) { 0 }

        // Process 50 consecutive silence frames (1 second)
        for (i in 0 until 50) {
            val triggered = engine.processAudio(silenceFrame, 16000)
            assertFalse("Silence must never trigger wake word", triggered)
        }
        engine.close()
    }

    @Test
    fun testLowEnergyWhiteNoiseDoesNotTriggerWakeWord() {
        val engine = LocalPhoneticWakeWordEngine()
        val noiseFrame = ShortArray(640) {
            // Low amplitude random noise (-100 to 100)
            ((-100..100).random()).toShort()
        }

        for (i in 0 until 30) {
            val triggered = engine.processAudio(noiseFrame, 16000)
            assertFalse("Low amplitude noise must never trigger wake word", triggered)
        }
        engine.close()
    }

    @Test
    fun testContinuousNasalWithoutInterSyllableGapDoesNotTrigger() {
        val engine = LocalPhoneticWakeWordEngine()
        val sampleRate = 16000
        val frameSize = 320 // 20ms

        // Synthesize a continuous 2100Hz tone for 1000ms with no gap
        val totalFrames = 50 // 1000ms
        for (f in 0 until totalFrames) {
            val frame = ShortArray(frameSize) { i ->
                val sampleIdx = f * frameSize + i
                (sin(2.0 * PI * 2100.0 * sampleIdx / sampleRate) * 12000.0).toInt().toShort()
            }
            val triggered = engine.processAudio(frame, sampleRate)
            // A continuous un-interrupted tone must not trigger the complete 3-stage keyword "TinGTinG ơi"
            assertFalse("Continuous uninterrupted tone must not trigger", triggered)
        }
        engine.close()
    }
}
