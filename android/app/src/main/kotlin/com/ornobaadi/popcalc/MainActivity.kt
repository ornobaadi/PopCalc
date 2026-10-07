package com.ornobaadi.popcalc

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val vibrator: Vibrator? by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "popcalc/haptics")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "play" -> {
                        @Suppress("UNCHECKED_CAST")
                        val hits = call.argument<List<Map<String, Any>>>("hits") ?: emptyList()
                        val strength = (call.argument<Double>("strength") ?: 1.0).coerceIn(0.0, 1.0)
                        result.success(play(hits.map { Hit.from(it) }, strength))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** One haptic primitive; [delayMs] is the gap before it starts. */
    private data class Hit(val primitive: String, val scale: Double, val delayMs: Int) {
        companion object {
            fun from(m: Map<String, Any>) = Hit(
                m["p"] as String,
                (m["s"] as Number).toDouble(),
                (m["d"] as Number).toInt(),
            )
        }
    }

    /** Returns false when the device can't vibrate, so Dart can fall back. */
    private fun play(hits: List<Hit>, strength: Double): Boolean {
        val v = vibrator ?: return false
        if (!v.hasVibrator() || hits.isEmpty() || strength <= 0.0) return false

        // Best: rich composed primitives (Android 11+ with a capable motor).
        // A primitive the motor lacks is swapped for its nearest supported
        // cousin, so one missing effect doesn't drop the whole pattern to
        // the plainer waveform.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val ids = hits.map { supportedPrimitive(v, it.primitive) }
            if (ids.all { it != null }) {
                val composition = VibrationEffect.startComposition()
                hits.forEachIndexed { i, hit ->
                    composition.addPrimitive(
                        ids[i]!!,
                        boost(hit.scale * strength).toFloat(),
                        hit.delayMs,
                    )
                }
                v.vibrate(composition.compose())
                return true
            }
        }

        // Fallback: a waveform of short, amplitude-scaled pulses.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val timings = mutableListOf<Long>()
            val amplitudes = mutableListOf<Int>()
            hits.forEach { hit ->
                val (ms, amp) = pulseFor(hit.primitive)
                timings += hit.delayMs.toLong(); amplitudes += 0
                // Below ~60 many budget motors never spin up at all.
                timings += ms; amplitudes += (amp * boost(hit.scale * strength)).toInt().coerceIn(60, 255)
            }
            v.vibrate(VibrationEffect.createWaveform(timings.toLongArray(), amplitudes.toIntArray(), -1))
            return true
        }

        @Suppress("DEPRECATION")
        v.vibrate((hits.sumOf { pulseFor(it.primitive).first + it.delayMs }).coerceAtMost(300L))
        return true
    }

    /**
     * Lifts soft and mid intensities so weaker motors still read them;
     * full strength is unchanged (0.3 -> 0.42, 0.6 -> 0.73, 1.0 -> 1.0).
     */
    private fun boost(x: Double): Double =
        (Math.pow(x.coerceIn(0.0, 1.0), 0.8) * 1.1).coerceIn(0.0, 1.0)

    /** [name]'s primitive id, or a supported stand-in, or null. */
    private fun supportedPrimitive(v: Vibrator, name: String): Int? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        val candidates = when (name) {
            "thud" -> listOf("thud", "click")
            "lowTick" -> listOf("lowTick", "tick", "click")
            "spin" -> listOf("spin", "quickRise", "click")
            "slowRise" -> listOf("slowRise", "quickRise", "click")
            "quickRise" -> listOf("quickRise", "click")
            "quickFall" -> listOf("quickFall", "click")
            "tick" -> listOf("tick", "click")
            else -> listOf(name)
        }
        for (candidate in candidates) {
            val id = primitiveId(candidate) ?: continue
            if (v.areAllPrimitivesSupported(id)) return id
        }
        return null
    }

    private fun primitiveId(name: String): Int? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        return when (name) {
            "click" -> VibrationEffect.Composition.PRIMITIVE_CLICK
            "tick" -> VibrationEffect.Composition.PRIMITIVE_TICK
            "quickRise" -> VibrationEffect.Composition.PRIMITIVE_QUICK_RISE
            "slowRise" -> VibrationEffect.Composition.PRIMITIVE_SLOW_RISE
            "quickFall" -> VibrationEffect.Composition.PRIMITIVE_QUICK_FALL
            "thud" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                VibrationEffect.Composition.PRIMITIVE_THUD else null
            "lowTick" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                VibrationEffect.Composition.PRIMITIVE_LOW_TICK else null
            "spin" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                VibrationEffect.Composition.PRIMITIVE_SPIN else null
            else -> null
        }
    }

    /** Duration (ms) and max amplitude used when primitives aren't available. */
    private fun pulseFor(name: String): Pair<Long, Int> = when (name) {
        // Long enough for slow-to-start motors to actually move.
        "click" -> 20L to 240
        "tick" -> 12L to 190
        "lowTick" -> 16L to 165
        "thud" -> 40L to 255
        "quickRise" -> 45L to 200
        "slowRise" -> 80L to 180
        "quickFall" -> 35L to 200
        "spin" -> 60L to 210
        else -> 16L to 210
    }
}
