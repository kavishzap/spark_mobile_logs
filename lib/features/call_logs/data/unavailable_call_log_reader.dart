import 'package:spark_sales/features/call_logs/domain/call_log_reader.dart';
import 'package:spark_sales/features/call_logs/domain/normalized_call.dart';

class UnavailableCallLogReader implements CallLogReader {
  const UnavailableCallLogReader();

  @override
  Future<CallLogPermission> permissionStatus() async {
    return const CallLogPermission(granted: false, shouldShowRationale: false);
  }

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<List<NormalizedCall>> readSince(
    DateTime since, {
    int limit = 2000,
  }) async {
    return const [];
  }
}
