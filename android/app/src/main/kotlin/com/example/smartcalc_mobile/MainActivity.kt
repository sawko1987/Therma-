package com.example.smartcalc_mobile

import android.Manifest
import android.content.pm.PackageManager
import android.provider.CallLog
import android.provider.ContactsContract
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "smartcalc_mobile/customer_phone"
    private var pendingResult: MethodChannel.Result? = null
    private var pendingPermission: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "supportsContacts" -> result.success(true)
                "supportsCallLog" -> result.success(true)
                "loadContacts" -> handleContacts(result)
                "loadCallLog" -> handleCallLog(result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val result = pendingResult ?: return
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        val permission = pendingPermission
        pendingResult = null
        pendingPermission = null

        if (!granted) {
            result.success(emptyList<Map<String, String>>())
            return
        }

        when (permission) {
            Manifest.permission.READ_CONTACTS -> result.success(loadContactsInternal())
            Manifest.permission.READ_CALL_LOG -> result.success(loadCallLogInternal())
            else -> result.success(emptyList<Map<String, String>>())
        }
    }

    private fun handleContacts(result: MethodChannel.Result) {
        if (hasPermission(Manifest.permission.READ_CONTACTS)) {
            result.success(loadContactsInternal())
            return
        }
        requestPermission(Manifest.permission.READ_CONTACTS, result)
    }

    private fun handleCallLog(result: MethodChannel.Result) {
        if (hasPermission(Manifest.permission.READ_CALL_LOG)) {
            result.success(loadCallLogInternal())
            return
        }
        requestPermission(Manifest.permission.READ_CALL_LOG, result)
    }

    private fun requestPermission(permission: String, result: MethodChannel.Result) {
        pendingResult = result
        pendingPermission = permission
        ActivityCompat.requestPermissions(this, arrayOf(permission), 1001)
    }

    private fun hasPermission(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            permission,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun loadContactsInternal(): List<Map<String, String>> {
        val entries = mutableListOf<Map<String, String>>()
        val resolver = applicationContext.contentResolver
        val cursor = resolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            arrayOf(
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER,
            ),
            null,
            null,
            "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC",
        )

        cursor?.use {
            val nameIndex =
                it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
            val phoneIndex =
                it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)

            while (it.moveToNext()) {
                val label = it.getString(nameIndex) ?: "Контакт"
                val phone = it.getString(phoneIndex) ?: continue
                entries.add(
                    mapOf(
                        "label" to label,
                        "phone" to phone,
                    ),
                )
            }
        }

        return entries.distinctBy { item -> item["label"] + item["phone"] }
    }

    private fun loadCallLogInternal(): List<Map<String, String>> {
        val entries = mutableListOf<Map<String, String>>()
        val resolver = applicationContext.contentResolver
        val cursor = resolver.query(
            CallLog.Calls.CONTENT_URI,
            arrayOf(
                CallLog.Calls.CACHED_NAME,
                CallLog.Calls.NUMBER,
                CallLog.Calls.DATE,
                CallLog.Calls.TYPE,
            ),
            null,
            null,
            "${CallLog.Calls.DATE} DESC LIMIT 50",
        )

        cursor?.use {
            val nameIndex = it.getColumnIndex(CallLog.Calls.CACHED_NAME)
            val phoneIndex = it.getColumnIndex(CallLog.Calls.NUMBER)
            val dateIndex = it.getColumnIndex(CallLog.Calls.DATE)
            val typeIndex = it.getColumnIndex(CallLog.Calls.TYPE)

            while (it.moveToNext()) {
                val phone = it.getString(phoneIndex) ?: continue
                val label = it.getString(nameIndex) ?: phone
                val timestamp = it.getLong(dateIndex)
                val type = when (it.getInt(typeIndex)) {
                    CallLog.Calls.INCOMING_TYPE -> "Входящий"
                    CallLog.Calls.OUTGOING_TYPE -> "Исходящий"
                    CallLog.Calls.MISSED_TYPE -> "Пропущенный"
                    else -> "Вызов"
                }
                entries.add(
                    mapOf(
                        "label" to label,
                        "phone" to phone,
                        "subtitle" to "$type • $timestamp",
                    ),
                )
            }
        }

        return entries.distinctBy { item -> item["label"] + item["phone"] }
    }
}
