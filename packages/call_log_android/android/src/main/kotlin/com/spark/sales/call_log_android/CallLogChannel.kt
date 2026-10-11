package com.spark.sales.call_log_android

import android.content.Context
import android.provider.CallLog

/**
 * Reads the device cellular call log through the platform CallLog provider.
 *
 * Only normal telephony rows are returned. The Dart layer drops unsupported
 * types such as voicemail. This class does not read messages, recordings,
 * or contact names.
 */
object CallLogChannel {
    fun read(context: Context, sinceMillis: Long, limit: Int): List<Map<String, Any?>> {
        val cursor = context.contentResolver.query(
            CallLog.Calls.CONTENT_URI,
            arrayOf(
                CallLog.Calls._ID,
                CallLog.Calls.NUMBER,
                CallLog.Calls.TYPE,
                CallLog.Calls.DATE,
                CallLog.Calls.DURATION,
            ),
            "${CallLog.Calls.DATE} >= ?",
            arrayOf(sinceMillis.toString()),
            "${CallLog.Calls.DATE} ASC",
        ) ?: return emptyList()

        cursor.use { rows ->
            val idIndex = rows.getColumnIndexOrThrow(CallLog.Calls._ID)
            val numberIndex = rows.getColumnIndexOrThrow(CallLog.Calls.NUMBER)
            val typeIndex = rows.getColumnIndexOrThrow(CallLog.Calls.TYPE)
            val dateIndex = rows.getColumnIndexOrThrow(CallLog.Calls.DATE)
            val durationIndex = rows.getColumnIndexOrThrow(CallLog.Calls.DURATION)
            val results = ArrayList<Map<String, Any?>>()
            while (rows.moveToNext() && results.size < limit) {
                val row = HashMap<String, Any?>()
                row["id"] = rows.getLong(idIndex).toString()
                row["number"] = if (rows.isNull(numberIndex)) null else rows.getString(numberIndex)
                row["type"] = rows.getInt(typeIndex)
                row["dateMillis"] = rows.getLong(dateIndex)
                row["durationSeconds"] = if (rows.isNull(durationIndex)) 0L else rows.getLong(durationIndex)
                results.add(row)
            }
            return results
        }
    }
}
