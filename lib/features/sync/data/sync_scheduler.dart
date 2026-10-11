import 'package:spark_sales/core/constants/app_constants.dart';
import 'package:spark_sales/core/platform/call_log_platform.dart';
import 'package:workmanager/workmanager.dart';

class SyncScheduler {
  const SyncScheduler();

  Future<void> ensureScheduled() {
    if (!CallLogPlatform.supported) {
      return Future<void>.value();
    }
    return Workmanager().registerPeriodicTask(
      AppConstants.callSyncUniqueName,
      AppConstants.callSyncTaskName,
      frequency: AppConstants.periodicInterval,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: AppConstants.periodicInterval,
    );
  }

  Future<void> cancel() {
    if (!CallLogPlatform.supported) {
      return Future<void>.value();
    }
    return Workmanager().cancelByUniqueName(AppConstants.callSyncUniqueName);
  }
}
