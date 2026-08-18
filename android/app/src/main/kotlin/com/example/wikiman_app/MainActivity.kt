package com.example.wikiman_app

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val heicChannelName = "com.example.wikiman_app/heic"
    private val updateChannelName = "com.example.wikiman_app/update"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, heicChannelName)
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updateChannelName)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getVersionName" -> result.success(currentVersionName())
                        "canInstallPackages" -> result.success(canInstallPackages())
                        "openInstallSettings" -> {
                            openInstallSettings()
                            result.success(null)
                        }
                        "installApk" -> {
                            val path = call.argument<String>("path")
                            if (path.isNullOrBlank()) {
                                result.error("INVALID_PATH", "설치할 파일 경로가 없습니다.", null)
                                return@setMethodCallHandler
                            }
                            installApk(path)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error(
                        "UPDATE_FAILED",
                        error.message ?: "앱 업데이트를 진행하지 못했습니다.",
                        null,
                    )
                }
            }
    }

    private fun currentVersionName(): String {
        val info = packageManager.getPackageInfo(packageName, 0)
        return info.versionName ?: ""
    }

    private fun canInstallPackages(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun openInstallSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
            data = Uri.parse("package:$packageName")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun installApk(path: String) {
        val file = File(path)
        if (!file.exists()) {
            throw IllegalStateException("설치할 APK를 찾을 수 없습니다.")
        }
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
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
