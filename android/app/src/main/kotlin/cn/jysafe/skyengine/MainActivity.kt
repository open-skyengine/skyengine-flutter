package cn.jysafe.skyengine

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.res.AssetManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.provider.Settings
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import android.view.KeyEvent
import android.view.OrientationEventListener
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.core.content.pm.PackageInfoCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.security.MessageDigest
import java.util.zip.ZipInputStream

class MainActivity : FlutterActivity() {
    private var mrpOpenChannel: MethodChannel? = null
    private var hardwareKeysChannel: MethodChannel? = null
    private var debugKeysChannel: MethodChannel? = null
    private var screenOrientationChannel: MethodChannel? = null
    private var vmrpLandscape = false
    private var landscapeOrientationListener: OrientationEventListener? = null
    private var appliedVmrpOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
    private var initialMrpRequest: ImportedMrp? = null
    private var pendingInstallApk: File? = null
    private var pendingUpdateDownloadResult: MethodChannel.Result? = null
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null
    private var updateDownloadReceiverRegistered = false
    private var activityResumed = false
    private var hardwareKeyCaptureEnabled = false
    private var debugKeyCaptureEnabled = false
    private val pressedHardwareKeys = mutableMapOf<Int, Int>()
    private val updateDownloadReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != UpdateDownloadService.ACTION_DOWNLOAD_RESULT) return
            val result = pendingUpdateDownloadResult ?: return
            pendingUpdateDownloadResult = null
            val path = intent.getStringExtra(UpdateDownloadService.EXTRA_RESULT_PATH)
            val error = intent.getStringExtra(UpdateDownloadService.EXTRA_RESULT_ERROR)
            if (!path.isNullOrBlank() && error.isNullOrBlank()) {
                result.success(mapOf("path" to path))
            } else {
                result.error(
                    ERROR_UPDATE_DOWNLOAD_FAILED,
                    error ?: getString(R.string.update_download_failed),
                    null,
                )
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        if (!updateDownloadReceiverRegistered) {
            ContextCompat.registerReceiver(
                this,
                updateDownloadReceiver,
                IntentFilter(UpdateDownloadService.ACTION_DOWNLOAD_RESULT),
                ContextCompat.RECEIVER_NOT_EXPORTED,
            )
            updateDownloadReceiverRegistered = true
        }
        captureUpdateInstallIntent(intent)

        initialMrpRequest = initialMrpRequest ?: importMrpFromIntent(intent)
        mrpOpenChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MRP_OPEN_CHANNEL)
        mrpOpenChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                METHOD_GET_INITIAL_MRP -> result.success(initialMrpRequest?.toFlutterMap())
                else -> result.notImplemented()
            }
        }

        hardwareKeysChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            HARDWARE_KEYS_CHANNEL,
        )
        hardwareKeysChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                METHOD_SET_HARDWARE_KEYS_ENABLED -> {
                    hardwareKeyCaptureEnabled = call.arguments as? Boolean ?: false
                    if (!hardwareKeyCaptureEnabled) {
                        pressedHardwareKeys.clear()
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        debugKeysChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEBUG_KEYS_CHANNEL,
        )
        debugKeysChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                METHOD_SET_DEBUG_KEYS_ENABLED -> {
                    debugKeyCaptureEnabled = call.arguments as? Boolean ?: false
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        screenOrientationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SCREEN_ORIENTATION_CHANNEL,
        )
        screenOrientationChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                METHOD_SET_VMRP_ROTATION -> {
                    val arguments = call.arguments as? Map<*, *>
                    val rotation = (arguments?.get("rotation") as? Number)?.toInt()
                    val landscape = arguments?.get("landscape") as? Boolean
                    if (rotation == null || rotation !in 0..3) {
                        result.error(
                            ERROR_BAD_ARGUMENTS,
                            "VMRP rotation must be between 0 and 3",
                            call.arguments,
                        )
                        return@setMethodCallHandler
                    }
                    val effectiveLandscape =
                        (landscape ?: false) || rotation % 2 == 1
                    setVmrpScreenRotation(rotation, effectiveLandscape)
                    result.success(null)
                }
                METHOD_CLEAR_VMRP_ROTATION -> {
                    clearVmrpScreenRotation()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

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
                    METHOD_VIBRATE -> {
                        val durationMs = (call.arguments as? Number)?.toLong()
                        if (durationMs == null || durationMs <= 0L) {
                            result.error(
                                ERROR_BAD_ARGUMENTS,
                                "Vibration duration must be positive",
                                call.arguments,
                            )
                            return@setMethodCallHandler
                        }
                        try {
                            vibrate(durationMs)
                            result.success(null)
                        } catch (error: Exception) {
                            result.error(
                                ERROR_VIBRATION_FAILED,
                                error.message ?: error.javaClass.simpleName,
                                error.javaClass.name,
                            )
                        }
                    }
                    METHOD_CANCEL_VIBRATION -> {
                        getVibrator()?.cancel()
                        result.success(null)
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_UPDATE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    METHOD_GET_VERSION_CODE -> {
                        try {
                            result.success(getCurrentVersionCode())
                        } catch (error: Exception) {
                            result.error(
                                ERROR_APP_UPDATE_FAILED,
                                error.message ?: error.javaClass.simpleName,
                                error.javaClass.name,
                            )
                        }
                    }
                    METHOD_INSTALL_APK -> {
                        val path = call.argument<String>(ARG_APK_PATH)
                        if (path.isNullOrBlank()) {
                            result.error(
                                ERROR_BAD_ARGUMENTS,
                                "Missing $ARG_APK_PATH",
                                null,
                            )
                            return@setMethodCallHandler
                        }

                        try {
                            result.success(installApk(File(path)))
                        } catch (error: InstallPermissionRequiredException) {
                            result.error(
                                ERROR_INSTALL_PERMISSION_REQUIRED,
                                error.message ?: error.javaClass.simpleName,
                                error.javaClass.name,
                            )
                        } catch (error: Exception) {
                            result.error(
                                ERROR_APP_UPDATE_FAILED,
                                error.message ?: error.javaClass.simpleName,
                                error.javaClass.name,
                            )
                        }
                    }
                    METHOD_DOWNLOAD_UPDATE_IN_BACKGROUND -> {
                        val url = call.argument<String>(ARG_DOWNLOAD_URL)
                        val destinationPath = call.argument<String>(ARG_DESTINATION_PATH)
                        val rawHeaders = call.argument<Map<*, *>>(ARG_HEADERS)
                        val expectedSize =
                            call.argument<Number>(ARG_EXPECTED_SIZE)?.toLong() ?: 0L
                        val checksum = call.argument<String>(ARG_CHECKSUM).orEmpty()
                        if (url.isNullOrBlank() || destinationPath.isNullOrBlank()) {
                            result.error(
                                ERROR_BAD_ARGUMENTS,
                                "Missing $ARG_DOWNLOAD_URL or $ARG_DESTINATION_PATH",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        if (pendingUpdateDownloadResult != null) {
                            result.error(
                                ERROR_UPDATE_DOWNLOAD_IN_PROGRESS,
                                getString(R.string.update_already_downloading),
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        val headers = rawHeaders
                            ?.entries
                            ?.mapNotNull { entry ->
                                val name = entry.key as? String
                                val value = entry.value as? String
                                if (name == null || value == null) null else name to value
                            }
                            ?.toMap()
                            .orEmpty()
                        try {
                            pendingUpdateDownloadResult = result
                            UpdateDownloadService.start(
                                this,
                                url,
                                destinationPath,
                                headers,
                                expectedSize,
                                checksum,
                            )
                        } catch (error: Exception) {
                            pendingUpdateDownloadResult = null
                            showUpdateDownloadFailed(
                                error.message
                                    ?: getString(R.string.background_download_start_failed),
                            )
                            result.error(
                                ERROR_UPDATE_DOWNLOAD_FAILED,
                                error.message ?: error.javaClass.simpleName,
                                error.javaClass.name,
                            )
                        }
                    }
                    METHOD_ENSURE_DOWNLOAD_NOTIFICATION_PERMISSION -> {
                        requestDownloadNotificationPermission(result)
                    }
                    METHOD_OPEN_DOWNLOAD_NOTIFICATION_SETTINGS -> {
                        try {
                            openUpdateNotificationSettings()
                            result.success(null)
                        } catch (error: Exception) {
                            result.error(
                                ERROR_APP_UPDATE_FAILED,
                                error.message ?: error.javaClass.simpleName,
                                error.javaClass.name,
                            )
                        }
                    }
                    METHOD_SHOW_DOWNLOAD_PROGRESS -> {
                        val downloadedBytes = call.argument<Number>(ARG_DOWNLOADED_BYTES)?.toLong()
                        val totalBytes = call.argument<Number>(ARG_TOTAL_BYTES)?.toLong()
                        if (downloadedBytes == null || totalBytes == null) {
                            result.error(
                                ERROR_BAD_ARGUMENTS,
                                "Missing $ARG_DOWNLOADED_BYTES or $ARG_TOTAL_BYTES",
                                null,
                            )
                            return@setMethodCallHandler
                        }

                        showUpdateDownloadProgress(downloadedBytes, totalBytes)
                        result.success(null)
                    }
                    METHOD_SHOW_DOWNLOAD_COMPLETE -> {
                        val path = call.argument<String>(ARG_APK_PATH)
                        if (path.isNullOrBlank()) {
                            result.error(
                                ERROR_BAD_ARGUMENTS,
                                "Missing $ARG_APK_PATH",
                                null,
                            )
                            return@setMethodCallHandler
                        }

                        showUpdateDownloadComplete(File(path))
                        result.success(null)
                    }
                    METHOD_SHOW_DOWNLOAD_FAILED -> {
                        showUpdateDownloadFailed(
                            call.argument<String>(ARG_MESSAGE).orEmpty(),
                        )
                        result.success(null)
                    }
                    METHOD_CANCEL_DOWNLOAD_NOTIFICATION -> {
                        cancelUpdateDownloadNotification()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        if (captureUpdateInstallIntent(intent)) {
            if (activityResumed) {
                resumePendingInstall()
            }
            return
        }

        val mrp = importMrpFromIntent(intent) ?: return
        mrpOpenChannel?.invokeMethod(METHOD_OPEN_MRP, mrp.toFlutterMap())
    }

    override fun onResume() {
        super.onResume()
        activityResumed = true
        if (vmrpLandscape) {
            landscapeOrientationListener?.enable()
        }
        resumePendingInstall()
    }

    override fun onPause() {
        activityResumed = false
        landscapeOrientationListener?.disable()
        super.onPause()
    }

    override fun onDestroy() {
        if (updateDownloadReceiverRegistered) {
            unregisterReceiver(updateDownloadReceiver)
            updateDownloadReceiverRegistered = false
        }
        pendingUpdateDownloadResult = null
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST_CODE) {
            return
        }

        pendingNotificationPermissionResult?.success(downloadNotificationStatus())
        pendingNotificationPermissionResult = null
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val vmrpKeyCode = vmrpKeyCodeForAndroidKey(event)
        if (debugKeyCaptureEnabled) {
            debugKeysChannel?.invokeMethod(
                METHOD_DEBUG_KEY_EVENT,
                debugKeyEventMap(event, vmrpKeyCode),
            )
            return true
        }
        if (hardwareKeyCaptureEnabled && vmrpKeyCode != null) {
            when (event.action) {
                KeyEvent.ACTION_DOWN -> {
                    if (event.repeatCount == 0) {
                        pressedHardwareKeys[event.keyCode] = vmrpKeyCode
                        hardwareKeysChannel?.invokeMethod(METHOD_HARDWARE_KEY_DOWN, vmrpKeyCode)
                    }
                    return true
                }
                KeyEvent.ACTION_UP -> {
                    val pressedKeyCode =
                        pressedHardwareKeys.remove(event.keyCode) ?: vmrpKeyCode
                    hardwareKeysChannel?.invokeMethod(METHOD_HARDWARE_KEY_UP, pressedKeyCode)
                    return true
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        getVibrator()?.cancel()
        mrpOpenChannel?.setMethodCallHandler(null)
        mrpOpenChannel = null
        hardwareKeysChannel?.setMethodCallHandler(null)
        hardwareKeysChannel = null
        debugKeysChannel?.setMethodCallHandler(null)
        debugKeysChannel = null
        screenOrientationChannel?.setMethodCallHandler(null)
        screenOrientationChannel = null
        clearVmrpScreenRotation()
        landscapeOrientationListener = null
        hardwareKeyCaptureEnabled = false
        debugKeyCaptureEnabled = false
        pressedHardwareKeys.clear()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private data class ImportedMrp(
        val path: String,
        val resolution: String?,
    ) {
        fun toFlutterMap(): Map<String, Any?> {
            return mapOf(
                ARG_MRP_PATH to path,
                ARG_RESOLUTION to resolution,
            )
        }
    }

    private fun importMrpFromIntent(intent: Intent?): ImportedMrp? {
        if (intent?.action != Intent.ACTION_VIEW) {
            return null
        }

        val uri = intent.data ?: return null
        return try {
            val path = importMrpUri(uri) ?: return null
            ImportedMrp(path, resolutionFromIntent(intent, uri))
        } catch (error: Exception) {
            Log.w(TAG, "Failed to import MRP from $uri", error)
            null
        }
    }

    private fun resolutionFromIntent(intent: Intent, uri: Uri): String? {
        val value = intent.getStringExtra(ARG_RESOLUTION)
            ?: uri.getQueryParameter(ARG_RESOLUTION)
            ?: return null
        return value
            .trim()
            .takeIf { RESOLUTION_PATTERN.matches(it) }
    }

    private fun importMrpUri(uri: Uri): String? {
        val displayName = displayNameForUri(uri) ?: return null
        if (!displayName.endsWith(MRP_EXTENSION, ignoreCase = true)) {
            Log.w(TAG, "Ignoring non-MRP file: $displayName")
            return null
        }

        val hash = sha256ForUri(uri) ?: return null
        existingMrpPathForHash(hash)?.let { return it }

        val targetDir = File(getExternalFilesDir(null) ?: filesDir, MYTHROAD_DIR_NAME)
        if (!targetDir.exists() && !targetDir.mkdirs()) {
            error("Unable to create ${targetDir.absolutePath}")
        }

        val target = uniqueFile(targetDir, sanitizeFileName(displayName))
        openMrpInputStream(uri)?.use { input ->
            FileOutputStream(target).use { output ->
                input.copyTo(output)
            }
        } ?: return null

        return target.absolutePath
    }

    private fun sha256ForUri(uri: Uri): String? {
        val digest = MessageDigest.getInstance("SHA-256")
        openMrpInputStream(uri)?.use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        } ?: return null
        return digest.digest().joinToString("") { byte ->
            "%02x".format(byte.toInt() and 0xff)
        }
    }

    private fun openMrpInputStream(uri: Uri): InputStream? {
        return when (uri.scheme) {
            "file" -> File(uri.path ?: return null).inputStream()
            "content" -> contentResolver.openInputStream(uri)
            else -> null
        }
    }

    private fun existingMrpPathForHash(hash: String): String? {
        val databaseFile = File(filesDir, LOCAL_MRP_DATABASE_FILE_NAME)
        if (!databaseFile.isFile) return null

        return try {
            SQLiteDatabase.openDatabase(
                databaseFile.absolutePath,
                null,
                SQLiteDatabase.OPEN_READONLY,
            ).use { database ->
                database.query(
                    LOCAL_MRP_TABLE,
                    arrayOf(LOCAL_MRP_PATH_COLUMN),
                    "$LOCAL_MRP_HASH_COLUMN = ?",
                    arrayOf(hash),
                    null,
                    null,
                    null,
                ).use { cursor ->
                    while (cursor.moveToNext()) {
                        val path = cursor.getString(0)
                        if (!path.isNullOrBlank() && File(path).isFile) {
                            return path
                        }
                    }
                }
            }
            null
        } catch (error: Exception) {
            Log.w(TAG, "Failed to query local MRP database", error)
            null
        }
    }

    private fun displayNameForUri(uri: Uri): String? {
        if (uri.scheme == "content") {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (index >= 0) {
                            val name = cursor.getString(index)
                            if (!name.isNullOrBlank()) {
                                return name
                            }
                        }
                    }
                }
        }

        return uri.lastPathSegment
            ?.substringAfterLast('/')
            ?.takeIf { it.isNotBlank() }
    }

    private fun sanitizeFileName(fileName: String): String {
        val sanitized = fileName
            .replace('\\', '_')
            .replace('/', '_')
            .replace(Regex("[\\x00-\\x1F]"), "_")
            .trim()
        return sanitized.takeIf { it.isNotEmpty() } ?: DEFAULT_MRP_FILE_NAME
    }

    private fun uniqueFile(dir: File, fileName: String): File {
        val dotIndex = fileName.lastIndexOf('.')
        val baseName = if (dotIndex > 0) fileName.substring(0, dotIndex) else fileName
        val extension = if (dotIndex >= 0) fileName.substring(dotIndex) else MRP_EXTENSION
        var candidate = File(dir, fileName)
        var index = 1
        while (candidate.exists()) {
            candidate = File(dir, "$baseName-$index$extension")
            index += 1
        }
        return candidate
    }

    private fun getCurrentVersionCode(): Long {
        val info = packageManager.getPackageInfo(packageName, 0)
        return PackageInfoCompat.getLongVersionCode(info)
    }

    private fun captureUpdateInstallIntent(intent: Intent?): Boolean {
        if (intent?.action != UpdateDownloadService.ACTION_INSTALL_UPDATE) {
            return false
        }
        val path = intent.getStringExtra(UpdateDownloadService.EXTRA_RESULT_PATH)
        if (!path.isNullOrBlank()) {
            pendingInstallApk = File(path)
        }
        intent.action = null
        return true
    }

    private fun resumePendingInstall() {
        val apk = pendingInstallApk ?: return
        try {
            installApk(apk)
        } catch (_: InstallPermissionRequiredException) {
            // The settings screen is already open; installation continues on resume.
        } catch (error: Exception) {
            Log.e(TAG, "Failed to resume update installation", error)
            pendingInstallApk = null
        }
    }

    private fun installApk(apk: File): Boolean {
        if (!apk.isFile) {
            error("APK not found: ${apk.absolutePath}")
        }

        if (!activityResumed) {
            pendingInstallApk = apk
            return false
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            pendingInstallApk = apk
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            throw InstallPermissionRequiredException(
                getString(R.string.install_unknown_apps_permission),
            )
        }

        pendingInstallApk = null
        openApkInstaller(apk)
        return true
    }

    private class InstallPermissionRequiredException(message: String) : Exception(message)

    private fun openApkInstaller(apk: File) {
        if (!apk.isFile) {
            error("APK not found: ${apk.absolutePath}")
        }
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            apk,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun showUpdateDownloadProgress(downloadedBytes: Long, totalBytes: Long) {
        if (!canShowUpdateDownloadNotification()) {
            return
        }
        ensureUpdateNotificationChannel()

        val hasTotal = totalBytes > 0
        val progress = if (hasTotal) {
            ((downloadedBytes * 100L) / totalBytes).coerceIn(0L, 100L).toInt()
        } else {
            0
        }
        val text = if (hasTotal) {
            getString(
                R.string.download_progress,
                progress,
                formatBytes(downloadedBytes),
                formatBytes(totalBytes),
            )
        } else {
            getString(R.string.downloaded_bytes, formatBytes(downloadedBytes))
        }
        val notification = updateNotificationBuilder()
            .setContentTitle(getString(R.string.update_downloading))
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setProgress(if (hasTotal) 100 else 0, progress, !hasTotal)
            .build()

        NotificationManagerCompat.from(this).notify(UPDATE_NOTIFICATION_ID, notification)
    }

    private fun showUpdateDownloadComplete(apk: File) {
        if (!canShowUpdateDownloadNotification()) {
            return
        }
        ensureUpdateNotificationChannel()
        val notification = updateNotificationBuilder()
            .setContentTitle(getString(R.string.update_download_complete))
            .setContentText(apk.name)
            .setOngoing(false)
            .setOnlyAlertOnce(false)
            .setProgress(0, 0, false)
            .setAutoCancel(true)
            .build()

        NotificationManagerCompat.from(this).notify(UPDATE_NOTIFICATION_ID, notification)
    }

    private fun showUpdateDownloadFailed(message: String) {
        if (!canShowUpdateDownloadNotification()) {
            return
        }
        ensureUpdateNotificationChannel()
        val text = message.ifBlank { getString(R.string.try_again_later) }
        val notification = updateNotificationBuilder()
            .setContentTitle(getString(R.string.update_download_failed))
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setOngoing(false)
            .setOnlyAlertOnce(false)
            .setProgress(0, 0, false)
            .setAutoCancel(true)
            .build()

        NotificationManagerCompat.from(this).notify(UPDATE_NOTIFICATION_ID, notification)
    }

    private fun cancelUpdateDownloadNotification() {
        NotificationManagerCompat.from(this).cancel(UPDATE_NOTIFICATION_ID)
    }

    private fun updateNotificationBuilder(): NotificationCompat.Builder {
        return NotificationCompat.Builder(this, UPDATE_NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
    }

    private fun ensureUpdateNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            UPDATE_NOTIFICATION_CHANNEL_ID,
            getString(R.string.app_update_channel_name),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = getString(R.string.app_update_channel_description)
        }
        manager.createNotificationChannel(channel)
    }

    private fun requestDownloadNotificationPermission(result: MethodChannel.Result) {
        if (canShowUpdateDownloadNotification()) {
            result.success(downloadNotificationStatus())
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            hasNotificationPermission()
        ) {
            result.success(downloadNotificationStatus())
            return
        }

        pendingNotificationPermissionResult?.success(downloadNotificationStatus())
        pendingNotificationPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE,
        )
    }

    private fun downloadNotificationStatus(): Map<String, Any> {
        if (canShowUpdateDownloadNotification()) {
            return mapOf(
                "canShow" to true,
                "canOpenSettings" to false,
                "message" to "",
            )
        }

        val message = when {
            !hasNotificationPermission() ->
                getString(R.string.notification_permission_disabled)
            !NotificationManagerCompat.from(this).areNotificationsEnabled() ->
                getString(R.string.system_notifications_disabled)
            isUpdateNotificationChannelBlocked() ->
                getString(R.string.update_notifications_disabled)
            else ->
                getString(R.string.notifications_unavailable)
        }

        return mapOf(
            "canShow" to false,
            "canOpenSettings" to true,
            "message" to message,
        )
    }

    private fun openUpdateNotificationSettings() {
        val notificationsEnabled = NotificationManagerCompat.from(this).areNotificationsEnabled()
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            notificationsEnabled &&
            isUpdateNotificationChannelBlocked()
        ) {
            Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                .putExtra(Settings.EXTRA_CHANNEL_ID, UPDATE_NOTIFICATION_CHANNEL_ID)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            appDetailsSettingsIntent()
        }
        startSettingsActivity(intent)
    }

    private fun startSettingsActivity(intent: Intent) {
        try {
            startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (error: ActivityNotFoundException) {
            startActivity(
                appDetailsSettingsIntent().addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }

    private fun appDetailsSettingsIntent(): Intent {
        return Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:$packageName"),
        )
    }

    private fun canShowUpdateDownloadNotification(): Boolean {
        if (!hasNotificationPermission()) {
            return false
        }
        if (!NotificationManagerCompat.from(this).areNotificationsEnabled()) {
            return false
        }
        return !isUpdateNotificationChannelBlocked()
    }

    private fun isUpdateNotificationChannelBlocked(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return false
        }
        val manager = getSystemService(NotificationManager::class.java)
        val channel = manager.getNotificationChannel(UPDATE_NOTIFICATION_CHANNEL_ID)
        return channel?.importance == NotificationManager.IMPORTANCE_NONE
    }

    private fun hasNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true
        }
        return ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
    }

    private fun formatBytes(bytes: Long): String {
        if (bytes < 1024L) {
            return "${bytes.coerceAtLeast(0L)} B"
        }
        val kib = bytes / 1024.0
        if (kib < 1024.0) {
            return String.format("%.1f KB", kib)
        }
        return String.format("%.1f MB", kib / 1024.0)
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

    private fun vibrate(durationMs: Long) {
        val vibrator = getVibrator() ?: return
        if (!vibrator.hasVibrator()) {
            return
        }

        vibrator.cancel()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(
                VibrationEffect.createOneShot(
                    durationMs,
                    VibrationEffect.DEFAULT_AMPLITUDE,
                ),
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(durationMs)
        }
    }

    private fun setVmrpScreenRotation(rotation: Int, landscape: Boolean) {
        vmrpLandscape = landscape
        val targetOrientation = when {
            landscape -> {
                ensureLandscapeOrientationListener()
                if (activityResumed) {
                    landscapeOrientationListener?.enable()
                }
                when (appliedVmrpOrientation) {
                    ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE,
                    ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE ->
                        appliedVmrpOrientation
                    else -> ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                }
            }
            rotation == 2 -> ActivityInfo.SCREEN_ORIENTATION_REVERSE_PORTRAIT
            else -> ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        }
        if (!landscape) {
            landscapeOrientationListener?.disable()
        }
        Log.i(
            TAG,
            "VMRP orientation request: rotation=$rotation, landscape=$landscape, " +
                "target=$targetOrientation",
        )
        applyVmrpOrientation(targetOrientation)
    }

    private fun clearVmrpScreenRotation() {
        vmrpLandscape = false
        landscapeOrientationListener?.disable()
        applyVmrpOrientation(ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED)
    }

    private fun ensureLandscapeOrientationListener() {
        if (landscapeOrientationListener != null) return
        landscapeOrientationListener = object : OrientationEventListener(this) {
            override fun onOrientationChanged(orientation: Int) {
                if (!vmrpLandscape || orientation == ORIENTATION_UNKNOWN) return
                val targetOrientation = when (orientation) {
                    in 45..135 -> ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
                    in 225..315 -> ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                    else -> return
                }
                applyVmrpOrientation(targetOrientation)
            }
        }
    }

    private fun applyVmrpOrientation(orientation: Int) {
        if (appliedVmrpOrientation == orientation) return
        appliedVmrpOrientation = orientation
        requestedOrientation = orientation
        Log.i(TAG, "Applied VMRP Activity orientation: $orientation")
    }

    private fun getVibrator(): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    private fun vmrpKeyCodeForAndroidKey(event: KeyEvent): Int? {
        val unicodeChar = event.unicodeChar
        if (unicodeChar in '0'.code..'9'.code) {
            return unicodeChar - '0'.code
        }
        if (unicodeChar == '*'.code) {
            return VMRP_KEY_STAR
        }
        if (unicodeChar == '#'.code) {
            return VMRP_KEY_POUND
        }

        return when (event.keyCode) {
            KeyEvent.KEYCODE_0, KeyEvent.KEYCODE_NUMPAD_0 -> VMRP_KEY_0
            KeyEvent.KEYCODE_1, KeyEvent.KEYCODE_NUMPAD_1 -> VMRP_KEY_1
            KeyEvent.KEYCODE_2, KeyEvent.KEYCODE_NUMPAD_2 -> VMRP_KEY_2
            KeyEvent.KEYCODE_3, KeyEvent.KEYCODE_NUMPAD_3 -> VMRP_KEY_3
            KeyEvent.KEYCODE_4, KeyEvent.KEYCODE_NUMPAD_4 -> VMRP_KEY_4
            KeyEvent.KEYCODE_5, KeyEvent.KEYCODE_NUMPAD_5 -> VMRP_KEY_5
            KeyEvent.KEYCODE_6, KeyEvent.KEYCODE_NUMPAD_6 -> VMRP_KEY_6
            KeyEvent.KEYCODE_7, KeyEvent.KEYCODE_NUMPAD_7 -> VMRP_KEY_7
            KeyEvent.KEYCODE_8, KeyEvent.KEYCODE_NUMPAD_8 -> VMRP_KEY_8
            KeyEvent.KEYCODE_9, KeyEvent.KEYCODE_NUMPAD_9 -> VMRP_KEY_9
            KeyEvent.KEYCODE_STAR, KeyEvent.KEYCODE_NUMPAD_MULTIPLY -> VMRP_KEY_STAR
            KeyEvent.KEYCODE_POUND -> VMRP_KEY_POUND
            KeyEvent.KEYCODE_SOFT_LEFT, KeyEvent.KEYCODE_MENU -> VMRP_KEY_SOFT_LEFT
            KeyEvent.KEYCODE_SOFT_RIGHT, KeyEvent.KEYCODE_BACK -> VMRP_KEY_SOFT_RIGHT
            else -> null
        }
    }

    private fun debugKeyEventMap(event: KeyEvent, vmrpKeyCode: Int?): Map<String, Any?> {
        return mapOf(
            "action" to event.action,
            "actionName" to keyActionName(event.action),
            "keyCode" to event.keyCode,
            "keyCodeName" to KeyEvent.keyCodeToString(event.keyCode),
            "scanCode" to event.scanCode,
            "repeatCount" to event.repeatCount,
            "metaState" to event.metaState,
            "metaStateName" to metaStateName(event.metaState),
            "unicodeChar" to event.unicodeChar,
            "deviceId" to event.deviceId,
            "source" to event.source,
            "flags" to event.flags,
            "vmrpKeyCode" to vmrpKeyCode,
            "vmrpKeyName" to vmrpKeyName(vmrpKeyCode),
        )
    }

    private fun keyActionName(action: Int): String {
        return when (action) {
            KeyEvent.ACTION_DOWN -> "down"
            KeyEvent.ACTION_UP -> "up"
            else -> "unknown"
        }
    }

    private fun metaStateName(metaState: Int): String {
        if (metaState == 0) {
            return "none"
        }
        val names = mutableListOf<String>()
        if (metaState and KeyEvent.META_SHIFT_ON != 0) names.add("shift")
        if (metaState and KeyEvent.META_ALT_ON != 0) names.add("alt")
        if (metaState and KeyEvent.META_CTRL_ON != 0) names.add("ctrl")
        if (metaState and KeyEvent.META_META_ON != 0) names.add("meta")
        if (metaState and KeyEvent.META_SYM_ON != 0) names.add("sym")
        if (metaState and KeyEvent.META_CAPS_LOCK_ON != 0) names.add("capsLock")
        if (metaState and KeyEvent.META_NUM_LOCK_ON != 0) names.add("numLock")
        if (metaState and KeyEvent.META_SCROLL_LOCK_ON != 0) names.add("scrollLock")
        if (names.isEmpty()) {
            return metaState.toString()
        }
        return names.joinToString("+")
    }

    private fun vmrpKeyName(keyCode: Int?): String? {
        return when (keyCode) {
            VMRP_KEY_0 -> "0"
            VMRP_KEY_1 -> "1"
            VMRP_KEY_2 -> "2"
            VMRP_KEY_3 -> "3"
            VMRP_KEY_4 -> "4"
            VMRP_KEY_5 -> "5"
            VMRP_KEY_6 -> "6"
            VMRP_KEY_7 -> "7"
            VMRP_KEY_8 -> "8"
            VMRP_KEY_9 -> "9"
            VMRP_KEY_STAR -> "*"
            VMRP_KEY_POUND -> "#"
            VMRP_KEY_SOFT_LEFT -> "softLeft"
            VMRP_KEY_SOFT_RIGHT -> "softRight"
            else -> null
        }
    }

    private companion object {
        const val HAPTICS_CHANNEL = "skyengine/haptics"
        const val METHOD_VIRTUAL_KEY_VIBRATE = "virtualKeyVibrate"
        const val METHOD_VIBRATE = "vibrate"
        const val METHOD_CANCEL_VIBRATION = "cancelVibration"
        const val ERROR_VIBRATION_FAILED = "VIBRATION_FAILED"
        const val HARDWARE_KEYS_CHANNEL = "skyengine/hardware_keys"
        const val METHOD_SET_HARDWARE_KEYS_ENABLED = "setEnabled"
        const val METHOD_HARDWARE_KEY_DOWN = "keyDown"
        const val METHOD_HARDWARE_KEY_UP = "keyUp"
        const val DEBUG_KEYS_CHANNEL = "skyengine/debug_keys"
        const val METHOD_SET_DEBUG_KEYS_ENABLED = "setEnabled"
        const val METHOD_DEBUG_KEY_EVENT = "keyEvent"
        const val SCREEN_ORIENTATION_CHANNEL = "skyengine/screen_orientation"
        const val METHOD_SET_VMRP_ROTATION = "setVmrpRotation"
        const val METHOD_CLEAR_VMRP_ROTATION = "clearVmrpRotation"
        const val APP_UPDATE_CHANNEL = "skyengine/app_update"
        const val METHOD_GET_VERSION_CODE = "getVersionCode"
        const val METHOD_INSTALL_APK = "installApk"
        const val METHOD_DOWNLOAD_UPDATE_IN_BACKGROUND = "downloadUpdateInBackground"
        const val METHOD_ENSURE_DOWNLOAD_NOTIFICATION_PERMISSION =
            "ensureDownloadNotificationPermission"
        const val METHOD_OPEN_DOWNLOAD_NOTIFICATION_SETTINGS =
            "openDownloadNotificationSettings"
        const val METHOD_SHOW_DOWNLOAD_PROGRESS = "showDownloadProgress"
        const val METHOD_SHOW_DOWNLOAD_COMPLETE = "showDownloadComplete"
        const val METHOD_SHOW_DOWNLOAD_FAILED = "showDownloadFailed"
        const val METHOD_CANCEL_DOWNLOAD_NOTIFICATION = "cancelDownloadNotification"
        const val ARG_APK_PATH = "path"
        const val ARG_DOWNLOAD_URL = "url"
        const val ARG_DESTINATION_PATH = "destinationPath"
        const val ARG_HEADERS = "headers"
        const val ARG_EXPECTED_SIZE = "expectedSize"
        const val ARG_CHECKSUM = "checksum"
        const val ARG_DOWNLOADED_BYTES = "downloadedBytes"
        const val ARG_TOTAL_BYTES = "totalBytes"
        const val ARG_MESSAGE = "message"
        const val ERROR_APP_UPDATE_FAILED = "APP_UPDATE_FAILED"
        const val ERROR_INSTALL_PERMISSION_REQUIRED = "INSTALL_PERMISSION_REQUIRED"
        const val ERROR_UPDATE_DOWNLOAD_FAILED = "UPDATE_DOWNLOAD_FAILED"
        const val ERROR_UPDATE_DOWNLOAD_IN_PROGRESS = "UPDATE_DOWNLOAD_IN_PROGRESS"
        const val UPDATE_NOTIFICATION_CHANNEL_ID = "app_update"
        const val UPDATE_NOTIFICATION_ID = 1001
        const val NOTIFICATION_PERMISSION_REQUEST_CODE = 2001
        const val MRP_OPEN_CHANNEL = "skyengine/mrp_open"
        const val METHOD_GET_INITIAL_MRP = "getInitialMrp"
        const val METHOD_OPEN_MRP = "openMrp"
        const val ARG_MRP_PATH = "path"
        const val ARG_RESOLUTION = "resolution"
        const val MYTHROAD_ASSETS_CHANNEL = "skyengine/mythroad_assets"
        const val METHOD_ENSURE_SYSTEM = "ensureSystem"
        const val ARG_MYTHROAD_DIR = "mythroadDir"
        const val MYTHROAD_SYSTEM_ASSET = "mythroad_system.zip"
        const val MYTHROAD_SYSTEM_DIR_NAME = "system"
        const val MYTHROAD_DIR_NAME = "mythroad"
        const val MRP_EXTENSION = ".mrp"
        const val DEFAULT_MRP_FILE_NAME = "imported.mrp"
        const val LOCAL_MRP_DATABASE_FILE_NAME = "local_mrp.db"
        const val LOCAL_MRP_TABLE = "local_mrp_files"
        const val LOCAL_MRP_PATH_COLUMN = "path"
        const val LOCAL_MRP_HASH_COLUMN = "hash"
        val RESOLUTION_PATTERN = Regex("""^\d{2,5}\s*[xX]\s*\d{2,5}$""")
        const val ERROR_BAD_ARGUMENTS = "BAD_ARGUMENTS"
        const val ERROR_MYTHROAD_SYSTEM_FAILED = "MYTHROAD_SYSTEM_FAILED"
        const val VIRTUAL_KEY_VIBRATION_MS = 18L
        const val VIRTUAL_KEY_SILENCE_MS = 1000L
        const val NO_REPEAT = -1
        const val TAG = "SkyEngine"
        const val VMRP_KEY_0 = 0
        const val VMRP_KEY_1 = 1
        const val VMRP_KEY_2 = 2
        const val VMRP_KEY_3 = 3
        const val VMRP_KEY_4 = 4
        const val VMRP_KEY_5 = 5
        const val VMRP_KEY_6 = 6
        const val VMRP_KEY_7 = 7
        const val VMRP_KEY_8 = 8
        const val VMRP_KEY_9 = 9
        const val VMRP_KEY_STAR = 10
        const val VMRP_KEY_POUND = 11
        const val VMRP_KEY_SOFT_LEFT = 17
        const val VMRP_KEY_SOFT_RIGHT = 18
    }
}
