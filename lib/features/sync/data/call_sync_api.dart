import 'package:spark_sales/core/errors/app_exception.dart';
import 'package:spark_sales/features/call_logs/domain/call_record.dart';
import 'package:spark_sales/features/sync/domain/sync_error_mapper.dart';
import 'package:spark_sales/features/sync/domain/sync_models.dart';
import 'package:spark_sales/features/sync/domain/sync_uploader.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CallSyncApi implements SyncUploader {
  CallSyncApi({this.client});

  final SupabaseClient? client;

  SupabaseClient get _supabase => client ?? Supabase.instance.client;

  @override
  Future<SyncAck> upload({
    required String deviceId,
    required List<CallRecord> calls,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'sync-call-logs',
        body: {
          'device_id': deviceId,
          'calls': calls
              .map((call) => call.toPayload())
              .toList(growable: false),
        },
      );
      final data = response.data;
      if (data is! Map) {
        throw const AppException(
          'malformed_response',
          'The server returned an unexpected sync response.',
          retryable: true,
        );
      }
      return SyncAck.fromJson(Map<String, dynamic>.from(data));
    } on FunctionException catch (error) {
      throw SyncErrorMapper.fromStatus(error.status, error.details);
    } catch (error) {
      if (error is AppException) {
        rethrow;
      }
      throw AppException(
        'network',
        'No network connection. Calls stay on this phone until sync can finish.',
        retryable: true,
      );
    }
  }
}
