package com.example.life_os_app

import android.os.Bundle
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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_quick_capture_shell)

        input = findViewById(R.id.quick_capture_input)
        primaryAction = findViewById(R.id.quick_capture_submit)
        secondaryAction = findViewById(R.id.quick_capture_open_full)
        progress = findViewById(R.id.quick_capture_progress)
        status = findViewById(R.id.quick_capture_status)

        primaryAction.setOnClickListener { submitQuickCapture() }
        secondaryAction.setOnClickListener {
            openFullCapture(
                CaptureLaunchIntents.ROUTE_CAPTURE_AI,
                input.text?.toString()?.trim().orEmpty()
            )
        }
    }

    private fun submitQuickCapture() {
        val rawText = input.text?.toString()?.trim().orEmpty()
        if (rawText.isBlank()) {
            Toast.makeText(this, R.string.quick_capture_empty_text, Toast.LENGTH_SHORT).show()
            return
        }
        setLoading(true, getString(R.string.quick_capture_submitting))
        val engine = FlutterEngineManager.prewarm(this)
        MethodChannel(
            engine.dartExecutor.binaryMessenger,
            "life_os_app/quick_capture_shell"
        ).invokeMethod(
            "submitQuickCapture",
            mapOf(
                "rawText" to rawText,
                "source" to "native_shell",
                "entryPoint" to "quick_capture_shell",
                "routeHint" to CaptureLaunchIntents.ROUTE_CAPTURE_AI,
                "modeHint" to "ai"
            ),
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
                            openFullCapture(route, rawText)
                        }
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

    private fun openFullCapture(route: String, rawText: String) {
        setLoading(false, getString(R.string.quick_capture_ready))
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
        primaryAction.isEnabled = !loading
        secondaryAction.isEnabled = !loading
        input.isEnabled = !loading
        status.text = message
    }
}
