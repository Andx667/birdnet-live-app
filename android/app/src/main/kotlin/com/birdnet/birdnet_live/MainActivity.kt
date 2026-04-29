package com.birdnet.birdnet_live

import android.view.WindowManager
import com.google.android.play.core.assetpacks.AssetPackManagerFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class MainActivity: FlutterActivity() {
    private val WAKELOCK_CHANNEL = "com.birdnet/wakelock"
    private val AUDIO_DECODER_CHANNEL = "com.birdnet/audio_decoder"
    private val ASSET_PACK_CHANNEL = "com.birdnet/asset_pack"
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Wakelock channel.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WAKELOCK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(null)
                }
                "disable" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Audio decoder channel — decode compressed audio to PCM via MediaCodec.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_DECODER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "decode" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_ARG", "Missing 'path' argument", null)
                        return@setMethodCallHandler
                    }
                    scope.launch {
                        try {
                            val decoded = NativeAudioDecoder.decode(path)
                            withContext(Dispatchers.Main) {
                                result.success(decoded)
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("DECODE_ERROR", e.message, null)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Asset pack channel — resolves the on-device path of an
        // install-time Play Asset Delivery pack. Used to locate the ONNX
        // model files in App Bundle (AAB) installs from the Play Store.
        // On sideload APK installs there is no asset pack, so the call
        // returns null and the Dart side falls back to extracting the
        // models from `rootBundle`.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ASSET_PACK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPackPath" -> {
                    val packName = call.argument<String>("packName")
                    if (packName.isNullOrBlank()) {
                        result.error("INVALID_ARG", "Missing 'packName'", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val mgr = AssetPackManagerFactory.getInstance(applicationContext)
                        val location = mgr.getPackLocation(packName)
                        result.success(location?.assetsPath())
                    } catch (e: Throwable) {
                        // Sideload APK without Play Asset Delivery support,
                        // pack not installed, or any other failure: report
                        // null so the Dart side falls back to rootBundle.
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}
