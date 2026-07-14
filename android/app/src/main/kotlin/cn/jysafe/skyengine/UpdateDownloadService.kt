package cn.jysafe.skyengine

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.Executors

class UpdateDownloadService : Service() {
    private val executor = Executors.newSingleThreadExecutor()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val request = intent?.toRequest()
        startForeground(NOTIFICATION_ID, progressNotification(0L, request?.expectedSize ?: 0L))

        if (request == null) {
            finishWithError("更新下载参数无效")
            return START_NOT_STICKY
        }

        executor.execute {
            try {
                val apk = download(request)
                showCompleteNotification(apk)
                sendResult(apk.absolutePath, null)
            } catch (error: Exception) {
                request.tempFile.delete()
                val message = error.message?.takeIf { it.isNotBlank() } ?: "请稍后重试"
                showFailedNotification(message)
                sendResult(null, message)
            } finally {
                stopForeground(false)
                stopSelf(startId)
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        executor.shutdown()
        super.onDestroy()
    }

    private fun download(request: DownloadRequest): File {
        val target = request.target
        val parent = target.parentFile ?: error("更新包目录无效")
        if (!parent.exists() && !parent.mkdirs()) {
            error("无法创建更新包目录")
        }

        parent.listFiles()?.forEach { file ->
            if (file != target &&
                (file.name.endsWith(".apk", ignoreCase = true) ||
                    file.name.endsWith(".apk.download", ignoreCase = true))
            ) {
                file.delete()
            }
        }
        request.tempFile.delete()

        val connection = (URL(request.url).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = CONNECT_TIMEOUT_MS
            readTimeout = READ_TIMEOUT_MS
            instanceFollowRedirects = true
            useCaches = false
            request.headers.forEach { (name, value) -> setRequestProperty(name, value) }
        }

        try {
            val status = connection.responseCode
            if (status != HttpURLConnection.HTTP_OK) {
                val body = connection.errorStream
                    ?.bufferedReader()
                    ?.use { it.readText().trim().take(500) }
                    .orEmpty()
                error(if (body.isEmpty()) "下载失败（HTTP $status）" else body)
            }

            val total = if (request.expectedSize > 0L) {
                request.expectedSize
            } else {
                connection.contentLengthLong
            }
            var downloaded = 0L
            var lastNotifiedAt = 0L
            var lastPercent = -1

            connection.inputStream.buffered().use { input ->
                FileOutputStream(request.tempFile).buffered().use { output ->
                    val buffer = ByteArray(BUFFER_SIZE)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        output.write(buffer, 0, count)
                        downloaded += count

                        val now = SystemClock.elapsedRealtime()
                        val percent = if (total > 0L) {
                            ((downloaded * 100L) / total).coerceIn(0L, 100L).toInt()
                        } else {
                            -1
                        }
                        if (percent != lastPercent || now - lastNotifiedAt >= NOTIFY_INTERVAL_MS) {
                            showProgress(downloaded, total)
                            lastPercent = percent
                            lastNotifiedAt = now
                        }
                    }
                }
            }

            if (downloaded <= 0L ||
                (request.expectedSize > 0L && downloaded != request.expectedSize)
            ) {
                error("下载的更新包不完整")
            }
            if (!checksumMatches(request.tempFile, request.checksum)) {
                error("下载的更新包校验失败")
            }

            if (target.exists() && !target.delete()) {
                error("无法替换旧更新包")
            }
            if (!request.tempFile.renameTo(target)) {
                error("无法保存更新包")
            }
            return target
        } finally {
            connection.disconnect()
        }
    }

    private fun checksumMatches(file: File, checksum: String): Boolean {
        val match = CHECKSUM_PATTERN.matchEntire(checksum.trim()) ?: return true
        val expected = match.groupValues[2].lowercase()
        val name = match.groupValues[1].lowercase().ifEmpty {
            when (expected.length) {
                64 -> "sha256"
                32 -> "md5"
                else -> return true
            }
        }
        val algorithm = when (name) {
            "sha256" -> "SHA-256"
            "md5" -> "MD5"
            else -> return true
        }
        val digest = MessageDigest.getInstance(algorithm)
        file.inputStream().buffered().use { input ->
            val buffer = ByteArray(BUFFER_SIZE)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        val actual = digest.digest().joinToString("") {
            (it.toInt() and 0xff).toString(16).padStart(2, '0')
        }
        return actual == expected
    }

    private fun showProgress(downloaded: Long, total: Long) {
        notify(progressNotification(downloaded, total))
    }

    private fun progressNotification(downloaded: Long, total: Long): Notification {
        ensureNotificationChannel()
        val hasTotal = total > 0L
        val percent = if (hasTotal) {
            ((downloaded * 100L) / total).coerceIn(0L, 100L).toInt()
        } else {
            0
        }
        val text = if (hasTotal) {
            "$percent%（${formatBytes(downloaded)} / ${formatBytes(total)}）"
        } else {
            "已下载 ${formatBytes(downloaded)}"
        }
        return notificationBuilder()
            .setContentTitle("正在下载更新")
            .setContentText(text)
            .setContentIntent(openAppIntent())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setProgress(if (hasTotal) 100 else 0, percent, !hasTotal)
            .build()
    }

    private fun showCompleteNotification(apk: File) {
        val installIntent = Intent(this, MainActivity::class.java).apply {
            action = ACTION_INSTALL_UPDATE
            putExtra(EXTRA_RESULT_PATH, apk.absolutePath)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val contentIntent = PendingIntent.getActivity(
            this,
            INSTALL_REQUEST_CODE,
            installIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        notify(
            notificationBuilder()
                .setContentTitle("更新下载完成")
                .setContentText("点击安装 ${apk.name}")
                .setContentIntent(contentIntent)
                .setOngoing(false)
                .setOnlyAlertOnce(false)
                .setProgress(0, 0, false)
                .setAutoCancel(true)
                .build(),
        )
    }

    private fun showFailedNotification(message: String) {
        notify(
            notificationBuilder()
                .setContentTitle("更新下载失败")
                .setContentText(message)
                .setStyle(NotificationCompat.BigTextStyle().bigText(message))
                .setContentIntent(openAppIntent())
                .setOngoing(false)
                .setOnlyAlertOnce(false)
                .setProgress(0, 0, false)
                .setAutoCancel(true)
                .build(),
        )
    }

    private fun finishWithError(message: String) {
        showFailedNotification(message)
        sendResult(null, message)
        stopForeground(false)
        stopSelf()
    }

    private fun sendResult(path: String?, error: String?) {
        sendBroadcast(
            Intent(ACTION_DOWNLOAD_RESULT).apply {
                setPackage(packageName)
                putExtra(EXTRA_RESULT_PATH, path)
                putExtra(EXTRA_RESULT_ERROR, error)
            },
        )
    }

    private fun notify(notification: Notification) {
        try {
            NotificationManagerCompat.from(this).notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // The foreground service still runs when the user has hidden notifications.
        }
    }

    private fun notificationBuilder(): NotificationCompat.Builder {
        ensureNotificationChannel()
        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(NOTIFICATION_CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "应用更新",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "显示应用更新下载进度"
            },
        )
    }

    private fun openAppIntent(): PendingIntent {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            this,
            OPEN_APP_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun Intent.toRequest(): DownloadRequest? {
        val url = getStringExtra(EXTRA_URL)?.takeIf { it.isNotBlank() } ?: return null
        val destinationPath = getStringExtra(EXTRA_DESTINATION_PATH)
            ?.takeIf { it.isNotBlank() }
            ?: return null
        val headerNames = getStringArrayExtra(EXTRA_HEADER_NAMES).orEmpty()
        val headerValues = getStringArrayExtra(EXTRA_HEADER_VALUES).orEmpty()
        if (headerNames.size != headerValues.size) return null
        val headers = headerNames.indices.associate { headerNames[it] to headerValues[it] }
        return DownloadRequest(
            url = url,
            target = File(destinationPath),
            headers = headers,
            expectedSize = getLongExtra(EXTRA_EXPECTED_SIZE, 0L),
            checksum = getStringExtra(EXTRA_CHECKSUM).orEmpty(),
        )
    }

    private data class DownloadRequest(
        val url: String,
        val target: File,
        val headers: Map<String, String>,
        val expectedSize: Long,
        val checksum: String,
    ) {
        val tempFile: File get() = File("${target.absolutePath}.download")
    }

    companion object {
        const val ACTION_DOWNLOAD_RESULT =
            "cn.jysafe.skyengine.action.UPDATE_DOWNLOAD_RESULT"
        const val ACTION_INSTALL_UPDATE =
            "cn.jysafe.skyengine.action.INSTALL_UPDATE"
        const val EXTRA_RESULT_PATH = "updateResultPath"
        const val EXTRA_RESULT_ERROR = "updateResultError"

        private const val EXTRA_URL = "url"
        private const val EXTRA_DESTINATION_PATH = "destinationPath"
        private const val EXTRA_HEADER_NAMES = "headerNames"
        private const val EXTRA_HEADER_VALUES = "headerValues"
        private const val EXTRA_EXPECTED_SIZE = "expectedSize"
        private const val EXTRA_CHECKSUM = "checksum"
        private const val NOTIFICATION_CHANNEL_ID = "app_update"
        private const val NOTIFICATION_ID = 1001
        private const val OPEN_APP_REQUEST_CODE = 3001
        private const val INSTALL_REQUEST_CODE = 3002
        private const val CONNECT_TIMEOUT_MS = 15_000
        private const val READ_TIMEOUT_MS = 30_000
        private const val BUFFER_SIZE = 64 * 1024
        private const val NOTIFY_INTERVAL_MS = 1_000L
        private val CHECKSUM_PATTERN =
            Regex("^(?:(sha256|md5)[:=])?([0-9a-f]+)$", RegexOption.IGNORE_CASE)

        fun start(
            context: Context,
            url: String,
            destinationPath: String,
            headers: Map<String, String>,
            expectedSize: Long,
            checksum: String,
        ) {
            val intent = Intent(context, UpdateDownloadService::class.java).apply {
                putExtra(EXTRA_URL, url)
                putExtra(EXTRA_DESTINATION_PATH, destinationPath)
                putExtra(EXTRA_HEADER_NAMES, headers.keys.toTypedArray())
                putExtra(EXTRA_HEADER_VALUES, headers.values.toTypedArray())
                putExtra(EXTRA_EXPECTED_SIZE, expectedSize)
                putExtra(EXTRA_CHECKSUM, checksum)
            }
            ContextCompat.startForegroundService(context, intent)
        }

        private fun formatBytes(bytes: Long): String {
            if (bytes < 1024L) return "$bytes B"
            val kib = bytes / 1024.0
            if (kib < 1024.0) return String.format("%.1f KB", kib)
            return String.format("%.1f MB", kib / 1024.0)
        }
    }
}
