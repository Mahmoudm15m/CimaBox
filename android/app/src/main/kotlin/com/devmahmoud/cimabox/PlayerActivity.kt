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
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.PlayerView
import java.io.File
import kotlin.math.abs

class PlayerActivity : AppCompatActivity() {
    private var player: ExoPlayer? = null
    private var playerView: PlayerView? = null
    private var videoUrl: String? = null
    private var videoTitle: String? = "Video"

    private lateinit var gestureLayout: LinearLayout
    private lateinit var gestureIcon: android.widget.ImageView
    private lateinit var gestureText: TextView
    private lateinit var audioManager: AudioManager
    private lateinit var gestureDetector: GestureDetector

    private var startVolume: Int = 0
    private var startBrightness: Float = 0f
    private var startPosition: Long = 0

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
        videoTitle = File(videoUrl ?: "").nameWithoutExtension.replace("-", " ")

        playerView?.setControllerVisibilityListener(object : PlayerView.ControllerVisibilityListener {
            override fun onVisibilityChanged(visibility: Int) {
                if (visibility == View.VISIBLE) {
                    val backBtn = findViewById<ImageButton>(R.id.btn_back)
                    val titleTv = findViewById<TextView>(R.id.tv_video_title)
                    val forwardBtn = findViewById<ImageButton>(R.id.btn_forward_10)
                    val rewindBtn = findViewById<ImageButton>(R.id.btn_rewind_10)

                    if (titleTv != null) titleTv.text = videoTitle
                    if (backBtn != null) backBtn.setOnClickListener { finish() }

                    forwardBtn?.setOnClickListener {
                        player?.let { it.seekTo(it.currentPosition + 10000) }
                    }
                    rewindBtn?.setOnClickListener {
                        player?.let { it.seekTo(it.currentPosition - 10000) }
                    }
                }
            }
        })

        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        gestureDetector = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {

            override fun onDown(e: MotionEvent): Boolean {
                startVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                startBrightness = window.attributes.screenBrightness
                if (startBrightness < 0) startBrightness = 0.5f
                player?.let { startPosition = it.currentPosition }
                currentGestureMode = GestureMode.NONE
                return true
            }

            override fun onScroll(
                e1: MotionEvent?,
                e2: MotionEvent,
                distanceX: Float,
                distanceY: Float
            ): Boolean {
                if (e1 == null) return false

                if (currentGestureMode == GestureMode.NONE) {
                    val diffX = abs(e1.x - e2.x)
                    val diffY = abs(e1.y - e2.y)
                    val touchSlop = 50f

                    if (diffX > touchSlop || diffY > touchSlop) {
                        if (diffY > diffX) {
                            currentGestureMode = GestureMode.VERTICAL
                        } else {
                            currentGestureMode = GestureMode.HORIZONTAL
                        }
                    }
                }

                if (currentGestureMode == GestureMode.NONE) return true

                val viewHeight = playerView!!.height.toFloat()
                val viewWidth = playerView!!.width.toFloat()

                if (currentGestureMode == GestureMode.VERTICAL) {
                    val percentY = (e1.y - e2.y) / viewHeight
                    val isLeftSide = e1.x < viewWidth / 2
                    if (isLeftSide) {
                        adjustBrightness(percentY)
                    } else {
                        adjustVolume(percentY)
                    }
                } else if (currentGestureMode == GestureMode.HORIZONTAL) {
                    val percentX = (e2.x - e1.x) / viewWidth
                    adjustSeek(percentX)
                }
                return true
            }
        })

        playerView?.setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_UP || event.action == MotionEvent.ACTION_CANCEL) {
                gestureLayout.visibility = View.GONE
                currentGestureMode = GestureMode.NONE
            }
            gestureDetector.onTouchEvent(event)
            playerView?.onTouchEvent(event) ?: false
        }
    }

    private fun adjustBrightness(percent: Float) {
        val layoutParams = window.attributes
        var newBrightness = startBrightness + percent
        newBrightness = newBrightness.coerceIn(0.01f, 1.0f)

        layoutParams.screenBrightness = newBrightness
        window.attributes = layoutParams

        val brightnessInt = (newBrightness * 100).toInt()
        showGestureFeedback(android.R.drawable.ic_menu_view, "$brightnessInt%")
    }

    private fun adjustVolume(percent: Float) {
        val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)

        val deltaVolume = (percent * maxVolume).toInt()
        var newVolume = startVolume + deltaVolume
        newVolume = newVolume.coerceIn(0, maxVolume)

        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, newVolume, 0)

        val volumePercent = (newVolume.toFloat() / maxVolume.toFloat() * 100).toInt()
        showGestureFeedback(android.R.drawable.ic_lock_silent_mode_off, "$volumePercent%")
    }

    private fun adjustSeek(percent: Float) {
        val player = player ?: return
        val totalDuration = player.duration

        val seekWindowMs = 120000L
        val deltaMs = (percent * seekWindowMs).toLong()

        var newPosition = startPosition + deltaMs
        newPosition = newPosition.coerceIn(0, totalDuration)

        player.seekTo(newPosition)

        val totalSeconds = newPosition / 1000
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60
        val timeString = String.format("%02d:%02d", minutes, seconds)

        val icon = if (deltaMs > 0) android.R.drawable.ic_media_ff else android.R.drawable.ic_media_rew

        showGestureFeedback(icon, timeString)
    }

    private fun showGestureFeedback(iconResId: Int, text: String) {
        gestureLayout.visibility = View.VISIBLE
        gestureIcon.setImageResource(iconResId)
        gestureText.text = text
    }

    private fun hideSystemUI() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).let { controller ->
            controller.hide(WindowInsetsCompat.Type.systemBars())
            controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
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

        val mediaSourceFactory = DefaultMediaSourceFactory(DownloadUtil.getDataSourceFactory(this))

        player = ExoPlayer.Builder(this)
            .setMediaSourceFactory(mediaSourceFactory)
            .build()

        playerView?.player = player

        val mediaItem = MediaItem.fromUri(videoUrl!!)
        player?.setMediaItem(mediaItem)
        player?.prepare()
        player?.playWhenReady = true
    }

    private fun releasePlayer() {
        player?.release()
        player = null
    }
}