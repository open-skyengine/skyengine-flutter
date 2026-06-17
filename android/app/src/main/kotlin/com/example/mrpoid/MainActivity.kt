package com.example.mrpoid

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HAPTICS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    METHOD_VIRTUAL_KEY_VIBRATE -> {
                        try {
                            vibrateVirtualKey()
                            result.success(null)
                        } catch (error: Exception) {
                            result.error(
                                ERROR_VIBRATION_FAILED,
                                error.message ?: error.javaClass.simpleName,
                                error.javaClass.name,
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun vibrateVirtualKey() {
        val vibrator = getVibrator() ?: return
        if (!vibrator.hasVibrator()) {
            return
        }

        // Some devices ignore a direct short pulse. The trailing silent segment
        // keeps the submitted waveform above the device's duration threshold
        // while the user only feels the first non-zero amplitude segment.
        vibrator.cancel()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(
                VibrationEffect.createWaveform(
                    longArrayOf(0L, VIRTUAL_KEY_VIBRATION_MS, VIRTUAL_KEY_SILENCE_MS),
                    intArrayOf(0, VibrationEffect.DEFAULT_AMPLITUDE, 0),
                    NO_REPEAT,
                ),
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(
                longArrayOf(0L, VIRTUAL_KEY_VIBRATION_MS, VIRTUAL_KEY_SILENCE_MS),
                NO_REPEAT,
            )
        }
    }

    private fun getVibrator(): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    private companion object {
        const val HAPTICS_CHANNEL = "mrpoid/haptics"
        const val METHOD_VIRTUAL_KEY_VIBRATE = "virtualKeyVibrate"
        const val ERROR_VIBRATION_FAILED = "VIBRATION_FAILED"
        const val VIRTUAL_KEY_VIBRATION_MS = 18L
        const val VIRTUAL_KEY_SILENCE_MS = 1000L
        const val NO_REPEAT = -1
    }
}
