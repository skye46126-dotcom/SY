package com.example.life_os_app

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

class MainActivity : FlutterActivity() {
    private var launchChannel: MethodChannel? = null
    private var pendingLaunchRoute: String? = null
    private var pendingImagePickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingLaunchRoute = extractLaunchRoute(intent)
        launchChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "life_os_app/launch"
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeLaunchRoute" -> {
                        result.success(pendingLaunchRoute)
                        pendingLaunchRoute = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "life_os_app/image_picker"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickImage" -> pickImage(result)
                "savePngToGallery" -> savePngToGallery(call.arguments, result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "life_os_app/share_panel"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "shareFile" -> shareFile(call.arguments, result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val launchRoute = extractLaunchRoute(intent) ?: return
        pendingLaunchRoute = launchRoute
        launchChannel?.invokeMethod("launchRoute", launchRoute)
    }

    private fun pickImage(result: MethodChannel.Result) {
        if (pendingImagePickResult != null) {
            result.error("busy", "Image picker is already open.", null)
            return
        }

        pendingImagePickResult = result
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Intent(MediaStore.ACTION_PICK_IMAGES).apply {
                type = "image/*"
            }
        } else {
            Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI).apply {
                type = "image/*"
            }
        }
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

        try {
            startActivityForResult(intent, REQUEST_PICK_IMAGE)
        } catch (_: ActivityNotFoundException) {
            val fallback = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "image/*"
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            try {
                startActivityForResult(fallback, REQUEST_PICK_IMAGE)
            } catch (error: ActivityNotFoundException) {
                pendingImagePickResult = null
                result.error("no_picker", "No image picker is available.", error.message)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_PICK_IMAGE) return

        val result = pendingImagePickResult
        pendingImagePickResult = null
        if (result == null) return

        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }

        val uri = data?.data
        if (uri == null) {
            result.error("missing_uri", "Image picker did not return a URI.", null)
            return
        }

        try {
            result.success(copyPickedImage(uri))
        } catch (error: Exception) {
            result.error("copy_failed", "Failed to copy picked image.", error.message)
        }
    }

    private fun copyPickedImage(uri: Uri): String {
        val mimeType = contentResolver.getType(uri)
        val extension = MimeTypeMap.getSingleton()
            .getExtensionFromMimeType(mimeType)
            ?.takeIf { it.isNotBlank() }
            ?: "jpg"
        val directory = File(cacheDir, "poster_covers")
        directory.mkdirs()
        val output = File(directory, "cover_${UUID.randomUUID()}.$extension")
        contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "Unable to open selected image." }
            output.outputStream().use { stream ->
                input.copyTo(stream)
            }
        }
        return output.absolutePath
    }

    private fun savePngToGallery(arguments: Any?, result: MethodChannel.Result) {
        val payload = arguments as? Map<*, *>
        val bytes = payload?.get("bytes") as? ByteArray
        val rawFileName = payload?.get("fileName") as? String
        if (bytes == null || bytes.isEmpty()) {
            result.error("missing_bytes", "PNG bytes are required.", null)
            return
        }

        val fileName = sanitizePngFileName(rawFileName)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                result.success(savePngWithMediaStore(bytes, fileName))
            } else {
                result.success(savePngToPublicPictures(bytes, fileName))
            }
        } catch (error: Exception) {
            result.error("save_failed", "Failed to save image to gallery.", error.message)
        }
    }

    private fun savePngWithMediaStore(bytes: ByteArray, fileName: String): Map<String, String> {
        val resolver = contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/SkyOS")
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("Unable to create gallery image entry.")
        resolver.openOutputStream(uri).use { stream ->
            requireNotNull(stream) { "Unable to open gallery image stream." }
            stream.write(bytes)
        }
        values.clear()
        values.put(MediaStore.Images.Media.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
        return mapOf(
            "uri" to uri.toString(),
            "album" to "SkyOS",
            "displayPath" to "Pictures/SkyOS/$fileName"
        )
    }

    private fun savePngToPublicPictures(bytes: ByteArray, fileName: String): Map<String, String> {
        val directory = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
            "SkyOS"
        )
        directory.mkdirs()
        val output = File(directory, fileName)
        output.writeBytes(bytes)
        MediaScannerConnection.scanFile(
            this,
            arrayOf(output.absolutePath),
            arrayOf("image/png"),
            null
        )
        return mapOf(
            "uri" to Uri.fromFile(output).toString(),
            "album" to "SkyOS",
            "displayPath" to output.absolutePath
        )
    }

    private fun sanitizePngFileName(raw: String?): String {
        val baseName = raw
            ?.trim()
            ?.replace(Regex("[^A-Za-z0-9_\\-\\.]+"), "_")
            ?.takeIf { it.isNotEmpty() }
            ?: "skyos_export.png"
        return if (baseName.lowercase().endsWith(".png")) baseName else "$baseName.png"
    }

    private fun shareFile(arguments: Any?, result: MethodChannel.Result) {
        val payload = arguments as? Map<*, *>
        val filePath = payload?.get("filePath") as? String
        val mimeType = (payload?.get("mimeType") as? String)
            ?.takeIf { it.isNotBlank() }
            ?: "application/octet-stream"
        val title = (payload?.get("title") as? String)
            ?.takeIf { it.isNotBlank() }
            ?: "分享导出文件"
        val text = payload?.get("text") as? String
        if (filePath.isNullOrBlank()) {
            result.error("missing_file_path", "Share filePath is required.", null)
            return
        }
        val file = File(filePath)
        if (!file.exists() || !file.isFile) {
            result.error("missing_file", "Share file does not exist.", filePath)
            return
        }

        try {
            val uri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                file
            )
            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                type = mimeType
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_TITLE, title)
                if (!text.isNullOrBlank()) {
                    putExtra(Intent.EXTRA_TEXT, text)
                }
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            val chooser = Intent.createChooser(shareIntent, title)
            chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            startActivity(chooser)
            result.success(true)
        } catch (error: Exception) {
            result.error("share_failed", "Failed to open share panel.", error.message)
        }
    }

    private fun extractLaunchRoute(intent: Intent?): String? {
        if (intent == null) {
            return null
        }
        intent.getStringExtra("target_route")
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?.let { return it }
        return deepLinkToRoute(intent.data)
    }

    private fun deepLinkToRoute(uri: Uri?): String? {
        if (uri == null || uri.scheme != "skyeos") {
            return null
        }
        val target = uri.host
            ?.takeIf { it.isNotBlank() }
            ?: uri.pathSegments.firstOrNull()
            ?: return null
        val query = uri.query
            ?.takeIf { it.isNotBlank() }
            ?.let { "?$it" }
            ?: ""
        return when (target.lowercase()) {
            "capture" -> "/capture$query"
            "today" -> "/today$query"
            "management" -> "/management$query"
            "review" -> "/review$query"
            else -> null
        }
    }

    companion object {
        private const val REQUEST_PICK_IMAGE = 4108
    }
}
