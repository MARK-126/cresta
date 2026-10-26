package com.cresta.cresta

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Respuesta pendiente mientras el sistema muestra el diálogo de permiso
    private var pendingNotifications: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cresta/permissions")
            .setMethodCallHandler { call, result ->
                if (call.method == "requestNotifications") {
                    requestNotifications(result)
                } else {
                    result.notImplemented()
                }
            }
    }

    // Android 13+ exige pedir POST_NOTIFICATIONS en tiempo de ejecución;
    // sin él no se ve el aviso fijo mientras se graba el recorrido.
    private fun requestNotifications(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (pendingNotifications != null) {
            result.success(false)
            return
        }
        pendingNotifications = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_NOTIFICATIONS,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_NOTIFICATIONS) return
        pendingNotifications?.success(
            grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED,
        )
        pendingNotifications = null
    }

    companion object {
        private const val REQUEST_NOTIFICATIONS = 4711
    }
}
