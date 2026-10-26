package com.alejandrocruz.tuktukcontrol

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

internal object DriverFloatingShortcut {
    private const val CHANNEL =
        "com.alejandrocruz.tuktukcontrol/floating_shortcut"

    private var pendingOpenJobs = false
    private var flutterChannel: MethodChannel? = null

    fun register(activity: Activity, engine: FlutterEngine) {
        val channel = MethodChannel(
            engine.dartExecutor.binaryMessenger,
            CHANNEL
        )
        flutterChannel = channel

        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "canDraw" -> {
                        result.success(Settings.canDrawOverlays(activity))
                    }

                    "openPermission" -> {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION
                        ).apply {
                            data = android.net.Uri.parse(
                                "package:${activity.packageName}"
                            )
                        }
                        activity.startActivity(intent)
                        result.success(true)
                    }

                    "setVisible" -> {
                        val visible =
                            call.argument<Boolean>("visible") ?: false

                        val service = Intent(
                            activity,
                            DriverFloatingShortcutService::class.java
                        )

                        if (!visible) {
                            activity.stopService(service)
                            result.success(true)
                        } else if (!Settings.canDrawOverlays(activity)) {
                            result.success(false)
                        } else {
                            val count =
                                (call.argument<Int>("count") ?: 0)
                                    .coerceIn(0, 99)

                            service.putExtra("count", count)

                            if (Build.VERSION.SDK_INT >= 26) {
                                activity.startForegroundService(service)
                            } else {
                                activity.startService(service)
                            }

                            result.success(true)
                        }
                    }

                    "consumeOpenJobs" -> {
                        val requested = pendingOpenJobs ||
                            activity.intent?.getBooleanExtra(
                                "tuktuk_open_jobs",
                                false
                            ) == true

                        pendingOpenJobs = false
                        activity.intent?.removeExtra("tuktuk_open_jobs")
                        result.success(requested)
                    }

                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                result.success(false)
            }
        }
    }

    fun handleIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("tuktuk_open_jobs", false) == true) {
            pendingOpenJobs = true
            flutterChannel?.invokeMethod("openJobs", null)
        }
    }
}

class DriverFloatingShortcutService : Service() {
    companion object {
        private const val CHANNEL_ID = "tuktuk_boton_flotante"
        private const val NOTIFICATION_ID = 7091
    }

    private var manager: WindowManager? = null
    private var bubble: FrameLayout? = null
    private var badge: TextView? = null
    private var params: WindowManager.LayoutParams? = null

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()

        try {
            startPersistentNotification()

            if (!Settings.canDrawOverlays(this)) {
                stopSelf()
                return
            }

            createBubble()
        } catch (_: Exception) {
            stopSelf()
        }
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int
    ): Int {
        if (!Settings.canDrawOverlays(this)) {
            stopSelf()
            return START_NOT_STICKY
        }

        val count = intent?.getIntExtra("count", 0) ?: 0
        updateBadge(count.coerceIn(0, 99))

        return START_NOT_STICKY
    }

    private fun startPersistentNotification() {
        val nm = getSystemService(
            Context.NOTIFICATION_SERVICE
        ) as NotificationManager

        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Boton flotante TukTuk",
                    NotificationManager.IMPORTANCE_LOW
                )
            )
        }

        val open = Intent(this, MainActivity::class.java).apply {
            putExtra("tuktuk_open_jobs", true)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pending = PendingIntent.getActivity(
            this,
            7091,
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or
                PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }

        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_tuktuk)
            .setContentTitle("TukTuk Conductor")
            .setContentText("Acceso rapido a tus trabajos")
            .setContentIntent(pending)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createBubble() {
        val wm = getSystemService(
            Context.WINDOW_SERVICE
        ) as WindowManager

        manager = wm

        val size = dp(66)

        val root = FrameLayout(this)

        val background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.rgb(12, 34, 42))
            setStroke(dp(2), Color.rgb(45, 212, 163))
        }

        root.background = background

        val logo = ImageView(this).apply {
            setImageResource(R.mipmap.ic_launcher_round)
            scaleType = ImageView.ScaleType.FIT_CENTER
            setPadding(dp(4), dp(4), dp(4), dp(4))
        }

        root.addView(
            logo,
            FrameLayout.LayoutParams(size, size)
        )

        val counter = TextView(this).apply {
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            textSize = 11f

            this.background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.rgb(255, 150, 35))
            }

            visibility = View.GONE
        }

        root.addView(
            counter,
            FrameLayout.LayoutParams(
                dp(23),
                dp(23),
                Gravity.TOP or Gravity.END
            )
        )

        badge = counter

        val windowType = if (Build.VERSION.SDK_INT >= 26) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val lp = WindowManager.LayoutParams(
            size,
            size,
            windowType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = resources.displayMetrics.widthPixels - dp(85)
            y = dp(220)
        }

        params = lp

        var initialX = 0
        var initialY = 0
        var touchX = 0f
        var touchY = 0f
        var dragged = false

        root.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = lp.x
                    initialY = lp.y
                    touchX = event.rawX
                    touchY = event.rawY
                    dragged = false
                    true
                }

                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - touchX).toInt()
                    val dy = (event.rawY - touchY).toInt()

                    if (kotlin.math.abs(dx) > dp(7) ||
                        kotlin.math.abs(dy) > dp(7)) {
                        dragged = true
                    }

                    lp.x = (initialX + dx).coerceIn(
                        0,
                        resources.displayMetrics.widthPixels - size
                    )

                    lp.y = (initialY + dy).coerceIn(
                        0,
                        resources.displayMetrics.heightPixels - size
                    )

                    wm.updateViewLayout(root, lp)
                    true
                }

                MotionEvent.ACTION_UP -> {
                    if (!dragged) {
                        val open = Intent(
                            this,
                            MainActivity::class.java
                        ).apply {
                            putExtra("tuktuk_open_jobs", true)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                                Intent.FLAG_ACTIVITY_CLEAR_TOP
                        }

                        startActivity(open)
                    }

                    true
                }

                else -> false
            }
        }

        wm.addView(root, lp)
        bubble = root
    }

    private fun updateBadge(count: Int) {
        badge?.apply {
            text = if (count >= 99) "99+" else count.toString()
            visibility = if (count > 0) View.VISIBLE else View.GONE
        }
    }

    override fun onDestroy() {
        bubble?.let { view ->
            try {
                manager?.removeView(view)
            } catch (_: Exception) {
            }
        }

        bubble = null
        badge = null
        manager = null
        params = null

        super.onDestroy()
    }
}