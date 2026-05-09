package expenses.tracker

import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val DEEP_LINK_CHANNEL = "expenses.tracker/deeplink"
    private val PENDING_CHANNEL = "expenses.tracker/pending"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Deep link channel
        handleIntent(intent, flutterEngine)

        // Pending transactions channel (for Quick Add native dialog)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PENDING_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPending" -> {
                        val prefs = getSharedPreferences("pending_transactions", Context.MODE_PRIVATE)
                        val count = prefs.getInt("count", 0)
                        if (count == 0) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        val map = mutableMapOf<String, Any?>()
                        map["count"] = count
                        for (i in 1..count) {
                            map["txn_${i}_type"] = prefs.getString("txn_${i}_type", "expense")
                            map["txn_${i}_amount"] = prefs.getString("txn_${i}_amount", "0")
                            map["txn_${i}_category"] = prefs.getString("txn_${i}_category", "Other")
                            map["txn_${i}_note"] = prefs.getString("txn_${i}_note", "")
                            map["txn_${i}_date"] = prefs.getString("txn_${i}_date", "")
                        }
                        result.success(map)
                    }
                    "clearPending" -> {
                        val prefs = getSharedPreferences("pending_transactions", Context.MODE_PRIVATE)
                        prefs.edit().clear().apply()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        flutterEngine?.let { handleIntent(intent, it) }
    }

    private fun handleIntent(intent: Intent, engine: FlutterEngine) {
        val uri = intent.data?.toString()
        if (uri != null && uri.startsWith("expensestracker://")) {
            MethodChannel(engine.dartExecutor.binaryMessenger, DEEP_LINK_CHANNEL)
                .invokeMethod("onDeepLink", uri)
            intent.data = null
        }
    }
}
