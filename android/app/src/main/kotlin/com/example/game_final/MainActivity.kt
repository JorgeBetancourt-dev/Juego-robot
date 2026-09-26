package com.example.game_final

import android.media.MediaPlayer
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var musicPlayer: MediaPlayer? = null
    private var resumeAfterPause = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "system_fallen/music",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val asset = call.argument<String>("asset")
                    val volume = call.argument<Double>("volume")?.toFloat() ?: 0.35f
                    if (asset == null) {
                        result.error("missing_asset", "Music asset was not provided", null)
                    } else {
                        playMusic(asset, volume, result)
                    }
                }
                "pause" -> {
                    pauseMusic()
                    result.success(null)
                }
                "resume" -> {
                    resumeMusic()
                    result.success(null)
                }
                "stop" -> {
                    stopMusic()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun playMusic(asset: String, volume: Float, result: MethodChannel.Result) {
        try {
            stopMusic()
            val lookupKey = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
            val descriptor = assets.openFd(lookupKey)
            musicPlayer = MediaPlayer().apply {
                setDataSource(
                    descriptor.fileDescriptor,
                    descriptor.startOffset,
                    descriptor.length,
                )
                isLooping = true
                setVolume(volume, volume)
                prepare()
                start()
            }
            descriptor.close()
            resumeAfterPause = true
            result.success(null)
        } catch (error: Exception) {
            stopMusic()
            result.error("music_error", error.message, null)
        }
    }

    private fun pauseMusic() {
        val player = musicPlayer ?: return
        if (player.isPlaying) {
            resumeAfterPause = true
            player.pause()
        }
    }

    private fun resumeMusic() {
        val player = musicPlayer ?: return
        if (resumeAfterPause && !player.isPlaying) player.start()
    }

    private fun stopMusic() {
        resumeAfterPause = false
        musicPlayer?.run {
            if (isPlaying) stop()
            release()
        }
        musicPlayer = null
    }

    override fun onStop() {
        pauseMusic()
        super.onStop()
    }

    override fun onStart() {
        super.onStart()
        resumeMusic()
    }

    override fun onDestroy() {
        stopMusic()
        super.onDestroy()
    }
}
