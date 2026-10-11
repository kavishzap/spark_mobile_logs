import 'package:spark_sales/features/call_logs/domain/normalized_call.dart';

class CallLogPermission {
  const CallLogPermission({
    required this.granted,
    required this.shouldShowRationale,
  });

  final bool granted;
  final bool shouldShowRationale;
}

abstract class CallLogReader {
  Future<CallLogPermission> permissionStatus();

  Future<bool> requestPermission();

  Future<void> openAppSettings();

  Future<List<NormalizedCall>> readSince(DateTime since, {int limit = 2000});
}
