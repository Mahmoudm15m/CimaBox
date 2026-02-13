package com.devmahmoud.cimabox

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import androidx.media3.exoplayer.offline.Download
import androidx.media3.exoplayer.offline.DownloadRequest
import androidx.media3.exoplayer.offline.DownloadService
import androidx.media3.datasource.DataSpec
import java.io.File
import java.io.FileOutputStream
import java.util.ArrayList
import java.util.HashSet

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.cima_box/downloads"
    private val EVENT_CHANNEL = "com.cima_box/downloads_progress"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startDownload" -> {
                    val url = call.argument<String>("url")
                    val title = call.argument<String>("title")
                    val id = call.argument<String>("id")
                    val headers = call.argument<Map<String, String>>("headers")

                    if (url != null && title != null && id != null) {
                        if (headers != null) {
                            HeadersStore.saveHeaders(url, headers)
                        }
                        startDownload(url, title, id)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Url, title or id missing", null)
                    }
                }
                "pauseDownload" -> {
                    val id = call.argument<String>("url")
                    if (id != null) {
                        pauseDownload(id)
                        result.success(true)
                    }
                }
                "resumeDownload" -> {
                    val id = call.argument<String>("url")
                    if (id != null) {
                        resumeDownload(id)
                        result.success(true)
                    }
                }
                "removeDownload" -> {
                    val id = call.argument<String>("url")
                    if (id != null) {
                        removeDownload(id)
                        result.success(true)
                    }
                }
                "playOfflineVideo" -> {
                    val url = call.argument<String>("url")
                    val id = call.argument<String>("id")
                    if (url != null) {
                        val intent = Intent(this, PlayerActivity::class.java)
                        intent.putExtra("video_url", url)
                        intent.putExtra("cache_key", id)
                        startActivity(intent)
                        result.success(true)
                    }
                }

                "exportDownload" -> {
                    val url = call.argument<String>("url")
                    val title = call.argument<String>("title")

                    if (url != null && title != null) {
                        Thread {
                            try {
                                val downloadManager = DownloadUtil.getDownloadManager(context)
                                var cacheKey: String? = null

                                val cursor = downloadManager.downloadIndex.getDownloads()
                                while (cursor.moveToNext()) {
                                    val download = cursor.download
                                    if (download.request.uri.toString() == url && download.state == Download.STATE_COMPLETED) {
                                        cacheKey = download.request.customCacheKey ?: download.request.id
                                        break
                                    }
                                }
                                cursor.close()

                                if (cacheKey == null) {
                                    runOnUiThread {
                                        result.error("NOT_FOUND", "الملف غير موجود في التنزيلات المكتملة", null)
                                    }
                                    return@Thread
                                }

                                val targetDir = File(android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOWNLOADS), "CimaBox")
                                if (!targetDir.exists()) targetDir.mkdirs()

                                val safeTitle = title.replace("[\\\\/:*?\"<>|]".toRegex(), "_")
                                val targetFile = File(targetDir, "$safeTitle.mp4")

                                val dataSourceFactory = DownloadUtil.getDataSourceFactory(context)
                                val dataSource = dataSourceFactory.createDataSource()

                                val dataSpec = DataSpec.Builder()
                                    .setUri(Uri.parse(url))
                                    .setKey(cacheKey)
                                    .setFlags(DataSpec.FLAG_ALLOW_CACHE_FRAGMENTATION)
                                    .build()

                                dataSource.open(dataSpec)
                                val outputStream = FileOutputStream(targetFile)
                                val buffer = ByteArray(1024 * 64)
                                var bytesRead: Int

                                while (dataSource.read(buffer, 0, buffer.size).also { bytesRead = it } != -1) {
                                    outputStream.write(buffer, 0, bytesRead)
                                }

                                outputStream.flush()
                                outputStream.close()
                                dataSource.close()

                                DownloadService.sendRemoveDownload(
                                    this,
                                    MyDownloadService::class.java,
                                    cacheKey,
                                    false
                                )

                                runOnUiThread {
                                    result.success(targetFile.absolutePath)
                                }

                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("EXPORT_FAILED", e.message, null)
                                }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "Url or title missing", null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(DownloadProgressStreamHandler(this))
    }

    private fun startDownload(url: String, title: String, id: String) {
        val downloadRequest = DownloadRequest.Builder(id, Uri.parse(url))
            .setData(title.toByteArray())
            .setCustomCacheKey(id)
            .build()

        DownloadService.sendAddDownload(
            this,
            MyDownloadService::class.java,
            downloadRequest,
            false
        )
    }

    private fun pauseDownload(id: String) {
        DownloadService.sendSetStopReason(
            this,
            MyDownloadService::class.java,
            id,
            1,
            false
        )
    }

    private fun resumeDownload(id: String) {
        DownloadService.sendSetStopReason(
            this,
            MyDownloadService::class.java,
            id,
            0,
            false
        )
    }

    private fun removeDownload(id: String) {
        HeadersStore.removeHeaders(id)
        DownloadService.sendRemoveDownload(
            this,
            MyDownloadService::class.java,
            id,
            false
        )
    }
}

class DownloadProgressStreamHandler(private val context: Context) : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    private var handler: Handler = Handler(Looper.getMainLooper())
    private var isDisposed = false
    private val trackedIds = HashSet<String>()
    private var isFirstRun = true

    private val progressRunnable = object : Runnable {
        override fun run() {
            if (isDisposed) return

            try {
                val downloadManager = DownloadUtil.getDownloadManager(context)
                val updates = ArrayList<Map<String, Any>>()
                val currentActiveIds = HashSet<String>()

                if (isFirstRun) {
                    isFirstRun = false
                    val cursor = downloadManager.downloadIndex.getDownloads()
                    while (cursor.moveToNext()) {
                        val download = cursor.download
                        val id = download.request.id

                        if (download.state != Download.STATE_COMPLETED && download.state != Download.STATE_FAILED) {
                            trackedIds.add(id)
                        }

                        val percent = download.percentDownloaded
                        val downloadedBytes = download.bytesDownloaded
                        val totalBytes = if (download.contentLength != -1L) download.contentLength else 0L

                        updates.add(mapOf(
                            "id" to id,
                            "status" to download.state,
                            "progress" to percent,
                            "downloadedBytes" to downloadedBytes,
                            "totalBytes" to totalBytes
                        ))
                    }
                    cursor.close()
                } else {
                    val activeDownloads = downloadManager.currentDownloads
                    for (download in activeDownloads) {
                        val id = download.request.id
                        currentActiveIds.add(id)
                        trackedIds.add(id)

                        val percent = download.percentDownloaded
                        val downloadedBytes = download.bytesDownloaded
                        val totalBytes = if (download.contentLength != -1L) download.contentLength else 0L

                        updates.add(mapOf(
                            "id" to id,
                            "status" to download.state,
                            "progress" to percent,
                            "downloadedBytes" to downloadedBytes,
                            "totalBytes" to totalBytes
                        ))
                    }

                    val iterator = trackedIds.iterator()
                    while (iterator.hasNext()) {
                        val id = iterator.next()
                        if (!currentActiveIds.contains(id)) {
                            val download = downloadManager.downloadIndex.getDownload(id)
                            if (download != null) {
                                val totalBytes = if (download.contentLength != -1L) download.contentLength else 0L

                                updates.add(mapOf(
                                    "id" to download.request.id,
                                    "status" to download.state,
                                    "progress" to download.percentDownloaded,
                                    "downloadedBytes" to download.bytesDownloaded,
                                    "totalBytes" to totalBytes
                                ))

                                if (download.state == Download.STATE_COMPLETED || download.state == Download.STATE_FAILED) {
                                    iterator.remove()
                                }
                            } else {
                                iterator.remove()
                            }
                        }
                    }
                }

                if (updates.isNotEmpty()) {
                    eventSink?.success(updates)
                }

            } catch (e: Exception) {
            }

            handler.postDelayed(this, 100)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        handler.post(progressRunnable)
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        handler.removeCallbacks(progressRunnable)
    }

    fun dispose() {
        isDisposed = true
        handler.removeCallbacks(progressRunnable)
    }
}