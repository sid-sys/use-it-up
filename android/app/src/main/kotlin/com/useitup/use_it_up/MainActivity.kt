package com.useitup.use_it_up

import android.content.pm.PackageManager
import android.os.Build
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "useitup/install").setMethodCallHandler { call, result ->
            if (call.method == "getInstallInfo") readInstallInfo(result) else result.notImplemented()
        }
    }

    /// Reports where this install came from. Works only once, the first time the app is opened after
    /// a Google Play install; Google Play keeps the answer for 90 days.
    private fun readInstallInfo(result: MethodChannel.Result) {
        val info = HashMap<String, Any?>()
        try {
            val pm = packageManager
            val pi = pm.getPackageInfo(packageName, 0)
            info["firstInstallTime"] = pi.firstInstallTime
            info["lastUpdateTime"] = pi.lastUpdateTime
            info["installer"] = if (Build.VERSION.SDK_INT >= 30) {
                pm.getInstallSourceInfo(packageName).installingPackageName
            } else {
                @Suppress("DEPRECATION") pm.getInstallerPackageName(packageName)
            }
        } catch (e: PackageManager.NameNotFoundException) {
            // leave the fields empty
        } catch (e: Exception) {
            // leave the fields empty
        }

        var answered = false
        fun finish() {
            if (!answered) {
                answered = true
                result.success(info)
            }
        }

        try {
            val client = InstallReferrerClient.newBuilder(this).build()
            client.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(code: Int) {
                    try {
                        if (code == InstallReferrerClient.InstallReferrerResponse.OK) {
                            val d = client.installReferrer
                            info["referrer"] = d.installReferrer
                            info["clickSeconds"] = d.referrerClickTimestampSeconds
                            info["installBeginSeconds"] = d.installBeginTimestampSeconds
                        } else {
                            info["referrerError"] = code
                        }
                    } catch (e: Exception) {
                        info["referrerError"] = -1
                    } finally {
                        try { client.endConnection() } catch (e: Exception) { }
                        finish()
                    }
                }

                override fun onInstallReferrerServiceDisconnected() {
                    finish()
                }
            })
        } catch (e: Exception) {
            info["referrerError"] = -1
            finish()
        }
    }
}
