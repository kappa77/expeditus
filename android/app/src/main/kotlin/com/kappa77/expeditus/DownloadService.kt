package com.kappa77.expeditus

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder

/**
 * Keeps the app process alive while a Dart video download is running.
 * The download itself is performed by the Flutter side.
 */
class DownloadService : Service() {
    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification())
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("Download in corso")
            .setContentText("Expeditus sta salvando un video in locale.")
            .setOngoing(true)
            .setPriority(Notification.PRIORITY_LOW)
            .setCategory(Notification.CATEGORY_PROGRESS)
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Download",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Download dei video offline"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    companion object {
        private const val CHANNEL_ID = "expeditus_downloads"
        private const val NOTIFICATION_ID = 4101
    }
}
