package com.spark.sales.call_log_android

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Registered with every Flutter engine, including the WorkManager background
 * engine, so periodic sync can read the call log without a foreground activity.
 */
class CallLogAndroidPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {
    private var channel: MethodChannel? = null
    private var appContext: Context? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingPermission: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var io: ExecutorService = Executors.newSingleThreadExecutor()

    @Volatile
    private var detached = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        detached = false
        if (io.isShutdown) {
            io = Executors.newSingleThreadExecutor()
        }
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        detached = true
        channel?.setMethodCallHandler(null)
        channel = null
        appContext = null
        io.shutdownNow()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        detachActivity()
    }

    private fun detachActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "permissionStatus" -> result.success(permissionStatus())
            "requestPermission" -> requestPermission(result)
            "openAppSettings" -> result.success(openAppSettings())
            "readCalls" -> readCalls(call, result)
            else -> result.notImplemented()
        }
    }

    private fun permissionStatus(): Map<String, Boolean> {
        val context = appContext
        val granted = context != null && hasPermission(context)
        val shouldShow = activity?.shouldShowRequestPermissionRationale(
            Manifest.permission.READ_CALL_LOG,
        ) == true
        return mapOf(
            "granted" to granted,
            "shouldShowRationale" to shouldShow,
        )
    }

    @Suppress("DEPRECATION")
    private fun requestPermission(result: MethodChannel.Result) {
        val context = appContext
        val host = activity
        if (context == null || host == null) {
            result.error(
                "activity_unavailable",
                "Call log permission can only be requested while the app is open.",
                null,
            )
            return
        }
        if (hasPermission(context)) {
            result.success(true)
            return
        }
        if (pendingPermission != null) {
            result.error(
                "permission_request_in_progress",
                "A permission request is already open.",
                null,
            )
            return
        }
        pendingPermission = result
        host.requestPermissions(arrayOf(Manifest.permission.READ_CALL_LOG), REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_CODE) {
            return false
        }
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        val pending = pendingPermission
        pendingPermission = null
        pending?.success(granted)
        return true
    }

    private fun openAppSettings(): Boolean {
        val context = activity ?: appContext ?: return false
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", context.packageName, null)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun readCalls(call: MethodCall, result: MethodChannel.Result) {
        val context = appContext
        if (context == null) {
            result.error("call_log_unavailable", "Application context is not available.", null)
            return
        }
        if (!hasPermission(context)) {
            result.error("permission_denied", "READ_CALL_LOG has not been granted.", null)
            return
        }
        val since = call.argument<Number>("sinceMillis")?.toLong() ?: 0L
        val limit = (call.argument<Number>("limit")?.toInt() ?: 2000).coerceIn(1, 5000)
        io.execute {
            try {
                val rows = CallLogChannel.read(context, since, limit)
                mainHandler.post {
                    if (!detached) {
                        result.success(rows)
                    }
                }
            } catch (error: SecurityException) {
                mainHandler.post {
                    if (!detached) {
                        result.error("permission_denied", error.message, null)
                    }
                }
            } catch (error: Exception) {
                mainHandler.post {
                    if (!detached) {
                        result.error("call_log_read_failed", error.message, null)
                    }
                }
            }
        }
    }

    private fun hasPermission(context: Context): Boolean {
        return context.checkSelfPermission(Manifest.permission.READ_CALL_LOG) ==
            PackageManager.PERMISSION_GRANTED
    }

    companion object {
        const val CHANNEL = "com.spark.sales/call_log"
        private const val REQUEST_CODE = 4816
    }
}
