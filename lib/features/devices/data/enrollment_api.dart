import 'package:spark_sales/core/errors/app_exception.dart';
import 'package:spark_sales/features/devices/domain/enrollment_models.dart';
import 'package:spark_sales/features/sync/domain/sync_error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EnrollmentApi {
  EnrollmentApi({this.client});

  final SupabaseClient? client;

  SupabaseClient get _supabase => client ?? Supabase.instance.client;

  Future<EnrollmentResult> enroll(Map<String, dynamic> body) async {
    try {
      final response = await _supabase.functions.invoke(
        'enroll-device',
        body: body,
      );
      final data = response.data;
      if (data is! Map) {
        throw const AppException(
          'malformed_response',
          'The server returned an unexpected enrollment response.',
          retryable: true,
        );
      }
      return EnrollmentResult.fromJson(Map<String, dynamic>.from(data));
    } on FunctionException catch (error) {
      throw SyncErrorMapper.fromStatus(error.status, error.details);
    } catch (error) {
      if (error is AppException) {
        rethrow;
      }
      throw const AppException(
        'network',
        'No network connection. Check the signal and try again.',
        retryable: true,
      );
    }
  }
}
