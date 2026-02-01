package com.devmahmoud.cimabox

import android.net.Uri

object HeadersStore {
    private val headersMap = mutableMapOf<String, Map<String, String>>()

    fun saveHeaders(url: String, headers: Map<String, String>) {
        headersMap[url] = headers
    }

    fun getHeaders(url: String): Map<String, String>? {
        if (headersMap.containsKey(url)) {
            return headersMap[url]
        }
        val host = Uri.parse(url).host
        if (host != null) {
            for ((key, value) in headersMap) {
                if (key.contains(host)) return value
            }
        }
        return null
    }

    fun removeHeaders(url: String) {
        headersMap.remove(url)
    }
}