import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:spark_sales/core/config/app_config.dart';
import 'package:spark_sales/core/security/secure_store.dart';
import 'package:spark_sales/features/call_logs/data/android_call_log_reader.dart';
import 'package:spark_sales/features/call_logs/data/call_queue_database.dart';
import 'package:spark_sales/features/call_logs/data/call_queue_repository.dart';
import 'package:spark_sales/features/sync/data/call_sync_api.dart';
import 'package:spark_sales/features/sync/data/call_sync_service.dart';
import 'package:spark_sales/features/sync/data/sync_scheduler.dart';
import 'package:spark_sales/features/sync/domain/sync_models.dart';
import 'package:spark_sales/features/sync/domain/sync_uploader.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

bool _supabaseReady = false;

Future<void> ensureSupabase() async {
  if (_supabaseReady) {
    return;
  }
  await AppConfig.load();
  final config = AppConfig.instance;
  if (!config.isConfigured) {
    return;
  }
  try {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
    );
  } on StateError {
    // This isolate already initialized Supabase, usually after a hot restart.
  }
  _supabaseReady = true;
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      return await runBackgroundSync();
    } catch (error, stackTrace) {
      debugPrint('Background call sync failed: $error\n$stackTrace');
      return false;
    }
  });
}

Future<bool> runBackgroundSync() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  final config = AppConfig.instance;
  if (!config.isConfigured) {
    return true;
  }
  await ensureSupabase();
  if (Supabase.instance.client.auth.currentSession == null) {
    await const SyncScheduler().cancel();
    return true;
  }

  final secure = SecureStore();
  final reader = AndroidCallLogReader();
  final permission = await reader.permissionStatus();
  final database = CallQueueDatabase();
  final queue = CallQueueRepository(database);
  final service = CallSyncService(
    reader: reader,
    queue: queue,
    uploader: CallSyncApi(),
    lookback: config.lookback,
    retention: config.localRetention,
  );
  final result = await service.synchronize(
    SyncRequest(
      signedIn: true,
      disclosureAccepted: await secure.disclosureAccepted(),
      permissionGranted: permission.granted,
      monitoringEnabled: true,
      deviceId: await secure.readDeviceId(),
    ),
  );
  if (result.outcome == SyncOutcome.revoked) {
    await queue.wipe();
    await secure.clearSession();
    await const SyncScheduler().cancel();
    try {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } catch (error) {
      debugPrint('Background sign-out failed: $error');
    }
    return true;
  }
  return !result.shouldRetryWork;
}
