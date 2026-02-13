package com.devmahmoud.cimabox

import android.content.Context
import android.media.AudioManager
import android.os.Bundle
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.PlayerView
import androidx.media3.datasource.DefaultDataSource
import java.io.File
import kotlin.math.abs

class PlayerActivity : AppCompatActivity() {

    private var player: ExoPlayer? = null
    private var playerView: PlayerView? = null
    private var videoUrl: String? = null
    private var cacheKey: String? = null
    private var videoTitle: String? = "Video"

    private lateinit var gestureLayout: LinearLayout
    private lateinit var gestureIcon: android.widget.ImageView
    private lateinit var gestureText: TextView
    private lateinit var audioManager: AudioManager
    private lateinit var gestureDetector: GestureDetector

    private var startVolume = 0
    private var startBrightness = 0f
    private var startPosition = 0L

    private var isLongPress = false
    private val normalSpeed = 1.0f
    private var canControl = false

    private enum class GestureMode { NONE, VERTICAL, HORIZONTAL }
    private var currentGestureMode = GestureMode.NONE

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_player)

        hideSystemUI()

        playerView = findViewById(R.id.player_view)
        gestureLayout = findViewById(R.id.gesture_layout)
        gestureIcon = findViewById(R.id.gesture_icon)
        gestureText = findViewById(R.id.gesture_text)

        videoUrl = intent.getStringExtra("video_url")
        cacheKey = intent.getStringExtra("cache_key")
        videoTitle = File(videoUrl ?: "").nameWithoutExtension.replace("-", " ")

        playerView?.setControllerVisibilityListener(
            object : PlayerView.ControllerVisibilityListener {
                override fun onVisibilityChanged(visibility: Int) {
                    if (visibility == View.VISIBLE) {
                        findViewById<TextView>(R.id.tv_video_title)?.text = videoTitle
                        findViewById<ImageButton>(R.id.btn_back)?.setOnClickListener { finish() }

                        findViewById<ImageButton>(R.id.btn_forward_10)?.setOnClickListener {
                            if (canControl) {
                                player?.seekTo((player?.currentPosition ?: 0) + 10000)
                            }
                        }

                        findViewById<ImageButton>(R.id.btn_rewind_10)?.setOnClickListener {
                            if (canControl) {
                                player?.seekTo((player?.currentPosition ?: 0) - 10000)
                            }
                        }
                    }
                }
            }
        )

        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        gestureDetector = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {

            override fun onDown(e: MotionEvent): Boolean {
                startVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                startBrightness = window.attributes.screenBrightness
                if (startBrightness < 0) startBrightness = 0.5f
                startPosition = player?.currentPosition ?: 0L
                currentGestureMode = GestureMode.NONE
                isLongPress = false
                return true
            }

            override fun onLongPress(e: MotionEvent) {
                if (!canControl) return
                val p = player ?: return

                val width = playerView!!.width
                isLongPress = true

                if (e.x > width / 2) {
                    p.setPlaybackSpeed(2.0f)
                    showGestureFeedback(android.R.drawable.ic_media_ff, "2x")
                } else {
                    p.setPlaybackSpeed(0.5f)
                    showGestureFeedback(android.R.drawable.ic_media_rew, "0.5x")
                }
            }

            override fun onScroll(
                e1: MotionEvent?,
                e2: MotionEvent,
                distanceX: Float,
                distanceY: Float
            ): Boolean {
                if (!canControl || isLongPress || e1 == null) return true

                if (currentGestureMode == GestureMode.NONE) {
                    val diffX = abs(e1.x - e2.x)
                    val diffY = abs(e1.y - e2.y)
                    if (diffX > 50 || diffY > 50) {
                        currentGestureMode =
                            if (diffY > diffX) GestureMode.VERTICAL else GestureMode.HORIZONTAL
                    }
                }

                val h = playerView!!.height.toFloat()
                val w = playerView!!.width.toFloat()

                when (currentGestureMode) {
                    GestureMode.VERTICAL -> {
                        val percent = (e1.y - e2.y) / h
                        if (e1.x < w / 2) adjustBrightness(percent)
                        else adjustVolume(percent)
                    }
                    GestureMode.HORIZONTAL -> {
                        val percent = (e2.x - e1.x) / w
                        adjustSeek(percent)
                    }
                    else -> {}
                }
                return true
            }
        })

        playerView?.setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_UP ||
                event.action == MotionEvent.ACTION_CANCEL
            ) {
                if (isLongPress) {
                    player?.setPlaybackSpeed(normalSpeed)
                }
                gestureLayout.visibility = View.GONE
                currentGestureMode = GestureMode.NONE
                isLongPress = false
            }
            gestureDetector.onTouchEvent(event)
            playerView?.onTouchEvent(event) ?: false
        }
    }

    private fun adjustBrightness(percent: Float) {
        val params = window.attributes
        var value = startBrightness + percent
        value = value.coerceIn(0.01f, 1f)
        params.screenBrightness = value
        window.attributes = params
        showGestureFeedback(android.R.drawable.ic_menu_view, "${(value * 100).toInt()}%")
    }

    private fun adjustVolume(percent: Float) {
        val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        var value = startVolume + (percent * max).toInt()
        value = value.coerceIn(0, max)
        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, value, 0)
        showGestureFeedback(
            android.R.drawable.ic_lock_silent_mode_off,
            "${(value * 100 / max)}%"
        )
    }

    private fun adjustSeek(percent: Float) {
        val p = player ?: return
        val delta = (percent * 120000).toLong()
        var pos = startPosition + delta
        pos = pos.coerceIn(0, p.duration)
        p.seekTo(pos)

        val sec = pos / 1000
        showGestureFeedback(
            if (delta > 0) android.R.drawable.ic_media_ff
            else android.R.drawable.ic_media_rew,
            String.format("%02d:%02d", sec / 60, sec % 60)
        )
    }

    private fun showGestureFeedback(icon: Int, text: String) {
        gestureLayout.visibility = View.VISIBLE
        gestureIcon.setImageResource(icon)
        gestureText.text = text
    }

    private fun hideSystemUI() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).apply {
            hide(WindowInsetsCompat.Type.systemBars())
            systemBarsBehavior =
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
    }

    override fun onStart() {
        super.onStart()
        initializePlayer()
    }

    override fun onStop() {
        super.onStop()
        releasePlayer()
    }

    private fun initializePlayer() {
        if (videoUrl == null) return

        
        val isLocalFile = videoUrl!!.startsWith("/") || videoUrl!!.startsWith("file://")

        val dataSourceFactory = if (isLocalFile) {
            
            DefaultDataSource.Factory(this)
        } else {
            
            DownloadUtil.getDataSourceFactory(this)
        }

        val mediaSourceFactory = DefaultMediaSourceFactory(dataSourceFactory)

        player = ExoPlayer.Builder(this)
            .setMediaSourceFactory(mediaSourceFactory)
            .build()

        player?.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(state: Int) {
                if (state == Player.STATE_READY) {
                    canControl = true
                }
            }
        })

        val mediaItemBuilder = MediaItem.Builder()
            .setUri(videoUrl!!)

        
        if (cacheKey != null && !isLocalFile) {
            mediaItemBuilder.setCustomCacheKey(cacheKey)
        }

        playerView?.player = player
        player?.setMediaItem(mediaItemBuilder.build())
        player?.prepare()
        player?.playWhenReady = true
    }

    private fun releasePlayer() {
        canControl = false
        player?.release()
        player = null
    }
}