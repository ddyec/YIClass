package com.ddyec.yiclass

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.Build
import android.os.ParcelFileDescriptor
import android.provider.Settings
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private var permissionResult: MethodChannel.Result? = null
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "yiclass/android").setMethodCallHandler { call, result ->
            when (call.method) {
                "sync" -> try {
                    val payload = call.arguments as String
                    getSharedPreferences("agenda", MODE_PRIVATE).edit().putString("snapshot", payload).apply()
                    PlatformAgenda.sync(this)
                    result.success(null)
                } catch (e: Exception) { result.error("SYNC", e.message, null) }
                "requestNotifications" -> {
                    if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        if (permissionResult != null) result.error("BUSY", "正在请求通知权限", null)
                        else { permissionResult = result; requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 330) }
                    } else result.success(null)
                }
                "openSettings" -> {
                    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                    result.success(null)
                }
                "recognize" -> {
                    val path = call.argument<String>("path")!!
                    val pdf = call.argument<Boolean>("pdf") == true
                    executor.execute {
                        try {
                            val recognizer = TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
                            val output = StringBuilder()
                            fun read(bitmap: Bitmap, page: Int) {
                                try {
                                    val text = Tasks.await(recognizer.process(InputImage.fromBitmap(bitmap, 0)), 60, TimeUnit.SECONDS)
                                    output.append("\n--- 第 ${page + 1} 页 ${bitmap.width}×${bitmap.height} ---\n")
                                    for (block in text.textBlocks) for (line in block.lines) {
                                        val box = line.boundingBox
                                        output.append("[${box?.left},${box?.top},${box?.right},${box?.bottom}] ${line.text}\n")
                                    }
                                } finally { bitmap.recycle() }
                            }
                            try {
                                if (pdf) {
                                    ParcelFileDescriptor.open(File(path), ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
                                        PdfRenderer(fd).use { renderer ->
                                            require(renderer.pageCount <= 20) { "PDF 最多支持 20 页，请拆分后导入" }
                                            for (index in 0 until renderer.pageCount) renderer.openPage(index).use { page ->
                                                val width = 2000
                                                val height = (page.height.toDouble() / page.width * width).toInt()
                                                require(height in 1..6000) { "页面尺寸过长，请裁剪后导入" }
                                                val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                                                bitmap.eraseColor(Color.WHITE)
                                                page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                                read(bitmap, index)
                                            }
                                        }
                                    }
                                } else {
                                    val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                                    BitmapFactory.decodeFile(path, options)
                                    require(options.outWidth > 0 && options.outHeight > 0) { "图片格式无法读取" }
                                    var sample = 1
                                    while (options.outWidth / sample > 2400 || options.outHeight / sample > 4000) sample *= 2
                                    val bitmap = BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
                                        ?: error("图片无法读取")
                                    read(bitmap, 0)
                                }
                            } finally { recognizer.close() }
                            runOnUiThread { result.success(output.toString()) }
                        } catch (e: Exception) { runOnUiThread { result.error("OCR", e.message, null) } }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 330) {
            if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) permissionResult?.success(null)
            else permissionResult?.error("PERMISSION", "通知权限未开启，可在系统设置中重新开启", null)
            permissionResult = null
        }
    }
    override fun onDestroy() { executor.shutdown(); super.onDestroy() }
}
