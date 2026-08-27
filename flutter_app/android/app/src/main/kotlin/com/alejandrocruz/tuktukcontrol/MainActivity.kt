package com.alejandrocruz.tuktukcontrol

import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    companion object {
        private const val REFERRAL_CHANNEL = "com.alejandrocruz.tuktukcontrol/referrals"
        private const val GET_INSTALL_REFERRER = "getInstallReferrer"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            REFERRAL_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method == GET_INSTALL_REFERRER) {
                readInstallReferrer(result)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun readInstallReferrer(result: MethodChannel.Result) {
        val client = try {
            InstallReferrerClient.newBuilder(this).build()
        } catch (_: Exception) {
            result.success(mapOf("status" to "platform_error"))
            return
        }
        val completed = AtomicBoolean(false)

        fun complete(status: String, installReferrer: String? = null) {
            if (!completed.compareAndSet(false, true)) return
            try {
                val payload = mutableMapOf<String, Any?>("status" to status)
                if (installReferrer != null) {
                    payload["installReferrer"] = installReferrer
                }
                result.success(payload)
            } finally {
                try {
                    client.endConnection()
                } catch (_: Exception) {
                    // Google Play may already have disconnected the service.
                }
            }
        }

        try {
            client.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(responseCode: Int) {
                    when (responseCode) {
                        InstallReferrerClient.InstallReferrerResponse.OK -> {
                            try {
                                complete("ok", client.installReferrer.installReferrer)
                            } catch (_: Exception) {
                                complete("platform_error")
                            }
                        }
                        InstallReferrerClient.InstallReferrerResponse.FEATURE_NOT_SUPPORTED ->
                            complete("feature_not_supported")
                        InstallReferrerClient.InstallReferrerResponse.SERVICE_UNAVAILABLE ->
                            complete("service_unavailable")
                        InstallReferrerClient.InstallReferrerResponse.SERVICE_DISCONNECTED ->
                            complete("service_disconnected")
                        else -> complete("platform_error")
                    }
                }

                override fun onInstallReferrerServiceDisconnected() {
                    complete("service_disconnected")
                }
            })
        } catch (_: Exception) {
            complete("platform_error")
        }
    }
}
