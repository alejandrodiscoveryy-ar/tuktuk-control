package com.alejandrocruz.tuktukcontrol

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Read-only diagnosis plus explicit, user-initiated Android Settings intents.
 * Never silently changes a user's sound, notification, or DND preferences.
 */
internal object DriverAlertDiagnostics {
    private const val CHANNEL = "com.alejandrocruz.tuktukcontrol/driver_alerts"
    private const val JOB_CHANNEL = "tuktuk_nuevas_carreras_v1"

    fun register(activity: Activity, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "inspect" -> result.success(inspect(activity))
                    "openAppNotifications" -> result.success(openAppNotifications(activity))
                    "openJobChannel" -> result.success(openJobChannel(activity))
                    "openSoundSettings" -> result.success(openSettings(activity, Intent(Settings.ACTION_SOUND_SETTINGS)))
                    "openLocationSettings" -> result.success(openSettings(activity, Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)))
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                // An unavailable settings screen must not crash the driver's app.
                result.success(false)
            }
        }
    }

    private fun inspect(activity: Activity): Map<String, Any> {
        val notifications = activity.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val audio = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val permissionGranted = Build.VERSION.SDK_INT < 33 ||
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        val appNotifications = permissionGranted && notifications.areNotificationsEnabled()
        val channel = if (Build.VERSION.SDK_INT >= 26) notifications.getNotificationChannel(JOB_CHANNEL) else null
        val channelPresent = Build.VERSION.SDK_INT < 26 || channel != null
        val channelImportance = if (Build.VERSION.SDK_INT >= 26) channel?.importance ?: 0 else 4
        val channelHasSound = Build.VERSION.SDK_INT < 26 || channel?.sound != null
        val volume = audio.getStreamVolume(AudioManager.STREAM_NOTIFICATION)
        val maxVolume = audio.getStreamMaxVolume(AudioManager.STREAM_NOTIFICATION)
        val normalRinger = audio.ringerMode == AudioManager.RINGER_MODE_NORMAL
        val dndAllows = notifications.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_ALL
        return mapOf(
            "appNotifications" to appNotifications,
            "channelPresent" to channelPresent,
            "channelImportance" to channelImportance,
            "channelHasSound" to channelHasSound,
            "notificationVolume" to volume,
            "notificationMaxVolume" to maxVolume,
            "normalRinger" to normalRinger,
            "dndAllows" to dndAllows,
        )
    }

    private fun openAppNotifications(activity: Activity): Boolean {
        if (Build.VERSION.SDK_INT >= 26) {
            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
            if (openSettings(activity, intent)) return true
        }
        return openAppDetails(activity)
    }

    private fun openJobChannel(activity: Activity): Boolean {
        if (Build.VERSION.SDK_INT >= 26) {
            val intent = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
                .putExtra(Settings.EXTRA_CHANNEL_ID, JOB_CHANNEL)
            if (openSettings(activity, intent)) return true
        }
        return openAppNotifications(activity)
    }

    private fun openAppDetails(activity: Activity): Boolean = openSettings(
        activity,
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = android.net.Uri.parse("package:${activity.packageName}")
        },
    )

    private fun openSettings(activity: Activity, intent: Intent): Boolean = try {
        activity.startActivity(intent)
        true
    } catch (_: Exception) {
        false
    }
}
