package com.example.life_os_app

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ShortcutInfo
import android.graphics.drawable.Icon
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.webkit.MimeTypeMap
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale
import java.util.UUID

open class BaseFlutterHostActivity : FlutterActivity() {
    private var launchChannel: MethodChannel? = null
    private var pendingLaunchRoute: String? = null
    private var pendingImagePickResult: MethodChannel.Result? = null
    private var pendingVoiceCaptureResult: MethodChannel.Result? = null
    private var pendingVoiceCapturePrompt: String? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var launchRouteDispatched = false

    protected open val publishesDynamicShortcuts: Boolean = false
    protected open val fallbackRoute: String? = null

    override fun provideFlutterEngine(context: android.content.Context): FlutterEngine {
        return FlutterEngineManager.prewarm(context)
    }

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingLaunchRoute = CaptureLaunchIntents.extractRoute(intent) ?: fallbackRoute
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (publishesDynamicShortcuts) {
            publishDynamicShortcuts()
        }
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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "life_os_app/voice_capture"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVoiceCapture" -> startVoiceCapture(call.arguments, result)
                else -> result.notImplemented()
            }
        }
        dispatchPendingLaunchRoute()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val launchRoute = CaptureLaunchIntents.extractRoute(intent) ?: fallbackRoute ?: return
        pendingLaunchRoute = launchRoute
        launchRouteDispatched = false
        dispatchPendingLaunchRoute()
    }

    override fun onPostResume() {
        super.onPostResume()
        dispatchPendingLaunchRoute()
    }

    override fun onDestroy() {
        speechRecognizer?.destroy()
        speechRecognizer = null
        super.onDestroy()
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

    private fun startVoiceCapture(arguments: Any?, result: MethodChannel.Result) {
        if (pendingVoiceCaptureResult != null) {
            result.error("busy", "Voice capture is already active.", null)
            return
        }
        val prompt = (arguments as? Map<*, *>)?.get("prompt") as? String
        pendingVoiceCaptureResult = result
        pendingVoiceCapturePrompt = prompt
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.RECORD_AUDIO),
                REQUEST_RECORD_AUDIO_PERMISSION
            )
            return
        }
        startSpeechRecognizer(prompt)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_RECORD_AUDIO_PERMISSION) {
            return
        }
        val result = pendingVoiceCaptureResult ?: return
        if (grantResults.isEmpty() || grantResults[0] != PackageManager.PERMISSION_GRANTED) {
            pendingVoiceCaptureResult = null
            pendingVoiceCapturePrompt = null
            result.error("permission_denied", "Microphone permission was denied.", null)
            return
        }
        startSpeechRecognizer(pendingVoiceCapturePrompt)
    }

    private fun startSpeechRecognizer(prompt: String?) {
        val result = pendingVoiceCaptureResult ?: return
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            pendingVoiceCaptureResult = null
            pendingVoiceCapturePrompt = null
            result.error("no_recognizer", "Speech recognition is not available.", null)
            return
        }

        speechRecognizer?.destroy()
        val serviceComponent =
            Settings.Secure.getString(contentResolver, "voice_recognition_service")
                ?.takeIf { it.isNotBlank() }
                ?.let { ComponentName.unflattenFromString(it) }
        speechRecognizer = if (serviceComponent != null) {
            SpeechRecognizer.createSpeechRecognizer(this, serviceComponent)
        } else {
            SpeechRecognizer.createSpeechRecognizer(this)
        }
        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) = Unit
            override fun onBeginningOfSpeech() = Unit
            override fun onRmsChanged(rmsdB: Float) = Unit
            override fun onBufferReceived(buffer: ByteArray?) = Unit
            override fun onEndOfSpeech() = Unit
            override fun onPartialResults(partialResults: Bundle?) = Unit
            override fun onEvent(eventType: Int, params: Bundle?) = Unit

            override fun onError(error: Int) {
                val callback = pendingVoiceCaptureResult
                pendingVoiceCaptureResult = null
                pendingVoiceCapturePrompt = null
                callback?.error(
                    "voice_capture_error",
                    "Speech recognition failed with error code $error.",
                    error
                )
            }

            override fun onResults(results: Bundle?) {
                val callback = pendingVoiceCaptureResult
                pendingVoiceCaptureResult = null
                pendingVoiceCapturePrompt = null
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                callback?.success(matches?.firstOrNull())
            }
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
            if (!prompt.isNullOrBlank()) {
                putExtra(RecognizerIntent.EXTRA_PROMPT, prompt)
            }
        }
        try {
            speechRecognizer?.startListening(intent)
        } catch (error: Exception) {
            pendingVoiceCaptureResult = null
            pendingVoiceCapturePrompt = null
            result.error("voice_capture_failed", "Failed to start speech recognizer.", error.message)
        }
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
        if (!file.exists() || !file.isFile()) {
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

    private fun publishDynamicShortcuts() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) {
            return
        }
        val shortcutManager = getSystemService(android.content.pm.ShortcutManager::class.java)
            ?: return
        val shortcuts = listOf(
            ShortcutInfo.Builder(this, "capture_ai_dynamic")
                .setShortLabel(getString(R.string.shortcut_capture_ai_short))
                .setLongLabel(getString(R.string.shortcut_capture_ai_long))
                .setIcon(Icon.createWithResource(this, R.mipmap.ic_launcher))
                .setIntent(CaptureLaunchIntents.createActivityIntent(this, CaptureLaunchIntents.ROUTE_CAPTURE_SHELL))
                .build(),
            ShortcutInfo.Builder(this, "capture_time_dynamic")
                .setShortLabel(getString(R.string.shortcut_capture_time_short))
                .setLongLabel(getString(R.string.shortcut_capture_time_long))
                .setIcon(Icon.createWithResource(this, R.mipmap.ic_launcher))
                .setIntent(CaptureLaunchIntents.createActivityIntent(this, CaptureLaunchIntents.ROUTE_CAPTURE_TIME))
                .build(),
            ShortcutInfo.Builder(this, "capture_learning_dynamic")
                .setShortLabel(getString(R.string.shortcut_capture_learning_short))
                .setLongLabel(getString(R.string.shortcut_capture_learning_long))
                .setIcon(Icon.createWithResource(this, R.mipmap.ic_launcher))
                .setIntent(CaptureLaunchIntents.createActivityIntent(this, CaptureLaunchIntents.ROUTE_CAPTURE_LEARNING))
                .build()
        )
        shortcutManager.dynamicShortcuts = shortcuts
    }

    private fun dispatchPendingLaunchRoute() {
        val route = pendingLaunchRoute ?: return
        if (launchRouteDispatched) {
            return
        }
        launchRouteDispatched = true
        window?.decorView?.post {
            launchChannel?.invokeMethod("launchRoute", route)
        }
    }

    companion object {
        private const val REQUEST_PICK_IMAGE = 4108
        private const val REQUEST_RECORD_AUDIO_PERMISSION = 4110
    }
}
