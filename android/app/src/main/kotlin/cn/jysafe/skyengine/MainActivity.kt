package cn.jysafe.skyengine

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.res.AssetManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.provider.Settings
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
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
import java.util.zip.ZipInputStream

class MainActivity : FlutterActivity() {
    private var mrpOpenChannel: MethodChannel? = null
    private var initialMrpPath: String? = null
    private var pendingInstallApk: File? = null
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        initialMrpPath = initialMrpPath ?: importMrpFromIntent(intent)
        mrpOpenChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MRP_OPEN_CHANNEL)
        mrpOpenChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                METHOD_GET_INITIAL_MRP -> result.success(initialMrpPath)
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
                            installApk(File(path))
                            result.success(null)
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
                    METHOD_ENSURE_DOWNLOAD_NOTIFICATION_PERMISSION -> {
                        requestDownloadNotificationPermission(result)
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

        val mrpPath = importMrpFromIntent(intent) ?: return
        mrpOpenChannel?.invokeMethod(METHOD_OPEN_MRP, mrpPath)
    }

    override fun onResume() {
        super.onResume()
        val apk = pendingInstallApk ?: return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()
        ) {
            pendingInstallApk = null
            openApkInstaller(apk)
        }
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

        pendingNotificationPermissionResult?.success(canShowUpdateDownloadNotification())
        pendingNotificationPermissionResult = null
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        mrpOpenChannel?.setMethodCallHandler(null)
        mrpOpenChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun importMrpFromIntent(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_VIEW) {
            return null
        }

        val uri = intent.data ?: return null
        return try {
            importMrpUri(uri)
        } catch (error: Exception) {
            Log.w(TAG, "Failed to import MRP from $uri", error)
            null
        }
    }

    private fun importMrpUri(uri: Uri): String? {
        val displayName = displayNameForUri(uri) ?: return null
        if (!displayName.endsWith(MRP_EXTENSION, ignoreCase = true)) {
            Log.w(TAG, "Ignoring non-MRP file: $displayName")
            return null
        }

        val targetDir = File(getExternalFilesDir(null) ?: filesDir, MYTHROAD_DIR_NAME)
        if (!targetDir.exists() && !targetDir.mkdirs()) {
            error("Unable to create ${targetDir.absolutePath}")
        }

        val target = uniqueFile(targetDir, sanitizeFileName(displayName))
        when (uri.scheme) {
            "file" -> File(uri.path ?: return null).inputStream()
            "content" -> contentResolver.openInputStream(uri)
            else -> null
        }?.use { input ->
            FileOutputStream(target).use { output ->
                input.copyTo(output)
            }
        } ?: return null

        return target.absolutePath
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

    private fun installApk(apk: File) {
        if (!apk.isFile) {
            error("APK not found: ${apk.absolutePath}")
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
                "请允许安装未知来源应用，返回后会自动继续安装",
            )
        }

        openApkInstaller(apk)
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
            "$progress%（${formatBytes(downloadedBytes)} / ${formatBytes(totalBytes)}）"
        } else {
            "已下载 ${formatBytes(downloadedBytes)}"
        }
        val notification = updateNotificationBuilder()
            .setContentTitle("正在下载更新")
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
            .setContentTitle("更新下载完成")
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
        val text = message.ifBlank { "请稍后重试" }
        val notification = updateNotificationBuilder()
            .setContentTitle("更新下载失败")
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
    }

    private fun ensureUpdateNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(UPDATE_NOTIFICATION_CHANNEL_ID) != null) {
            return
        }
        val channel = NotificationChannel(
            UPDATE_NOTIFICATION_CHANNEL_ID,
            "应用更新",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "显示应用更新下载进度"
        }
        manager.createNotificationChannel(channel)
    }

    private fun requestDownloadNotificationPermission(result: MethodChannel.Result) {
        if (canShowUpdateDownloadNotification()) {
            result.success(true)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            hasNotificationPermission()
        ) {
            result.success(false)
            return
        }

        pendingNotificationPermissionResult?.success(false)
        pendingNotificationPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE,
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

    private fun getVibrator(): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    private companion object {
        const val HAPTICS_CHANNEL = "skyengine/haptics"
        const val METHOD_VIRTUAL_KEY_VIBRATE = "virtualKeyVibrate"
        const val ERROR_VIBRATION_FAILED = "VIBRATION_FAILED"
        const val APP_UPDATE_CHANNEL = "skyengine/app_update"
        const val METHOD_GET_VERSION_CODE = "getVersionCode"
        const val METHOD_INSTALL_APK = "installApk"
        const val METHOD_ENSURE_DOWNLOAD_NOTIFICATION_PERMISSION =
            "ensureDownloadNotificationPermission"
        const val METHOD_SHOW_DOWNLOAD_PROGRESS = "showDownloadProgress"
        const val METHOD_SHOW_DOWNLOAD_COMPLETE = "showDownloadComplete"
        const val METHOD_SHOW_DOWNLOAD_FAILED = "showDownloadFailed"
        const val METHOD_CANCEL_DOWNLOAD_NOTIFICATION = "cancelDownloadNotification"
        const val ARG_APK_PATH = "path"
        const val ARG_DOWNLOADED_BYTES = "downloadedBytes"
        const val ARG_TOTAL_BYTES = "totalBytes"
        const val ARG_MESSAGE = "message"
        const val ERROR_APP_UPDATE_FAILED = "APP_UPDATE_FAILED"
        const val ERROR_INSTALL_PERMISSION_REQUIRED = "INSTALL_PERMISSION_REQUIRED"
        const val UPDATE_NOTIFICATION_CHANNEL_ID = "app_update"
        const val UPDATE_NOTIFICATION_ID = 1001
        const val NOTIFICATION_PERMISSION_REQUEST_CODE = 2001
        const val MRP_OPEN_CHANNEL = "skyengine/mrp_open"
        const val METHOD_GET_INITIAL_MRP = "getInitialMrp"
        const val METHOD_OPEN_MRP = "openMrp"
        const val MYTHROAD_ASSETS_CHANNEL = "skyengine/mythroad_assets"
        const val METHOD_ENSURE_SYSTEM = "ensureSystem"
        const val ARG_MYTHROAD_DIR = "mythroadDir"
        const val MYTHROAD_SYSTEM_ASSET = "mythroad_system.zip"
        const val MYTHROAD_SYSTEM_DIR_NAME = "system"
        const val MYTHROAD_DIR_NAME = "mythroad"
        const val MRP_EXTENSION = ".mrp"
        const val DEFAULT_MRP_FILE_NAME = "imported.mrp"
        const val ERROR_BAD_ARGUMENTS = "BAD_ARGUMENTS"
        const val ERROR_MYTHROAD_SYSTEM_FAILED = "MYTHROAD_SYSTEM_FAILED"
        const val VIRTUAL_KEY_VIBRATION_MS = 18L
        const val VIRTUAL_KEY_SILENCE_MS = 1000L
        const val NO_REPEAT = -1
        const val TAG = "SkyEngine"
    }
}
