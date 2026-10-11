import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_sales/core/config/app_config.dart';
import 'package:spark_sales/core/platform/call_log_platform.dart';
import 'package:spark_sales/core/security/secure_store.dart';
import 'package:spark_sales/features/auth/data/auth_repository.dart';
import 'package:spark_sales/features/call_logs/data/android_call_log_reader.dart';
import 'package:spark_sales/features/call_logs/data/unavailable_call_log_reader.dart';
import 'package:spark_sales/features/call_logs/data/call_queue_database.dart';
import 'package:spark_sales/features/call_logs/data/call_queue_repository.dart';
import 'package:spark_sales/features/call_logs/domain/call_log_reader.dart';
import 'package:spark_sales/features/devices/data/device_info_reader.dart';
import 'package:spark_sales/features/devices/data/enrollment_api.dart';
import 'package:spark_sales/features/sync/data/call_sync_api.dart';
import 'package:spark_sales/features/sync/data/call_sync_service.dart';
import 'package:spark_sales/features/sync/data/sync_scheduler.dart';
import 'package:spark_sales/features/sync/domain/sync_uploader.dart';

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

final callQueueDatabaseProvider = Provider<CallQueueDatabase>((ref) {
  final database = CallQueueDatabase();
  ref.onDispose(database.close);
  return database;
});

final callQueueRepositoryProvider = Provider<CallQueueRepository>((ref) {
  return CallQueueRepository(ref.watch(callQueueDatabaseProvider));
});

final callLogReaderProvider = Provider<CallLogReader>((ref) {
  if (CallLogPlatform.supported) {
    return AndroidCallLogReader();
  }
  return const UnavailableCallLogReader();
});

final syncUploaderProvider = Provider<SyncUploader>((ref) => CallSyncApi());

final enrollmentApiProvider = Provider<EnrollmentApi>((ref) => EnrollmentApi());

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

final deviceInfoReaderProvider = Provider<DeviceInfoReader>(
  (ref) => const DeviceInfoReader(),
);

final syncSchedulerProvider = Provider<SyncScheduler>(
  (ref) => const SyncScheduler(),
);

final callSyncServiceProvider = Provider<CallSyncService>((ref) {
  final config = AppConfig.instance;
  return CallSyncService(
    reader: ref.watch(callLogReaderProvider),
    queue: ref.watch(callQueueRepositoryProvider),
    uploader: ref.watch(syncUploaderProvider),
    lookback: config.lookback,
    retention: config.localRetention,
  );
});
