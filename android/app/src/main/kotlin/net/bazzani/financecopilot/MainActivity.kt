package net.bazzani.financecopilot

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/build_info")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "get" -> {
                        try {
                            val content = applicationContext.assets
                                .open("build_info.txt")
                                .bufferedReader()
                                .use { it.readText() }
                            result.success(content.trim())
                        } catch (_: IOException) {
                            result.success("")
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
