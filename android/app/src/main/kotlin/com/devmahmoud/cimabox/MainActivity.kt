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
import java.util.ArrayList

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
                    val headers = call.argument<Map<String, String>>("headers")

                    if (url != null && title != null) {
                        if (headers != null) {
                            HeadersStore.saveHeaders(url, headers)
                        }
                        startDownload(url, title)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Url or title missing", null)
                    }
                }
                "pauseDownload" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        pauseDownload(url)
                        result.success(true)
                    }
                }
                "resumeDownload" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        resumeDownload(url)
                        result.success(true)
                    }
                }
                "removeDownload" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        removeDownload(url)
                        result.success(true)
                    }
                }
                "playOfflineVideo" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        val intent = Intent(this, PlayerActivity::class.java)
                        intent.putExtra("video_url", url)
                        startActivity(intent)
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(DownloadProgressStreamHandler(this))
    }

    private fun startDownload(url: String, title: String) {
        val downloadRequest = DownloadRequest.Builder(url, Uri.parse(url))
            .setData(title.toByteArray())
            .build()

        DownloadService.sendAddDownload(
            this,
            MyDownloadService::class.java,
            downloadRequest,
            false
        )
    }

    private fun pauseDownload(url: String) {
        DownloadService.sendSetStopReason(
            this,
            MyDownloadService::class.java,
            url,
            1,
            false
        )
    }

    private fun resumeDownload(url: String) {
        DownloadService.sendSetStopReason(
            this,
            MyDownloadService::class.java,
            url,
            0,
            false
        )
    }

    private fun removeDownload(url: String) {
        HeadersStore.removeHeaders(url)
        DownloadService.sendRemoveDownload(
            this,
            MyDownloadService::class.java,
            url,
            false
        )
    }
}

class DownloadProgressStreamHandler(private val context: Context) : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    private var handler: Handler = Handler(Looper.getMainLooper())
    private var isDisposed = false

    private val progressRunnable = object : Runnable {
        override fun run() {
            if (isDisposed) return

            try {
                val downloadManager = DownloadUtil.getDownloadManager(context)
                val cursor = downloadManager.downloadIndex.getDownloads()
                val updates = ArrayList<Map<String, Any>>()

                while (cursor.moveToNext()) {
                    val download = cursor.download

                    val percent = download.percentDownloaded
                    val downloadedBytes = download.bytesDownloaded
                    val totalBytes = if (download.contentLength != -1L) download.contentLength else 0L

                    updates.add(mapOf(
                        "id" to download.request.id,
                        "status" to download.state,
                        "progress" to percent,
                        "downloadedBytes" to downloadedBytes,
                        "totalBytes" to totalBytes
                    ))
                }

                if (updates.isNotEmpty()) {
                    eventSink?.success(updates)
                }

            } catch (e: Exception) {
            }

            handler.postDelayed(this, 500)
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