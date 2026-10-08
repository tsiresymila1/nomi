package com.example.gena

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class DocumentProcessingForegroundService : Service() {
    companion object {
        const val ACTION_START = "com.example.gena.document_processing.START"
        const val ACTION_UPDATE = "com.example.gena.document_processing.UPDATE"
        const val EXTRA_DOCUMENT_NAME = "document_name"
        const val EXTRA_PHASE = "phase"

        private const val CHANNEL_ID = "nomi_document_processing"
        private const val NOTIFICATION_ID = 2473
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val documentName = intent?.getStringExtra(EXTRA_DOCUMENT_NAME)
            ?.takeIf { it.isNotBlank() }
            ?: "Document"
        val phase = intent?.getStringExtra(EXTRA_PHASE)
            ?.takeIf { it.isNotBlank() }
            ?: "Preparing for private search"

        startForeground(NOTIFICATION_ID, buildNotification(documentName, phase))
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Document processing",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Progress while Nomi prepares documents for private search"
            setShowBadge(false)
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(documentName: String, phase: String) =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("Nomi · Document processing")
            .setContentText("$phase · $documentName")
            .setStyle(
                NotificationCompat.BigTextStyle().bigText("$phase · $documentName")
            )
            .setContentIntent(openAppPendingIntent())
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setProgress(0, 0, true)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()

    private fun openAppPendingIntent(): PendingIntent {
        val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        } ?: Intent(this, MainActivity::class.java)
        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
