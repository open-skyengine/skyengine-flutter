package com.example.mrpoid

import android.content.res.AssetManager
import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.util.zip.ZipInputStream

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MYTHROAD_ASSETS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    METHOD_ENSURE_SYSTEM -> {
                        val mythroadDir = call.argument<String>(ARG_MYTHROAD_DIR)
                        if (mythroadDir.isNullOrBlank()) {
                            result.error(
                                ERROR_BAD_ARGUMENTS,
                                "Missing $ARG_MYTHROAD_DIR",
                                null,
                            )
                            return@setMethodCallHandler
                        }

                        try {
                            result.success(ensureMythroadSystem(File(mythroadDir)))
                        } catch (error: Exception) {
                            result.error(
                                ERROR_MYTHROAD_SYSTEM_FAILED,
                                error.message ?: error.javaClass.simpleName,
                                error.javaClass.name,
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun ensureMythroadSystem(mythroadDir: File): String {
        val systemDir = File(mythroadDir, MYTHROAD_SYSTEM_DIR_NAME)
        if (isMythroadSystemPresent(mythroadDir)) {
            return systemDir.absolutePath
        }

        if (!mythroadDir.exists() && !mythroadDir.mkdirs()) {
            error("Unable to create ${mythroadDir.absolutePath}")
        }

        unzipAssetSafely(
            assets = assets,
            assetName = MYTHROAD_SYSTEM_ASSET,
            targetRoot = mythroadDir,
        )

        if (!isMythroadSystemPresent(mythroadDir)) {
            error("Missing extracted Mythroad system files in ${systemDir.absolutePath}")
        }
        return systemDir.absolutePath
    }

    private fun isMythroadSystemPresent(mythroadDir: File): Boolean {
        var sawFile = false
        ZipInputStream(
            BufferedInputStream(assets.open(MYTHROAD_SYSTEM_ASSET)),
        ).use { zip ->
            var entry = zip.nextEntry
            while (entry != null) {
                if (!entry.isDirectory) {
                    sawFile = true
                    val file = File(mythroadDir, entry.name)
                    if (!file.isFile) {
                        return false
                    }
                }
                zip.closeEntry()
                entry = zip.nextEntry
            }
        }
        return sawFile
    }

    private fun unzipAssetSafely(
        assets: AssetManager,
        assetName: String,
        targetRoot: File,
    ) {
        val canonicalRoot = targetRoot.canonicalFile
        ZipInputStream(BufferedInputStream(assets.open(assetName))).use { zip ->
            var entry = zip.nextEntry
            while (entry != null) {
                val output = File(canonicalRoot, entry.name).canonicalFile
                if (!isInsideDirectory(canonicalRoot, output)) {
                    error("Refusing to extract outside target directory: ${entry.name}")
                }

                if (entry.isDirectory) {
                    if (!output.exists() && !output.mkdirs()) {
                        error("Unable to create ${output.absolutePath}")
                    }
                } else {
                    val parent = output.parentFile
                    if (parent != null && !parent.exists() && !parent.mkdirs()) {
                        error("Unable to create ${parent.absolutePath}")
                    }
                    FileOutputStream(output).use { out ->
                        zip.copyTo(out)
                    }
                }
                zip.closeEntry()
                entry = zip.nextEntry
            }
        }
    }

    private fun isInsideDirectory(parent: File, child: File): Boolean {
        val parentPath = parent.path
        val childPath = child.path
        return childPath == parentPath || childPath.startsWith(parentPath + File.separator)
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
        const val MYTHROAD_ASSETS_CHANNEL = "mrpoid/mythroad_assets"
        const val METHOD_ENSURE_SYSTEM = "ensureSystem"
        const val ARG_MYTHROAD_DIR = "mythroadDir"
        const val MYTHROAD_SYSTEM_ASSET = "mythroad_system.zip"
        const val MYTHROAD_SYSTEM_DIR_NAME = "system"
        const val ERROR_BAD_ARGUMENTS = "BAD_ARGUMENTS"
        const val ERROR_MYTHROAD_SYSTEM_FAILED = "MYTHROAD_SYSTEM_FAILED"
        const val VIRTUAL_KEY_VIBRATION_MS = 18L
        const val VIRTUAL_KEY_SILENCE_MS = 1000L
        const val NO_REPEAT = -1
    }
}
