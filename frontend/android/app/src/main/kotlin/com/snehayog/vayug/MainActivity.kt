package com.snehayog.vayug

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.snehayog.vayug/share_receiver"
    private var methodChannel: MethodChannel? = null
    private var pendingSharedVideoPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharedVideo" -> {
                    val path = pendingSharedVideoPath
                    pendingSharedVideoPath = null
                    result.success(path)
                }
                "clearSharedVideo" -> {
                    pendingSharedVideoPath = null
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Handle cold-start share intent
        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShareIntent(intent)
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        val type = intent.type

        if (Intent.ACTION_SEND == action && type != null && type.startsWith("video/")) {
            @Suppress("DEPRECATION")
            val uri: Uri? = intent.getParcelableExtra(Intent.EXTRA_STREAM)
                ?: (if (intent.clipData != null && intent.clipData!!.itemCount > 0) intent.clipData!!.getItemAt(0).uri else null)
                ?: intent.data

            if (uri != null) {
                Thread {
                    val cachedPath = copyUriToCache(uri)
                    if (cachedPath != null) {
                        runOnUiThread {
                            if (methodChannel != null) {
                                methodChannel?.invokeMethod("onVideoReceived", cachedPath)
                            } else {
                                pendingSharedVideoPath = cachedPath
                            }
                        }
                    }
                }.start()
            }
        }
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val inputStream = contentResolver.openInputStream(uri) ?: return null
            val fileName = "shared_video_${System.currentTimeMillis()}.mp4"
            val destFile = File(cacheDir, fileName)
            destFile.outputStream().use { output ->
                inputStream.copyTo(output)
            }
            destFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
