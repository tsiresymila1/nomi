package com.example.gena

import android.Manifest
import android.app.ActivityManager
import android.content.Intent
import android.content.Context
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL_NAME = "gena/native_phone_tools"
        private const val DEVICE_INFO_CHANNEL_NAME = "gena/device_system_info"
        private const val DIRECT_MODEL_FILES_CHANNEL_NAME = "gena/direct_model_files"
        private const val CALL_PERMISSION_REQUEST_CODE = 9107
        private const val CONTACTS_PERMISSION_REQUEST_CODE = 9108
        private const val ALL_FILES_ACCESS_REQUEST_CODE = 9109
        private const val MODEL_FILE_PICK_REQUEST_CODE = 9110
    }

    private var pendingCallResult: MethodChannel.Result? = null
    private var pendingPhoneNumber: String? = null
    private var pendingContactsPermissionResult: MethodChannel.Result? = null
    private var pendingAllFilesAccessResult: MethodChannel.Result? = null
    private var pendingModelFileResult: MethodChannel.Result? = null

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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DIRECT_MODEL_FILES_CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasAllFilesAccess" -> result.success(hasAllFilesAccess())
                "requestAllFilesAccess" -> requestAllFilesAccess(result)
                "pickModelFile" -> pickDirectModelFile(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun hasAllFilesAccess(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.R ||
            Environment.isExternalStorageManager()
    }

    private fun requestAllFilesAccess(result: MethodChannel.Result) {
        if (hasAllFilesAccess()) {
            result.success(true)
            return
        }
        if (pendingAllFilesAccessResult != null) {
            result.error(
                "permission_request_in_progress",
                "Another file access request is already in progress.",
                null
            )
            return
        }

        pendingAllFilesAccessResult = result
        val appSettingsIntent = Intent(
            Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
            Uri.parse("package:$packageName")
        )
        try {
            startActivityForResult(appSettingsIntent, ALL_FILES_ACCESS_REQUEST_CODE)
        } catch (_: Exception) {
            startActivityForResult(
                Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION),
                ALL_FILES_ACCESS_REQUEST_CODE
            )
        }
    }

    private fun pickDirectModelFile(result: MethodChannel.Result) {
        if (!hasAllFilesAccess()) {
            result.error(
                "all_files_access_required",
                "Grant file access before choosing a model.",
                null
            )
            return
        }
        if (pendingModelFileResult != null) {
            result.error(
                "picker_in_progress",
                "Another model picker is already active.",
                null
            )
            return
        }

        pendingModelFileResult = result
        val picker = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/octet-stream"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("application/octet-stream", "application/x-gguf", "*/*")
            )
        }
        startActivityForResult(picker, MODEL_FILE_PICK_REQUEST_CODE)
    }

    private fun resolveDirectModelPath(uri: Uri): String? {
        if (uri.scheme == "file") return uri.path
        if (!DocumentsContract.isDocumentUri(this, uri)) return null

        val documentId = DocumentsContract.getDocumentId(uri)
        if (uri.authority == "com.android.externalstorage.documents") {
            val parts = documentId.split(":", limit = 2)
            if (parts.size != 2) return null
            val root = if (parts[0].equals("primary", ignoreCase = true)) {
                Environment.getExternalStorageDirectory().absolutePath
            } else {
                "/storage/${parts[0]}"
            }
            return java.io.File(root, parts[1]).canonicalPath
        }

        if (uri.authority == "com.android.providers.downloads.documents" &&
            documentId.startsWith("raw:")) {
            return java.io.File(documentId.removePrefix("raw:")).canonicalPath
        }
        return null
    }

    private fun selectedDisplayName(uri: Uri): String? {
        var cursor: Cursor? = null
        return try {
            cursor = contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null
            )
            if (cursor?.moveToFirst() == true) cursor.getString(0) else null
        } catch (_: Exception) {
            null
        } finally {
            cursor?.close()
        }
    }

    @Deprecated("Deprecated in Android API; retained for FlutterActivity result bridging.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            ALL_FILES_ACCESS_REQUEST_CODE -> {
                val result = pendingAllFilesAccessResult
                pendingAllFilesAccessResult = null
                result?.success(hasAllFilesAccess())
            }

            MODEL_FILE_PICK_REQUEST_CODE -> {
                val result = pendingModelFileResult
                pendingModelFileResult = null
                if (result == null) return
                if (resultCode != RESULT_OK || data?.data == null) {
                    result.success(null)
                    return
                }

                val uri = data.data!!
                val directPath = try {
                    resolveDirectModelPath(uri)
                } catch (_: Exception) {
                    null
                }
                if (directPath == null) {
                    result.error(
                        "direct_path_unavailable",
                        "Choose an on-device file. Cloud providers cannot be used directly without copying.",
                        selectedDisplayName(uri)
                    )
                    return
                }

                val file = java.io.File(directPath)
                val extension = file.extension.lowercase()
                if (!file.isFile || !file.canRead() ||
                    (extension != "gguf" && extension != "litertlm")) {
                    result.error(
                        "invalid_model_file",
                        "Choose a readable .gguf or .litertlm file.",
                        directPath
                    )
                    return
                }
                result.success(file.canonicalPath)
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
