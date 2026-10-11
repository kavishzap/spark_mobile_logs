import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark_sales/core/errors/app_exception.dart';
import 'package:spark_sales/core/network/app_clock.dart';
import 'package:spark_sales/features/call_logs/data/call_queue_database.dart';
import 'package:spark_sales/features/call_logs/data/call_queue_repository.dart';
import 'package:spark_sales/features/call_logs/domain/call_log_reader.dart';
import 'package:spark_sales/features/call_logs/domain/call_record.dart';
import 'package:spark_sales/features/call_logs/domain/normalized_call.dart';
import 'package:spark_sales/features/sync/data/call_sync_service.dart';
import 'package:spark_sales/features/sync/domain/retry_policy.dart';
import 'package:spark_sales/features/sync/domain/sync_error_mapper.dart';
import 'package:spark_sales/features/sync/domain/sync_models.dart';
import 'package:spark_sales/features/sync/domain/sync_uploader.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('backoff grows exponentially and stops after the retry cap', () {
    expect(RetryPolicy.delayFor(1), const Duration(minutes: 2));
    expect(RetryPolicy.delayFor(2), const Duration(minutes: 4));
    expect(RetryPolicy.delayFor(6).inMinutes, lessThanOrEqualTo(60));
    expect(
      RetryPolicy.isReady(
        retryCount: 10,
        lastAttemptAt: null,
        now: DateTime.utc(2026, 10, 11),
      ),
      isFalse,
    );
  });

  test(
    'a network failure retries later, then a repeat read does not duplicate the call',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'spark_sales_sync',
      );
      final database = CallQueueDatabase(
        factory: databaseFactoryFfi,
        path: '${directory.path}/calls.db',
      );
      final queue = CallQueueRepository(database);
      final clock = _ManualClock(DateTime.utc(2026, 10, 11, 12));
      final reader = _FakeReader([
        NormalizedCall(
          androidCallId: '100',
          phoneNumber: '+23051234567',
          callType: CallType.outgoing,
          callDate: clock.current,
          durationSeconds: 185,
        ),
      ]);
      final uploader = _FakeUploader();
      final service = CallSyncService(
        reader: reader,
        queue: queue,
        uploader: uploader,
        lookback: const Duration(days: 30),
        retention: const Duration(days: 90),
        clock: clock,
      );
      const request = SyncRequest(
        signedIn: true,
        disclosureAccepted: true,
        permissionGranted: true,
        monitoringEnabled: true,
        deviceId: 'device-a',
      );

      final failed = await service.synchronize(request);
      expect(failed.outcome, SyncOutcome.failed);
      expect(failed.retryable, isTrue);
      expect(uploader.nonEmptyAttempts, 1);

      final waiting = await service.synchronize(request);
      expect(waiting.outcome, SyncOutcome.success);
      expect(uploader.nonEmptyAttempts, 1);
      final stillFailed = await queue.search(const CallQuery());
      expect(stillFailed.single.syncStatus, SyncStatus.failed);

      clock.current = clock.current.add(const Duration(minutes: 3));
      final synced = await service.synchronize(request);
      expect(synced.outcome, SyncOutcome.success);
      expect(synced.uploaded, 1);
      expect(uploader.uploadedIds, ['100']);

      final again = await service.synchronize(request);
      expect(again.uploaded, 0);
      expect(await queue.countAll(), 1);
      final rows = await queue.search(const CallQuery());
      expect(rows.single.syncStatus, SyncStatus.synced);

      await database.close();
      await directory.delete(recursive: true);
    },
  );

  test('an inactive device revokes access instead of uploading', () async {
    final directory = await Directory.systemTemp.createTemp(
      'spark_sales_revoke',
    );
    final database = CallQueueDatabase(
      factory: databaseFactoryFfi,
      path: '${directory.path}/calls.db',
    );
    final service = CallSyncService(
      reader: _FakeReader(const []),
      queue: CallQueueRepository(database),
      uploader: _RevokedUploader(),
      lookback: const Duration(days: 30),
      retention: const Duration(days: 90),
    );

    final result = await service.synchronize(
      const SyncRequest(
        signedIn: true,
        disclosureAccepted: true,
        permissionGranted: true,
        monitoringEnabled: true,
        deviceId: 'device-a',
      ),
    );

    expect(result.outcome, SyncOutcome.revoked);
    expect(result.code, 'device_inactive');
    await database.close();
    await directory.delete(recursive: true);
  });

  test('maps server denials for inactive employees and unknown devices', () {
    final employee = SyncErrorMapper.fromStatus(403, {
      'error': 'assistant_inactive',
      'message': 'This sales assistant account is inactive.',
    });
    expect(employee.revokesAccess, isTrue);
    expect(employee.retryable, isFalse);

    final device = SyncErrorMapper.fromStatus(403, {
      'error': 'device_not_assigned',
      'message': 'This phone is not the registered company device.',
    });
    expect(device.code, 'device_not_assigned');
    expect(device.revokesAccess, isTrue);
  });
}

class _ManualClock extends AppClock {
  _ManualClock(this.current);

  DateTime current;

  @override
  DateTime now() => current;
}

class _FakeReader implements CallLogReader {
  _FakeReader(this.calls);

  final List<NormalizedCall> calls;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<CallLogPermission> permissionStatus() async {
    return const CallLogPermission(granted: true, shouldShowRationale: false);
  }

  @override
  Future<List<NormalizedCall>> readSince(
    DateTime since, {
    int limit = 2000,
  }) async {
    return calls;
  }

  @override
  Future<bool> requestPermission() async => true;
}

class _FakeUploader implements SyncUploader {
  int nonEmptyAttempts = 0;
  final uploadedIds = <String>[];

  @override
  Future<SyncAck> upload({
    required String deviceId,
    required List<CallRecord> calls,
  }) async {
    if (calls.isEmpty) {
      return SyncAck(
        acknowledged: const [],
        rejected: const [],
        serverTime: DateTime.utc(2026, 10, 11, 12),
      );
    }
    nonEmptyAttempts += 1;
    if (nonEmptyAttempts == 1) {
      throw const AppException('network', 'offline', retryable: true);
    }
    uploadedIds.addAll(calls.map((call) => call.androidCallId));
    return SyncAck(
      acknowledged: calls.map((call) => call.androidCallId).toList(),
      rejected: const [],
      serverTime: DateTime.utc(2026, 10, 11, 13),
    );
  }
}

class _RevokedUploader implements SyncUploader {
  @override
  Future<SyncAck> upload({
    required String deviceId,
    required List<CallRecord> calls,
  }) async {
    throw const AppException(
      'device_inactive',
      'This phone was deactivated.',
      revokesAccess: true,
    );
  }
}
