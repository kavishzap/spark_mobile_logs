import 'package:flutter/services.dart';
import 'package:spark_sales/core/errors/app_exception.dart';
import 'package:spark_sales/features/call_logs/domain/call_log_reader.dart';
import 'package:spark_sales/features/call_logs/domain/normalized_call.dart';
import 'package:call_log_android/call_log_android.dart';

class AndroidCallLogReader implements CallLogReader {
  AndroidCallLogReader({CallLogAndroid? plugin})
    : _plugin = plugin ?? CallLogAndroid();

  final CallLogAndroid _plugin;

  @override
  Future<CallLogPermission> permissionStatus() async {
    try {
      final status = await _plugin.permissionStatus();
      return CallLogPermission(
        granted: status.granted,
        shouldShowRationale: status.shouldShowRationale,
      );
    } on PlatformException catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      return await _plugin.requestPermission();
    } on PlatformException catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<void> openAppSettings() async {
    try {
      await _plugin.openAppSettings();
    } on PlatformException catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<List<NormalizedCall>> readSince(
    DateTime since, {
    int limit = 2000,
  }) async {
    try {
      final rows = await _plugin.readCalls(
        sinceMillis: since.toUtc().millisecondsSinceEpoch,
        limit: limit,
      );
      final calls = <NormalizedCall>[];
      for (final row in rows) {
        final parsed = NormalizedCall.tryParse(row);
        if (parsed != null) {
          calls.add(parsed);
        }
      }
      return calls;
    } on PlatformException catch (error) {
      throw _map(error);
    }
  }

  AppException _map(PlatformException error) {
    if (error.code == 'permission_denied') {
      return const AppException(
        'permission_denied',
        'Call log permission is not granted.',
      );
    }
    if (error.code == 'activity_unavailable') {
      return AppException(
        'activity_unavailable',
        error.message ?? 'Open the app to allow call log access.',
      );
    }
    return AppException(
      error.code,
      error.message ?? 'Could not read the call log.',
      retryable: error.code == 'call_log_read_failed',
    );
  }
}
