import 'package:spark_sales/features/call_logs/domain/call_record.dart';
import 'package:spark_sales/features/sync/domain/sync_models.dart';

abstract class SyncUploader {
  Future<SyncAck> upload({
    required String deviceId,
    required List<CallRecord> calls,
  });
}

class SyncRequest {
  const SyncRequest({
    required this.signedIn,
    required this.disclosureAccepted,
    required this.permissionGranted,
    required this.monitoringEnabled,
    required this.deviceId,
  });

  final bool signedIn;
  final bool disclosureAccepted;
  final bool permissionGranted;
  final bool monitoringEnabled;
  final String? deviceId;
}
