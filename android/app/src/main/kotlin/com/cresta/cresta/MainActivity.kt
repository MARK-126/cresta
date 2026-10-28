package com.cresta.cresta

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cresta/notify")
            .setMethodCallHandler { call, result ->
                val id = call.argument<Int>("id") ?: 0
                when (call.method) {
                    "show" -> {
                        showAlert(
                            id,
                            call.argument<String>("title") ?: "",
                            call.argument<String>("body") ?: "",
                        )
                        result.success(null)
                    }
                    "cancel" -> {
                        getSystemService(NotificationManager::class.java).cancel(id)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Aviso de la hora límite de regreso: canal de importancia alta (suena y sale encima de
    // otras apps); al tocarlo vuelve a la app.
    private fun showAlert(id: Int, title: String, body: String) {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    ALERT_CHANNEL,
                    "Hora límite de regreso",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply { description = "Avisos de tu hora límite mientras grabas un recorrido" },
            )
        }
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        manager.notify(
            id,
            NotificationCompat.Builder(this, ALERT_CHANNEL)
                .setSmallIcon(applicationInfo.icon)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setAutoCancel(true)
                .setContentIntent(open)
                .build(),
        )
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
        private const val ALERT_CHANNEL = "cresta_alerts"
    }
}
