package com.example.wikiman_app

import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.wikiman_app/heic"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "convertToPng") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.error("INVALID_PATH", "변환할 파일 경로가 없습니다.", null)
                    return@setMethodCallHandler
                }

                try {
                    result.success(convertHeicToPng(path))
                } catch (error: Exception) {
                    result.error(
                        "CONVERT_FAILED",
                        error.message ?: "HEIC를 PNG로 변환하지 못했습니다.",
                        null,
                    )
                }
            }
    }

    private fun convertHeicToPng(path: String): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            throw IllegalStateException("이 Android 버전에서는 HEIC 변환을 지원하지 않습니다.")
        }

        val sourceFile = File(path)
        if (!sourceFile.exists()) {
            throw IllegalStateException("변환할 HEIC 파일을 찾을 수 없습니다.")
        }

        val source = ImageDecoder.createSource(sourceFile)
        val bitmap = ImageDecoder.decodeBitmap(source)
        val outFile = File(cacheDir, "heic-${System.currentTimeMillis()}.png")
        FileOutputStream(outFile).use { stream ->
            if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)) {
                throw IllegalStateException("PNG로 저장하지 못했습니다.")
            }
        }
        return outFile.absolutePath
    }
}
