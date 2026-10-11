import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spark_sales/features/call_logs/data/call_queue_database.dart';
import 'package:spark_sales/features/call_logs/data/call_queue_repository.dart';
import 'package:spark_sales/features/call_logs/domain/call_record.dart';
import 'package:spark_sales/features/call_logs/domain/normalized_call.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('spark_sales_queue');
  });

  tearDown(() async {
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  });

  test('pending records survive closing and reopening the database', () async {
    final path = '${directory.path}/calls.db';
    final firstDatabase = CallQueueDatabase(
      factory: databaseFactoryFfi,
      path: path,
    );
    final first = CallQueueRepository(firstDatabase);
    await first.ingestAll([_call('55')]);
    await firstDatabase.close();

    final reopenedDatabase = CallQueueDatabase(
      factory: databaseFactoryFfi,
      path: path,
    );
    final reopened = CallQueueRepository(reopenedDatabase);
    final pending = await reopened.readyBatch(
      now: DateTime.utc(2026, 10, 11, 12),
      limit: 10,
    );
    expect(pending, hasLength(1));
    expect(pending.single.androidCallId, '55');
    expect(pending.single.syncStatus, SyncStatus.pending);
    await reopenedDatabase.close();
  });

  test('a synced call is not queued again', () async {
    final database = CallQueueDatabase(
      factory: databaseFactoryFfi,
      path: '${directory.path}/calls.db',
    );
    final repository = CallQueueRepository(database);
    final call = _call('77');
    await repository.ingestAll([call]);
    await repository.markSynced(['77']);
    await repository.ingestAll([call]);

    expect(await repository.countAll(), 1);
    final snapshot = await repository.snapshot();
    expect(snapshot.pending, 0);
    final rows = await repository.search(const CallQuery());
    expect(rows.single.syncStatus, SyncStatus.synced);
    await database.close();
  });

  test('failed calls wait for backoff and can be reset', () async {
    final database = CallQueueDatabase(
      factory: databaseFactoryFfi,
      path: '${directory.path}/calls.db',
    );
    final repository = CallQueueRepository(database);
    final now = DateTime.utc(2026, 10, 11, 12);
    await repository.ingestAll([_call('88')]);
    await repository.markForRetry(['88'], 'offline', now);

    final tooSoon = await repository.readyBatch(
      now: now.add(const Duration(minutes: 1)),
      limit: 10,
    );
    expect(tooSoon, isEmpty);

    final ready = await repository.readyBatch(
      now: now.add(const Duration(minutes: 3)),
      limit: 10,
    );
    expect(ready, hasLength(1));
    expect(ready.single.retryCount, 1);

    await repository.resetFailed();
    final reset = await repository.readyBatch(now: now, limit: 10);
    expect(reset.single.syncStatus, SyncStatus.pending);
    expect(reset.single.retryCount, 0);
    await database.close();
  });
}

NormalizedCall _call(String id) {
  return NormalizedCall(
    androidCallId: id,
    phoneNumber: '+23051234567',
    callType: CallType.outgoing,
    callDate: DateTime.utc(2026, 10, 11, 10, 30),
    durationSeconds: 185,
  );
}
