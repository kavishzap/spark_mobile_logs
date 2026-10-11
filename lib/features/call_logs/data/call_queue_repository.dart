import 'package:spark_sales/core/constants/app_constants.dart';
import 'package:spark_sales/features/call_logs/data/call_queue_database.dart';
import 'package:spark_sales/features/call_logs/domain/call_record.dart';
import 'package:spark_sales/features/call_logs/domain/normalized_call.dart';
import 'package:spark_sales/features/sync/domain/retry_policy.dart';
import 'package:spark_sales/features/sync/domain/sync_models.dart';
import 'package:sqflite/sqflite.dart';

class QueueCounts {
  const QueueCounts({
    required this.pending,
    required this.syncing,
    required this.failed,
    required this.synced,
  });

  final int pending;
  final int syncing;
  final int failed;
  final int synced;

  int get waiting => pending + syncing;
}

class SyncSnapshot {
  const SyncSnapshot({
    required this.lastSuccessAt,
    required this.lastAttemptAt,
    required this.lastError,
    required this.lastUploaded,
    required this.pending,
    required this.syncing,
    required this.failed,
    required this.status,
    this.busy = false,
  });

  final DateTime? lastSuccessAt;
  final DateTime? lastAttemptAt;
  final String? lastError;
  final int lastUploaded;
  final int pending;
  final int syncing;
  final int failed;
  final String status;
  final bool busy;

  SyncSnapshot copyWith({bool? busy}) {
    return SyncSnapshot(
      lastSuccessAt: lastSuccessAt,
      lastAttemptAt: lastAttemptAt,
      lastError: lastError,
      lastUploaded: lastUploaded,
      pending: pending,
      syncing: syncing,
      failed: failed,
      status: status,
      busy: busy ?? this.busy,
    );
  }
}

class DashboardStats {
  const DashboardStats({
    required this.incoming,
    required this.outgoing,
    required this.missed,
    required this.rejected,
    required this.blocked,
    required this.durationSeconds,
    required this.pending,
    required this.failed,
  });

  final int incoming;
  final int outgoing;
  final int missed;
  final int rejected;
  final int blocked;
  final int durationSeconds;
  final int pending;
  final int failed;

  static const empty = DashboardStats(
    incoming: 0,
    outgoing: 0,
    missed: 0,
    rejected: 0,
    blocked: 0,
    durationSeconds: 0,
    pending: 0,
    failed: 0,
  );
}

enum DateRangePreset { all, today, last7Days, custom }

class CallQuery {
  const CallQuery({this.type, this.start, this.end, this.search = ''});

  final CallType? type;
  final DateTime? start;
  final DateTime? end;
  final String search;

  static CallQuery build({
    CallType? type,
    required DateRangePreset preset,
    DateTime? customStart,
    DateTime? customEnd,
    String search = '',
    DateTime? now,
  }) {
    final localNow = now ?? DateTime.now();
    DateTime? start;
    DateTime? end;
    switch (preset) {
      case DateRangePreset.all:
        break;
      case DateRangePreset.today:
        final day = DateTime(localNow.year, localNow.month, localNow.day);
        start = day.toUtc();
        end = day.add(const Duration(days: 1)).toUtc();
      case DateRangePreset.last7Days:
        final day = DateTime(localNow.year, localNow.month, localNow.day);
        start = day.subtract(const Duration(days: 6)).toUtc();
        end = day.add(const Duration(days: 1)).toUtc();
      case DateRangePreset.custom:
        if (customStart != null) {
          final day = DateTime(
            customStart.year,
            customStart.month,
            customStart.day,
          );
          start = day.toUtc();
        }
        if (customEnd != null) {
          final day = DateTime(customEnd.year, customEnd.month, customEnd.day);
          end = day.add(const Duration(days: 1)).toUtc();
        }
    }
    return CallQuery(type: type, start: start, end: end, search: search);
  }
}

class CallQueueRepository {
  CallQueueRepository(this._database);

  final CallQueueDatabase _database;

  Future<bool> acquireLock(DateTime now) {
    return _database.run((db) {
      return db.transaction<bool>((txn) async {
        final rows = await txn.query(
          'meta',
          where: 'key = ?',
          whereArgs: ['sync_lock'],
        );
        if (rows.isNotEmpty) {
          final held = DateTime.tryParse(rows.first['value'] as String? ?? '');
          if (held != null &&
              now.toUtc().difference(held.toUtc()) <
                  AppConstants.lockStaleAfter) {
            return false;
          }
        }
        await txn.insert('meta', {
          'key': 'sync_lock',
          'value': now.toUtc().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        return true;
      });
    });
  }

  Future<void> releaseLock() async {
    final db = await _database.database;
    await db.delete('meta', where: 'key = ?', whereArgs: ['sync_lock']);
  }

  Future<void> resetStaleSyncing(DateTime olderThan) async {
    final db = await _database.database;
    await db.rawUpdate(
      '''
      UPDATE calls
      SET sync_status = 'pending'
      WHERE sync_status = 'syncing'
        AND (last_attempt_at IS NULL OR last_attempt_at < ?)
      ''',
      [olderThan.toUtc().toIso8601String()],
    );
  }

  Future<DateTime?> checkpoint() async {
    final db = await _database.database;
    final raw = await _readMeta(db, 'checkpoint_millis');
    final millis = int.tryParse(raw ?? '');
    if (millis == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  Future<void> setCheckpoint(DateTime value) async {
    final db = await _database.database;
    await _writeMeta(
      db,
      'checkpoint_millis',
      value.toUtc().millisecondsSinceEpoch.toString(),
    );
  }

  Future<void> ingestAll(List<NormalizedCall> calls) async {
    if (calls.isEmpty) {
      return;
    }
    await _database.run((db) async {
      await db.transaction((txn) async {
        for (final call in calls) {
          final existing = await txn.query(
            'calls',
            where: 'android_call_id = ?',
            whereArgs: [call.androidCallId],
            limit: 1,
          );
          if (existing.isEmpty) {
            await txn.insert(
              'calls',
              _insertRow(call, SyncStatus.pending, 0, null),
            );
            continue;
          }
          final status = existing.first['sync_status'] as String?;
          if (status == SyncStatus.synced.name) {
            continue;
          }
          await txn.update(
            'calls',
            {
              'phone_number': call.phoneNumber,
              'call_type': call.callType.name,
              'call_date': call.callDate.toUtc().toIso8601String(),
              'call_date_millis': call.callDate.toUtc().millisecondsSinceEpoch,
              'duration_seconds': call.durationSeconds,
            },
            where: 'android_call_id = ?',
            whereArgs: [call.androidCallId],
          );
        }
      });
    });
  }

  Future<void> ingestTerminalAll(
    List<NormalizedCall> calls,
    String reason,
  ) async {
    if (calls.isEmpty) {
      return;
    }
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      for (final call in calls) {
        final existing = await txn.query(
          'calls',
          columns: ['sync_status'],
          where: 'android_call_id = ?',
          whereArgs: [call.androidCallId],
          limit: 1,
        );
        if (existing.isNotEmpty &&
            existing.first['sync_status'] == SyncStatus.synced.name) {
          continue;
        }
        await txn.insert('calls', {
          ..._insertRow(
            call,
            SyncStatus.failed,
            AppConstants.terminalRetryCount,
            reason,
          ),
          'last_attempt_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<CallRecord>> readyBatch({
    required DateTime now,
    required int limit,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'calls',
      where: "sync_status IN ('pending', 'failed')",
      orderBy: 'call_date_millis ASC',
      limit: 200,
    );
    final ready = <CallRecord>[];
    for (final row in rows) {
      final record = _fromRow(row);
      if (RetryPolicy.isReady(
        retryCount: record.retryCount,
        lastAttemptAt: record.lastAttemptAt,
        now: now,
      )) {
        ready.add(record);
      }
      if (ready.length >= limit) {
        break;
      }
    }
    return ready;
  }

  Future<void> markSyncing(List<String> ids, DateTime now) async {
    await _updateIds(ids, {
      'sync_status': SyncStatus.syncing.name,
      'last_attempt_at': now.toUtc().toIso8601String(),
    });
  }

  Future<void> markSynced(List<String> ids) async {
    await _updateIds(ids, {
      'sync_status': SyncStatus.synced.name,
      'last_error': null,
    });
  }

  Future<void> markRejected(List<RejectedCall> rejected, DateTime now) async {
    if (rejected.isEmpty) {
      return;
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      for (final item in rejected) {
        await txn.update(
          'calls',
          {
            'sync_status': SyncStatus.failed.name,
            'retry_count': AppConstants.terminalRetryCount,
            'last_attempt_at': now.toUtc().toIso8601String(),
            'last_error': item.reason,
          },
          where: 'android_call_id = ?',
          whereArgs: [item.androidCallId],
        );
      }
    });
  }

  Future<void> markForRetry(
    List<String> ids,
    String error,
    DateTime now,
  ) async {
    if (ids.isEmpty) {
      return;
    }
    final db = await _database.database;
    final attempt = now.toUtc().toIso8601String();
    await db.transaction((txn) async {
      for (final id in ids) {
        await txn.rawUpdate(
          '''
          UPDATE calls
          SET sync_status = 'failed',
              retry_count = MIN(retry_count + 1, ?),
              last_attempt_at = ?,
              last_error = ?
          WHERE android_call_id = ?
          ''',
          [AppConstants.maxRetryCount, attempt, error, id],
        );
      }
    });
  }

  Future<void> resetSyncing(List<String> ids) async {
    await _updateIds(ids, {'sync_status': SyncStatus.pending.name});
  }

  Future<void> resetFailed() async {
    final db = await _database.database;
    await db.update(
      'calls',
      {
        'sync_status': SyncStatus.pending.name,
        'retry_count': 0,
        'last_attempt_at': null,
      },
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.failed.name],
    );
  }

  Future<void> recordSuccess({
    required DateTime at,
    required int uploaded,
  }) async {
    final db = await _database.database;
    final stamp = at.toUtc().toIso8601String();
    await _writeMeta(db, 'last_success_at', stamp);
    await _writeMeta(db, 'last_attempt_at', stamp);
    await _writeMeta(db, 'last_uploaded_count', uploaded.toString());
    await _writeMeta(db, 'last_status', 'success');
    await db.delete('meta', where: 'key = ?', whereArgs: ['last_error']);
  }

  Future<void> recordFailure(String message, DateTime at) async {
    final db = await _database.database;
    await _writeMeta(db, 'last_attempt_at', at.toUtc().toIso8601String());
    await _writeMeta(db, 'last_status', 'failed');
    await _writeMeta(db, 'last_error', message);
    await _writeMeta(db, 'last_uploaded_count', '0');
  }

  Future<void> recordIdle(DateTime at) async {
    final db = await _database.database;
    await _writeMeta(db, 'last_attempt_at', at.toUtc().toIso8601String());
    await _writeMeta(db, 'last_status', 'idle');
  }

  Future<SyncSnapshot> snapshot() {
    return _database.run((db) async {
      final counts = await countsFor(db);
      return SyncSnapshot(
        lastSuccessAt: DateTime.tryParse(
          await _readMeta(db, 'last_success_at') ?? '',
        )?.toUtc(),
        lastAttemptAt: DateTime.tryParse(
          await _readMeta(db, 'last_attempt_at') ?? '',
        )?.toUtc(),
        lastError: await _readMeta(db, 'last_error'),
        lastUploaded:
            int.tryParse(await _readMeta(db, 'last_uploaded_count') ?? '') ?? 0,
        pending: counts.pending,
        syncing: counts.syncing,
        failed: counts.failed,
        status: await _readMeta(db, 'last_status') ?? 'idle',
      );
    });
  }

  Future<QueueCounts> counts() async {
    final db = await _database.database;
    return countsFor(db);
  }

  Future<DashboardStats> todayStats(DateTime localNow) {
    final start = DateTime(localNow.year, localNow.month, localNow.day).toUtc();
    final end = start.add(const Duration(days: 1));
    return _database.run((db) async {
      final rows = await db.rawQuery(
        '''
      SELECT call_type, COUNT(*) AS c, COALESCE(SUM(duration_seconds), 0) AS d
      FROM calls
      WHERE call_date_millis >= ? AND call_date_millis < ?
      GROUP BY call_type
      ''',
        [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      );
      var incoming = 0;
      var outgoing = 0;
      var missed = 0;
      var rejected = 0;
      var blocked = 0;
      var duration = 0;
      for (final row in rows) {
        final count = (row['c'] as num?)?.toInt() ?? 0;
        duration += (row['d'] as num?)?.toInt() ?? 0;
        switch (row['call_type']) {
          case 'incoming':
            incoming = count;
          case 'outgoing':
            outgoing = count;
          case 'missed':
            missed = count;
          case 'rejected':
            rejected = count;
          case 'blocked':
            blocked = count;
        }
      }
      final queue = await countsFor(db);
      return DashboardStats(
        incoming: incoming,
        outgoing: outgoing,
        missed: missed,
        rejected: rejected,
        blocked: blocked,
        durationSeconds: duration,
        pending: queue.waiting,
        failed: queue.failed,
      );
    });
  }

  Future<List<CallRecord>> search(CallQuery query) {
    return _database.run((db) async {
      final where = <String>[];
      final args = <Object?>[];
      if (query.type != null) {
        where.add('call_type = ?');
        args.add(query.type!.name);
      }
      if (query.start != null) {
        where.add('call_date_millis >= ?');
        args.add(query.start!.toUtc().millisecondsSinceEpoch);
      }
      if (query.end != null) {
        where.add('call_date_millis < ?');
        args.add(query.end!.toUtc().millisecondsSinceEpoch);
      }
      final search = query.search.trim();
      if (search.isNotEmpty) {
        where.add("phone_number LIKE ? ESCAPE '\\'");
        args.add('%${_escapeLike(search)}%');
      }
      final rows = await db.query(
        'calls',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'call_date_millis DESC',
        limit: 500,
      );
      return rows.map(_fromRow).toList(growable: false);
    });
  }

  Future<void> purgeSyncedOlderThan(DateTime cutoff) async {
    final db = await _database.database;
    await db.delete(
      'calls',
      where: 'sync_status = ? AND call_date_millis < ?',
      whereArgs: [
        SyncStatus.synced.name,
        cutoff.toUtc().millisecondsSinceEpoch,
      ],
    );
  }

  Future<void> wipe() async {
    final db = await _database.database;
    await db.delete('calls');
    await db.delete('meta');
  }

  Future<int> countAll() async {
    final db = await _database.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM calls');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<QueueCounts> countsFor(Database db) async {
    Future<int> count(String status) async {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM calls WHERE sync_status = ?',
        [status],
      );
      return Sqflite.firstIntValue(rows) ?? 0;
    }

    return QueueCounts(
      pending: await count(SyncStatus.pending.name),
      syncing: await count(SyncStatus.syncing.name),
      failed: await count(SyncStatus.failed.name),
      synced: await count(SyncStatus.synced.name),
    );
  }

  Map<String, Object?> _insertRow(
    NormalizedCall call,
    SyncStatus status,
    int retryCount,
    String? error,
  ) {
    final utc = call.callDate.toUtc();
    return {
      'android_call_id': call.androidCallId,
      'phone_number': call.phoneNumber,
      'call_type': call.callType.name,
      'call_date': utc.toIso8601String(),
      'call_date_millis': utc.millisecondsSinceEpoch,
      'duration_seconds': call.durationSeconds,
      'sync_status': status.name,
      'retry_count': retryCount,
      'last_attempt_at': null,
      'last_error': error,
    };
  }

  CallRecord _fromRow(Map<String, Object?> row) {
    return CallRecord(
      androidCallId: row['android_call_id'] as String,
      phoneNumber: row['phone_number'] as String,
      callType:
          CallType.tryParse(row['call_type'] as String?) ?? CallType.missed,
      callDate: DateTime.parse(row['call_date'] as String).toUtc(),
      durationSeconds: (row['duration_seconds'] as num).toInt(),
      syncStatus: SyncStatus.parse(row['sync_status'] as String?),
      retryCount: (row['retry_count'] as num?)?.toInt() ?? 0,
      lastAttemptAt: DateTime.tryParse(
        row['last_attempt_at'] as String? ?? '',
      )?.toUtc(),
      lastError: row['last_error'] as String?,
    );
  }

  Future<void> _updateIds(List<String> ids, Map<String, Object?> values) async {
    if (ids.isEmpty) {
      return;
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      for (final id in ids) {
        await txn.update(
          'calls',
          values,
          where: 'android_call_id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  Future<String?> _readMeta(Database db, String key) async {
    final rows = await db.query(
      'meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String?;
  }

  Future<void> _writeMeta(DatabaseExecutor db, String key, String value) {
    return db.insert('meta', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  String _escapeLike(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }
}
