package com.example.gena

import android.Manifest
import android.app.ActivityManager
import android.content.Intent
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.StatFs
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL_NAME = "gena/native_phone_tools"
        private const val DEVICE_INFO_CHANNEL_NAME = "gena/device_system_info"
        private const val CALL_PERMISSION_REQUEST_CODE = 9107
        private const val CONTACTS_PERMISSION_REQUEST_CODE = 9108
    }

    private var pendingCallResult: MethodChannel.Result? = null
    private var pendingPhoneNumber: String? = null
    private var pendingContactsPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "makeDirectPhoneCall" -> {
                    val rawPhoneNumber = call.argument<String>("phoneNumber")?.trim().orEmpty()
                    if (rawPhoneNumber.isEmpty()) {
                        result.error(
                            "invalid_phone_number",
                            "Parameter \"phoneNumber\" is required.",
                            null
                        )
                        return@setMethodCallHandler
                    }
                    requestOrStartDirectCall(rawPhoneNumber, result)
                }
                "requestContactsPermission" -> {
                    requestContactsPermission(result)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_INFO_CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInfo" -> result.success(buildDeviceInfo())
                else -> result.notImplemented()
            }
        }
    }

    private fun buildDeviceInfo(): Map<String, Any?> {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)

        val dataDirectory = Environment.getDataDirectory()
        val statFs = StatFs(dataDirectory.path)
        val deviceConfig = activityManager.deviceConfigurationInfo
        val glEsVersion = deviceConfig?.glEsVersion ?: "OpenGL ES"

        val socModel = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            Build.SOC_MODEL?.takeIf { it.isNotBlank() }
        } else {
            null
        }
        val cpuModel = listOfNotNull(
            socModel,
            Build.HARDWARE?.takeIf { it.isNotBlank() },
            Build.BOARD?.takeIf { it.isNotBlank() }
        ).firstOrNull() ?: "Unknown CPU"

        return mapOf(
            "platform" to "android",
            "cpuCores" to Runtime.getRuntime().availableProcessors(),
            "cpuModel" to cpuModel,
            "gpuModel" to glEsVersion,
            "totalRamBytes" to memoryInfo.totalMem,
            "availableRamBytes" to memoryInfo.availMem,
            "totalStorageBytes" to statFs.totalBytes,
            "freeStorageBytes" to statFs.availableBytes,
            "abis" to Build.SUPPORTED_ABIS.toList()
        )
    }

    private fun requestOrStartDirectCall(
        phoneNumber: String,
        result: MethodChannel.Result
    ) {
        if (pendingCallResult != null) {
            result.error(
                "call_in_progress",
                "Another phone call request is already in progress.",
                null
            )
            return
        }

        val hasPermission = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.CALL_PHONE
        ) == PackageManager.PERMISSION_GRANTED

        if (!hasPermission) {
            pendingCallResult = result
            pendingPhoneNumber = phoneNumber
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.CALL_PHONE),
                CALL_PERMISSION_REQUEST_CODE
            )
            return
        }

        startDirectCall(phoneNumber, result)
    }

    private fun startDirectCall(
        phoneNumber: String,
        result: MethodChannel.Result
    ) {
        try {
            val callIntent = Intent(Intent.ACTION_CALL).apply {
                data = Uri.parse("tel:$phoneNumber")
            }
            startActivity(callIntent)
            result.success(true)
        } catch (e: Exception) {
            result.error("call_failed", e.message ?: "Failed to place phone call.", null)
        }
    }

    private fun requestContactsPermission(result: MethodChannel.Result) {
        if (pendingContactsPermissionResult != null) {
            result.error(
                "permission_request_in_progress",
                "Another contacts permission request is already in progress.",
                null
            )
            return
        }

        val readGranted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.READ_CONTACTS
        ) == PackageManager.PERMISSION_GRANTED
        val writeGranted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.WRITE_CONTACTS
        ) == PackageManager.PERMISSION_GRANTED

        if (readGranted && writeGranted) {
            result.success(true)
            return
        }

        pendingContactsPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.READ_CONTACTS, Manifest.permission.WRITE_CONTACTS),
            CONTACTS_PERMISSION_REQUEST_CODE
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            CALL_PERMISSION_REQUEST_CODE -> {
                val result = pendingCallResult
                val phoneNumber = pendingPhoneNumber
                pendingCallResult = null
                pendingPhoneNumber = null

                if (result == null || phoneNumber.isNullOrEmpty()) return

                val granted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED

                if (!granted) {
                    result.error(
                        "permission_denied",
                        "Phone call permission was denied by the user.",
                        null
                    )
                    return
                }

                startDirectCall(phoneNumber, result)
            }

            CONTACTS_PERMISSION_REQUEST_CODE -> {
                val result = pendingContactsPermissionResult
                pendingContactsPermissionResult = null
                if (result == null) return

                val allGranted = grantResults.isNotEmpty() &&
                    grantResults.all { grant -> grant == PackageManager.PERMISSION_GRANTED }
                result.success(allGranted)
            }
        }
    }
}
