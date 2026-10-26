package com.alejandrocruz.tuktukcontrol

import android.animation.ObjectAnimator
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
import android.os.Handler
import android.os.IBinder
import android.os.Looper
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
    private var hostVisible = true

    fun hostVisibilityChanged(visible: Boolean) {
        hostVisible = visible
        DriverFloatingShortcutService.updateOverlayVisibility(!visible)
    }

    fun hostIsVisible(): Boolean = hostVisible

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
                            service.putExtra(
                                "attention",
                                call.argument<Boolean>("attention") ?: false
                            )

                            if (Build.VERSION.SDK_INT >= 26) {
                                activity.startForegroundService(service)
                            } else {
                                activity.startService(service)
                            }

                            result.success(true)
                        }
                    }

                    "acknowledgeJobs" -> {
                        DriverFloatingShortcutService.acknowledgeCurrentJobs()
                        result.success(true)
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
        private var activeService: DriverFloatingShortcutService? = null

        fun updateOverlayVisibility(shouldShow: Boolean) {
            activeService?.setBubbleVisible(shouldShow)
        }

        fun acknowledgeCurrentJobs() {
            activeService?.acknowledgeCurrentJobs()
        }
    }

    private var manager: WindowManager? = null
    private var bubble: FrameLayout? = null
    private var badge: TextView? = null
    private var haloView: View? = null
    private var haloDrawable: GradientDrawable? = null
    private var haloPulse: ObjectAnimator? = null
    private var latestCount = 0
    private var nativeJobNotificationCount = 0
    private val acknowledgedNotificationKeys = mutableSetOf<String>()
    private var previousUnseenNotificationKeys = emptySet<String>()
    private var needsAttention = false
    private var haloHadNewJob = false
    private var params: WindowManager.LayoutParams? = null

    private val handler = Handler(Looper.getMainLooper())
    private val checkNotifications = object : Runnable {
        override fun run() {
            if (bubble == null) return
            inspectOwnJobNotifications()
            handler.postDelayed(this, 4_000L)
        }
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()

        try {
            activeService = this
            startPersistentNotification()

            if (!Settings.canDrawOverlays(this)) {
                stopSelf()
                return
            }

            setBubbleVisible(!DriverFloatingShortcut.hostIsVisible())
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

        latestCount = (intent?.getIntExtra("count", 0) ?: 0)
            .coerceIn(0, 99)
        needsAttention = intent?.getBooleanExtra("attention", false) ?: needsAttention

        setBubbleVisible(!DriverFloatingShortcut.hostIsVisible())
        updateHaloColor()
        updateBadge(maxOf(latestCount, nativeJobNotificationCount))

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

    private fun setBubbleVisible(visible: Boolean) {
        if (visible && Settings.canDrawOverlays(this)) {
            if (bubble == null) createBubble()
            handler.removeCallbacks(checkNotifications)
            inspectOwnJobNotifications()
            handler.postDelayed(checkNotifications, 4_000L)
        } else {
            removeBubble()
        }
    }

    // La clave y fecha de publicacion diferencian una segunda carrera de
    // una notificacion antigua que Android todavia conserva en el panel.
    private fun currentJobNotificationKeys(): Set<String> {
        if (Build.VERSION.SDK_INT < 26) return emptySet()
        return try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.activeNotifications.filter { item ->
                val channelId = item.notification.channelId
                channelId == "tuktuk_nuevas_carreras_v1" ||
                    channelId == "tuktuk_nuevas_carreras_v2"
            }.map { item -> "${item.key}:${item.postTime}" }.toSet()
        } catch (_: Exception) {
            emptySet()
        }
    }

    // El conductor abre Trabajos: deja de avisar sobre esos mensajes,
    // aunque permanezcan en la cortina de notificaciones de Android.
    private fun acknowledgeCurrentJobs() {
        acknowledgedNotificationKeys.addAll(currentJobNotificationKeys())
        nativeJobNotificationCount = 0
        previousUnseenNotificationKeys = emptySet()
        needsAttention = false
        updateHaloColor()
        updateBadge(latestCount)
    }

    // Sin permiso adicional ni consultas de red; solo avisos de esta app.
    private fun inspectOwnJobNotifications() {
        val current = currentJobNotificationKeys()
        acknowledgedNotificationKeys.retainAll(current)
        val unseen = current - acknowledgedNotificationKeys
        val anotherNewJob = (unseen - previousUnseenNotificationKeys).isNotEmpty()
        previousUnseenNotificationKeys = unseen
        nativeJobNotificationCount = unseen.size
        updateHaloColor(anotherNewJob)
        updateBadge(maxOf(latestCount, nativeJobNotificationCount))
    }

    private fun updateHaloColor(anotherNewJob: Boolean = false) {
        val hasNewJob = needsAttention || nativeJobNotificationCount > 0
        val ringColor = when {
            hasNewJob -> Color.rgb(255, 107, 75)  // Coral: nueva carrera sin revisar.
            latestCount > 0 -> Color.rgb(255, 195, 76) // Dorado: hay carreras.
            else -> Color.rgb(48, 217, 200) // Turquesa: disponible, sin avisos.
        }
        haloDrawable?.setStroke(dp(3), ringColor)
        haloView?.invalidate()

        if (hasNewJob && (anotherNewJob || !haloHadNewJob)) {
            val ring = haloView
            if (ring != null) {
                haloPulse?.cancel()
                haloPulse = ObjectAnimator.ofFloat(
                    ring, View.ALPHA, 1f, 0.55f, 1f
                ).apply {
                    duration = 950L
                    repeatCount = 2
                    start()
                }
            }
        } else if (!hasNewJob) {
            haloPulse?.cancel()
            haloView?.alpha = 1f
        }
        haloHadNewJob = hasNewJob
    }

    private fun removeBubble() {
        handler.removeCallbacks(checkNotifications)
        haloPulse?.cancel()
        haloPulse = null
        haloView = null
        haloDrawable = null
        haloHadNewJob = false
        bubble?.let { view ->
            try {
                manager?.removeView(view)
            } catch (_: Exception) {
            }
        }

        bubble = null
        badge = null
    }

    private fun createBubble() {
        val wm = getSystemService(
            Context.WINDOW_SERVICE
        ) as WindowManager

        manager = wm

        val size = dp(70)

        val root = FrameLayout(this)
        root.background = null

        val ringBackground = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.rgb(12, 38, 48))
            setStroke(dp(3), Color.rgb(48, 217, 200))
        }
        val ring = View(this).apply {
            background = ringBackground
            elevation = dp(2).toFloat()
        }
        root.addView(ring, FrameLayout.LayoutParams(size, size))
        haloView = ring
        haloDrawable = ringBackground

        val logo = ImageView(this).apply {
            elevation = dp(3).toFloat()
            setImageResource(R.mipmap.ic_launcher_round)
            scaleType = ImageView.ScaleType.CENTER_CROP
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.rgb(12, 38, 48))
            }
            clipToOutline = true
            setPadding(0, 0, 0, 0)
        }

        root.addView(
            logo,
            FrameLayout.LayoutParams(
                size - dp(10), size - dp(10), Gravity.CENTER
            )
        )

        val counter = TextView(this).apply {
            elevation = dp(4).toFloat()
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
        if (activeService === this) activeService = null

        removeBubble()
        manager = null
        params = null

        super.onDestroy()
    }
}