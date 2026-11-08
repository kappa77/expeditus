package com.kappa77.expeditus

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.kappa77.expeditus/multicast",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquire" -> {
                    acquireMulticastLock()
                    result.success(true)
                }

                "release" -> {
                    releaseMulticastLock()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "expeditus/downloads",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    requestNotificationPermission()
                    val intent = Intent(this, DownloadService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }

                "stop" -> {
                    stopService(Intent(this, DownloadService::class.java))
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun acquireMulticastLock() {
        val lock = multicastLock
        if (lock != null && lock.isHeld) return
        try {
            val wifiManager =
                applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val newLock = wifiManager.createMulticastLock("expeditus_dlna").apply {
                setReferenceCounted(false)
                acquire()
            }
            multicastLock = newLock
        } catch (_: Exception) {
            // Some devices or emulators do not expose a usable WifiManager.
        }
    }

    private fun releaseMulticastLock() {
        val lock = multicastLock ?: return
        try {
            if (lock.isHeld) lock.release()
        } catch (_: Exception) {
            // Best effort.
        }
        multicastLock = null
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST,
            )
        }
    }

    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST = 4101
    }
}
