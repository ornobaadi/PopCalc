package com.ornobaadi.popcalc

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.View
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class PopCalcActivity : FlutterActivity() {
    /** Launcher aliases in AndroidManifest.xml; ".MainActivity" is the official icon. */
    private val iconAliases = listOf(
        "MainActivity", "IconAmber", "IconPercent", "IconPlusminus", "IconOperators", "IconKeypad",
        "IconRoot", "IconRuler",
    )

    private val vibrator: Vibrator? by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }

    /**
     * What androidx's EdgeToEdge.enable does, without pulling in androidx
     * (FlutterActivity is not a ComponentActivity). Android 15 forces this
     * for target SDK 35 anyway; doing it ourselves keeps older versions the
     * same and answers Play's edge-to-edge check. The bars' colours stay
     * with Flutter (main.dart makes them transparent), so no deprecated
     * setStatusBarColor/setNavigationBarColor calls here.
     */
    private fun enableEdgeToEdge() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = window.decorView.systemUiVisibility or
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes = window.attributes.apply {
                layoutInDisplayCutoutMode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
                } else {
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                }
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // No grey scrim behind gesture/3-button navigation.
            window.isNavigationBarContrastEnforced = false
            window.isStatusBarContrastEnforced = false
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "popcalc/app_icon")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "set" -> {
                        val alias = call.argument<String>("alias") ?: ""
                        if (alias in iconAliases) pendingIcon = alias
                        result.success(alias in iconAliases)
                    }
                    "current" -> result.success(currentIcon())
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "popcalc/qs_tile")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "request" -> requestTile { result.success(it) }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Asks Android to add the Quick Settings tile (Android 13+ shows its own
     * "Add tile?" card). Answers with StatusBarManager's code: 2 added,
     * 1 already there, 0 declined, negative = failed. Older versions answer
     * [TILE_UNSUPPORTED] so Settings can explain how to add it by hand.
     */
    private fun requestTile(done: (Int) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            done(TILE_UNSUPPORTED)
            return
        }
        try {
            val bar = getSystemService(android.app.StatusBarManager::class.java)
            if (bar == null) {
                done(TILE_UNSUPPORTED)
                return
            }
            bar.requestAddTileService(
                ComponentName(this, PopCalcTileService::class.java),
                "PopCalc",
                android.graphics.drawable.Icon.createWithResource(this, R.drawable.ic_qs_popcalc),
                mainExecutor,
            ) { code -> done(code) }
        } catch (e: Exception) {
            done(TILE_UNSUPPORTED)
        }
    }

    private companion object {
        const val TILE_UNSUPPORTED = -100
    }

    // Alias classes resolve against the namespace, not the app id (debug builds add ".dev").
    /**
     * The icon picked in Settings, switched in [onStop]: changing launcher entries
     * while the app is in front can make some launchers close it, and the new icon
     * is only seen on the home screen anyway.
     */
    private var pendingIcon: String? = null

    override fun onStop() {
        super.onStop()
        pendingIcon?.let { setIcon(it) }
        pendingIcon = null
    }

    private fun component(alias: String) = ComponentName(packageName, "com.ornobaadi.popcalc.$alias")

    private fun isEnabled(alias: String): Boolean =
        when (packageManager.getComponentEnabledSetting(component(alias))) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED -> false
            else -> alias == "MainActivity" // manifest default
        }

    private fun currentIcon(): String = iconAliases.firstOrNull { isEnabled(it) } ?: "MainActivity"

    /**
     * Enables [alias] and disables the rest. The chosen one goes on first so the app
     * never has zero launcher entries; nothing happens if it is already the one shown.
     */
    private fun setIcon(alias: String): Boolean {
        if (alias !in iconAliases) return false
        if (currentIcon() == alias && iconAliases.none { it != alias && isEnabled(it) }) return true
        return try {
            val pm = packageManager
            pm.setComponentEnabledSetting(
                component(alias), PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP,
            )
            for (other in iconAliases) if (other != alias) {
                pm.setComponentEnabledSetting(
                    component(other), PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP,
                )
            }
            true
        } catch (e: Exception) {
            false
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
