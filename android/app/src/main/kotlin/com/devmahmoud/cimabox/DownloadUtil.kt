package com.devmahmoud.cimabox

import android.content.Context
import androidx.media3.database.DatabaseProvider
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.cache.Cache
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.NoOpCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import androidx.media3.exoplayer.offline.DownloadManager
import java.io.File
import java.util.concurrent.Executors

object DownloadUtil {
    private const val DOWNLOAD_CONTENT_DIRECTORY = "downloads"
    private var databaseProvider: DatabaseProvider? = null
    private var downloadCache: Cache? = null
    private var dataSourceFactory: DataSource.Factory? = null
    private var downloadManager: DownloadManager? = null

    @Synchronized
    fun getDownloadManager(context: Context): DownloadManager {
        ensureDownloadManagerInitialized(context)
        return downloadManager!!
    }

    @Synchronized
    fun getDataSourceFactory(context: Context): DataSource.Factory {
        if (dataSourceFactory == null) {
            val contextApplication = context.applicationContext
            val upstreamFactory = DynamicHeaderDataSourceFactory()

            dataSourceFactory = CacheDataSource.Factory()
                .setCache(getDownloadCache(contextApplication))
                .setUpstreamDataSourceFactory(upstreamFactory)
                .setCacheWriteDataSinkFactory(null)
                .setFlags(CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR)
        }
        return dataSourceFactory!!
    }

    private class DynamicHeaderDataSourceFactory : DataSource.Factory {
        private val internalFactory = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(8000)
            .setReadTimeoutMs(8000)

        override fun createDataSource(): DataSource {
            val internalDataSource = internalFactory.createDataSource() as DefaultHttpDataSource
            return DynamicHeaderDataSource(internalDataSource)
        }
    }

    private class DynamicHeaderDataSource(
        private val internalSource: DefaultHttpDataSource
    ) : DataSource {

        override fun addTransferListener(transferListener: androidx.media3.datasource.TransferListener) {
            internalSource.addTransferListener(transferListener)
        }

        override fun open(dataSpec: DataSpec): Long {
            val headers = HeadersStore.getHeaders(dataSpec.uri.toString())
            if (headers != null) {
                headers.forEach { (key, value) ->
                    internalSource.setRequestProperty(key, value)
                }
            }
            return internalSource.open(dataSpec)
        }

        override fun read(buffer: ByteArray, offset: Int, length: Int): Int = internalSource.read(buffer, offset, length)
        override fun getUri(): android.net.Uri? = internalSource.uri
        override fun close() = internalSource.close()
        override fun getResponseHeaders(): Map<String, List<String>> = internalSource.responseHeaders
    }

    @Synchronized
    private fun getDownloadCache(context: Context): Cache {
        if (downloadCache == null) {
            val downloadContentDirectory = File(context.getExternalFilesDir(null), DOWNLOAD_CONTENT_DIRECTORY)
            downloadCache = SimpleCache(
                downloadContentDirectory,
                NoOpCacheEvictor(),
                getDatabaseProvider(context)
            )
        }
        return downloadCache!!
    }

    @Synchronized
    private fun ensureDownloadManagerInitialized(context: Context) {
        if (downloadManager == null) {
            val downloadExecutor = Executors.newFixedThreadPool(6)
            downloadManager = DownloadManager(
                context,
                getDatabaseProvider(context),
                getDownloadCache(context),
                getDataSourceFactory(context),
                downloadExecutor
            ).apply {
                maxParallelDownloads = 3
            }
        }
    }

    @Synchronized
    private fun getDatabaseProvider(context: Context): DatabaseProvider {
        if (databaseProvider == null) {
            databaseProvider = StandaloneDatabaseProvider(context)
        }
        return databaseProvider!!
    }
}