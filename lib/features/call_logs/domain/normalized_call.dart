import 'package:spark_sales/features/call_logs/domain/call_record.dart';
import 'package:spark_sales/features/call_logs/domain/call_type_mapper.dart';
import 'package:spark_sales/features/call_logs/domain/duration_parser.dart';
import 'package:spark_sales/features/call_logs/domain/phone_number_normalizer.dart';
import 'package:spark_sales/features/call_logs/domain/timestamp_codec.dart';

class NormalizedCall {
  const NormalizedCall({
    required this.androidCallId,
    required this.phoneNumber,
    required this.callType,
    required this.callDate,
    required this.durationSeconds,
  });

  final String androidCallId;
  final String phoneNumber;
  final CallType callType;
  final DateTime callDate;
  final int durationSeconds;

  static NormalizedCall? tryParse(Map<dynamic, dynamic> row) {
    final id = row['id']?.toString().trim() ?? '';
    if (id.isEmpty) {
      return null;
    }
    final type = CallTypeMapper.fromAndroid((row['type'] as num?)?.toInt());
    if (type == null) {
      return null;
    }
    final millis = (row['dateMillis'] as num?)?.toInt();
    if (millis == null) {
      return null;
    }
    return NormalizedCall(
      androidCallId: id,
      phoneNumber: PhoneNumberNormalizer.normalize(row['number'] as String?),
      callType: type,
      callDate: TimestampCodec.fromAndroidMillis(millis),
      durationSeconds: DurationParser.parseSeconds(row['durationSeconds']),
    );
  }

  CallRecord toRecord({
    SyncStatus status = SyncStatus.pending,
    int retryCount = 0,
    DateTime? lastAttemptAt,
    String? lastError,
  }) {
    return CallRecord(
      androidCallId: androidCallId,
      phoneNumber: phoneNumber,
      callType: callType,
      callDate: callDate.toUtc(),
      durationSeconds: durationSeconds,
      syncStatus: status,
      retryCount: retryCount,
      lastAttemptAt: lastAttemptAt,
      lastError: lastError,
    );
  }
}
