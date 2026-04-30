package com.example.life_os_app

import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.activity.ComponentActivity
import io.flutter.plugin.common.MethodChannel

class QuickCaptureShellActivity : ComponentActivity() {
    private lateinit var input: EditText
    private lateinit var primaryAction: Button
    private lateinit var secondaryAction: Button
    private lateinit var progress: ProgressBar
    private lateinit var status: TextView
    private lateinit var countChip: TextView
    private var sessionId: String? = null
    private var bufferedCount: Int = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_quick_capture_shell)

        input = findViewById(R.id.quick_capture_input)
        primaryAction = findViewById(R.id.quick_capture_submit)
        secondaryAction = findViewById(R.id.quick_capture_open_full)
        progress = findViewById(R.id.quick_capture_progress)
        status = findViewById(R.id.quick_capture_status)
        countChip = findViewById(R.id.quick_capture_count_chip)

        primaryAction.setOnClickListener { appendQuickCapture() }
        secondaryAction.setOnClickListener { processQuickCaptureBuffer() }
        input.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit
            override fun afterTextChanged(s: Editable?) {
                updateActionState()
            }
        })
        prepareQuickCaptureBuffer()
    }

    private fun prepareQuickCaptureBuffer() {
        setLoading(true, getString(R.string.quick_capture_buffer_preparing))
        val engine = FlutterEngineManager.prewarm(this)
        MethodChannel(
            engine.dartExecutor.binaryMessenger,
            "life_os_app/quick_capture_shell"
        ).invokeMethod(
            "prepareQuickCaptureBuffer",
            null,
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    val payload = result as? Map<*, *>
                    sessionId = payload?.get("session_id")?.toString()
                    bufferedCount = (payload?.get("item_count") as? Number)?.toInt() ?: 0
                    runOnUiThread {
                        updateCountChip(bufferedCount)
                        setLoading(false, bufferStatusText(bufferedCount))
                    }
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    runOnUiThread {
                        setLoading(false, errorMessage ?: getString(R.string.quick_capture_failed))
                    }
                }

                override fun notImplemented() {
                    runOnUiThread {
                        setLoading(false, getString(R.string.quick_capture_failed))
                    }
                }
            }
        )
    }

    private fun appendQuickCapture() {
        val rawText = input.text?.toString()?.trim().orEmpty()
        if (rawText.isBlank()) {
            Toast.makeText(this, R.string.quick_capture_empty_text, Toast.LENGTH_SHORT).show()
            return
        }
        setLoading(true, getString(R.string.quick_capture_buffering))
        val engine = FlutterEngineManager.prewarm(this)
        MethodChannel(
            engine.dartExecutor.binaryMessenger,
            "life_os_app/quick_capture_shell"
        ).invokeMethod(
            "appendQuickCaptureBuffer",
            mapOf(
                "rawText" to rawText,
                "sessionId" to sessionId,
                "source" to "native_shell",
                "entryPoint" to "quick_capture_shell",
                "routeHint" to CaptureLaunchIntents.ROUTE_CAPTURE_AI,
                "modeHint" to "ai"
            ),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    val payload = result as? Map<*, *>
                    sessionId = payload?.get("session_id")?.toString() ?: sessionId
                    bufferedCount = (payload?.get("item_count") as? Number)?.toInt() ?: bufferedCount
                    runOnUiThread {
                        input.setText("")
                        updateCountChip(bufferedCount)
                        Toast.makeText(
                            this@QuickCaptureShellActivity,
                            getString(R.string.quick_capture_buffered, bufferedCount),
                            Toast.LENGTH_SHORT
                        ).show()
                        setLoading(false, bufferStatusText(bufferedCount))
                    }
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    runOnUiThread {
                        setLoading(false, errorMessage ?: getString(R.string.quick_capture_failed))
                        openFullCapture(CaptureLaunchIntents.ROUTE_CAPTURE_AI, rawText)
                    }
                }

                override fun notImplemented() {
                    runOnUiThread {
                        setLoading(false, getString(R.string.quick_capture_failed))
                        openFullCapture(CaptureLaunchIntents.ROUTE_CAPTURE_AI, rawText)
                    }
                }
            }
        )
    }

    private fun processQuickCaptureBuffer() {
        val activeSessionId = sessionId
        if (activeSessionId.isNullOrBlank()) {
            Toast.makeText(this, R.string.quick_capture_no_buffer, Toast.LENGTH_SHORT).show()
            return
        }
        if (input.text?.toString()?.trim().isNullOrEmpty().not()) {
            appendQuickCaptureThenProcess(activeSessionId)
            return
        }
        setLoading(true, getString(R.string.quick_capture_processing))
        val engine = FlutterEngineManager.prewarm(this)
        MethodChannel(
            engine.dartExecutor.binaryMessenger,
            "life_os_app/quick_capture_shell"
        ).invokeMethod(
            "processQuickCaptureBuffer",
            mapOf("sessionId" to activeSessionId),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    val payload = result as? Map<*, *>
                    val statusValue = payload?.get("status")?.toString() ?: "needs_review"
                    val route =
                        payload?.get("route")?.toString() ?: CaptureLaunchIntents.ROUTE_CAPTURE_AI
                    runOnUiThread {
                        if (statusValue == "committed") {
                            Toast.makeText(
                                this@QuickCaptureShellActivity,
                                R.string.quick_capture_saved,
                                Toast.LENGTH_SHORT
                            ).show()
                            finish()
                        } else {
                            openFullCapture(route, "")
                        }
                    }
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    runOnUiThread {
                        setLoading(false, errorMessage ?: getString(R.string.quick_capture_failed))
                    }
                }

                override fun notImplemented() {
                    runOnUiThread {
                        setLoading(false, getString(R.string.quick_capture_failed))
                    }
                }
            }
        )
    }

    private fun appendQuickCaptureThenProcess(activeSessionId: String) {
        val rawText = input.text?.toString()?.trim().orEmpty()
        if (rawText.isBlank()) {
            processQuickCaptureBuffer()
            return
        }
        setLoading(true, getString(R.string.quick_capture_buffering))
        val engine = FlutterEngineManager.prewarm(this)
        MethodChannel(
            engine.dartExecutor.binaryMessenger,
            "life_os_app/quick_capture_shell"
        ).invokeMethod(
            "appendQuickCaptureBuffer",
            mapOf(
                "rawText" to rawText,
                "sessionId" to activeSessionId,
                "source" to "native_shell",
                "entryPoint" to "quick_capture_shell",
                "routeHint" to CaptureLaunchIntents.ROUTE_CAPTURE_AI,
                "modeHint" to "ai"
            ),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    val payload = result as? Map<*, *>
                    sessionId = payload?.get("session_id")?.toString() ?: sessionId
                    bufferedCount = (payload?.get("item_count") as? Number)?.toInt() ?: bufferedCount
                    runOnUiThread {
                        input.setText("")
                        updateCountChip(bufferedCount)
                        processQuickCaptureBuffer()
                    }
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    runOnUiThread {
                        setLoading(false, errorMessage ?: getString(R.string.quick_capture_failed))
                    }
                }

                override fun notImplemented() {
                    runOnUiThread {
                        setLoading(false, getString(R.string.quick_capture_failed))
                    }
                }
            }
        )
    }

    private fun openFullCapture(route: String, rawText: String) {
        setLoading(false, bufferStatusText(bufferedCount))
        val resolvedRoute = if (rawText.isBlank() || route.contains("text=")) {
            route
        } else {
            "$route&text=${android.net.Uri.encode(rawText)}"
        }
        startActivity(CaptureLaunchIntents.createActivityIntent(this, resolvedRoute))
        finish()
    }

    private fun setLoading(loading: Boolean, message: String) {
        progress.visibility = if (loading) View.VISIBLE else View.GONE
        input.isEnabled = !loading
        status.text = message
        updateActionState(loading)
    }

    private fun bufferStatusText(count: Int): String {
        return if (count <= 0) {
            getString(R.string.quick_capture_ready)
        } else {
            getString(R.string.quick_capture_buffer_status, count)
        }
    }

    private fun updateCountChip(count: Int) {
        countChip.text = if (count <= 0) {
            getString(R.string.quick_capture_buffer_count_zero)
        } else {
            getString(R.string.quick_capture_buffer_count_value, count)
        }
    }

    private fun updateActionState(loading: Boolean = progress.visibility == View.VISIBLE) {
        val hasDraftInput = input.text?.toString()?.trim().isNullOrEmpty().not()
        primaryAction.isEnabled = !loading
        secondaryAction.isEnabled = !loading && (bufferedCount > 0 || hasDraftInput)
        secondaryAction.alpha = if (secondaryAction.isEnabled) 1f else 0.55f
        primaryAction.alpha = if (primaryAction.isEnabled) 1f else 0.7f
    }
}
