package com.example.frontend

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.annotation.NonNull

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.doculens.ai/local"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "extract") {
                val text = call.argument<String>("text")
                val imagePath = call.argument<String>("imagePath")
                
                // TODO: Initialize MediaPipe/ExecuTorch local AI model here
                // For now, return an error indicating local model isn't loaded,
                // so the Flutter app knows to fallback to Cloud Gemini
                result.error("UNAVAILABLE", "Local AI model not initialized", null)
            } else {
                result.notImplemented()
            }
        }
    }
}
