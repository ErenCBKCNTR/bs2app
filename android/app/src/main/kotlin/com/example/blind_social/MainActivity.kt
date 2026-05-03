package com.example.blind_social

import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.blind_social/lockscreen"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setLockScreenVisibility" -> {
                    val isVisible = call.argument<Boolean>("isVisible") ?: false
                    setLockScreenVisibility(isVisible)
                    result.success(null)
                }
                "toggleScreenProtection" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    toggleScreenProtection(enabled)
                    result.success(null)
                }
                "playTone" -> {
                    val type = call.argument<String>("type") ?: "start"
                    val duration = call.argument<Int>("duration") ?: 150
                    playTone(type, duration)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun playTone(type: String, durationMs: Int) {
        try {
            val volume = if (type == "start") 30 else 50
            val toneGen = ToneGenerator(AudioManager.STREAM_DTMF, volume)
            val toneParam = if (type == "end") ToneGenerator.TONE_PROP_PROMPT else ToneGenerator.TONE_PROP_BEEP
            toneGen.startTone(toneParam, durationMs)
            
            Handler(Looper.getMainLooper()).postDelayed({
                toneGen.release()
            }, (durationMs + 50).toLong())
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun toggleScreenProtection(enabled: Boolean) {
        runOnUiThread {
            if (enabled) {
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        }
    }

    private fun setLockScreenVisibility(isVisible: Boolean) {
        runOnUiThread {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(isVisible)
                setTurnScreenOn(isVisible)
            } else {
                if (isVisible) {
                    window.addFlags(
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                    )
                } else {
                    window.clearFlags(
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                    )
                }
            }
        }
    }
}
