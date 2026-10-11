import 'package:spark_sales/core/constants/app_constants.dart';
import 'package:spark_sales/core/errors/app_exception.dart';
import 'package:spark_sales/core/network/app_clock.dart';
import 'package:spark_sales/features/call_logs/data/call_queue_repository.dart';
import 'package:spark_sales/features/call_logs/domain/call_log_reader.dart';
import 'package:spark_sales/features/call_logs/domain/call_record.dart';
import 'package:spark_sales/features/call_logs/domain/call_record_validator.dart';
import 'package:spark_sales/features/call_logs/domain/normalized_call.dart';
import 'package:spark_sales/features/call_logs/domain/permission_gate.dart';
import 'package:spark_sales/features/sync/domain/sync_models.dart';
import 'package:spark_sales/features/sync/domain/sync_uploader.dart';

class CallSyncService {
  CallSyncService({
    required this.reader,
    required this.queue,
    required this.uploader,
    required this.lookback,
    required this.retention,
    this.clock = const AppClock(),
  });

  final CallLogReader reader;
  final CallQueueRepository queue;
  final SyncUploader uploader;
  final Duration lookback;
  final Duration retention;
  final AppClock clock;

  Future<SyncRunResult> synchronize(SyncRequest request) async {
    final now = clock.now().toUtc();
    final block = PermissionGate.evaluate(
      signedIn: request.signedIn,
      disclosureAccepted: request.disclosureAccepted,
      permissionGranted: request.permissionGranted,
      monitoringEnabled: request.monitoringEnabled,
    );
    if (block != CollectionBlock.none) {
      await queue.recordIdle(now);
      return SyncRunResult.skipped(block.name);
    }
    final deviceId = request.deviceId;
    if (deviceId == null || deviceId.isEmpty) {
      final error = const AppException(
        'device_not_registered',
        'This phone is not registered.',
      );
      await queue.recordFailure(error.message, now);
      return SyncRunResult.failed(error);
    }

    final locked = await queue.acquireLock(now);
    if (!locked) {
      return SyncRunResult.skipped('in_progress');
    }

    try {
      await queue.resetStaleSyncing(now.subtract(AppConstants.lockStaleAfter));
      try {
        await _collect(now);
      } on AppException catch (error) {
        await queue.recordFailure(error.message, now);
        return SyncRunResult.failed(error);
      }
      await queue.purgeSyncedOlderThan(now.subtract(retention));

      var uploaded = 0;
      for (var round = 0; round < 8; round++) {
        final batch = await queue.readyBatch(
          now: clock.now().toUtc(),
          limit: AppConstants.batchSize,
        );
        if (batch.isEmpty) {
          try {
            final ack = await uploader.upload(
              deviceId: deviceId,
              calls: const [],
            );
            await queue.recordSuccess(at: ack.serverTime, uploaded: uploaded);
            final counts = await queue.counts();
            return SyncRunResult.success(
              uploaded: uploaded,
              pending: counts.waiting,
              failed: counts.failed,
            );
          } on AppException catch (error) {
            final attemptAt = clock.now().toUtc();
            await queue.recordFailure(error.message, attemptAt);
            if (error.revokesAccess) {
              return SyncRunResult.revoked(error);
            }
            final counts = await queue.counts();
            return SyncRunResult.failed(
              error,
              pending: counts.waiting,
              failed: counts.failed,
            );
          }
        }

        final ids = batch
            .map((call) => call.androidCallId)
            .toList(growable: false);
        await queue.markSyncing(ids, clock.now().toUtc());
        try {
          final ack = await uploader.upload(deviceId: deviceId, calls: batch);
          uploaded += await _applyAck(batch, ack);
        } on AppException catch (error) {
          final attemptAt = clock.now().toUtc();
          if (error.revokesAccess) {
            await queue.resetSyncing(ids);
            await queue.recordFailure(error.message, attemptAt);
            return SyncRunResult.revoked(error);
          }
          await queue.markForRetry(ids, error.message, attemptAt);
          await queue.recordFailure(error.message, attemptAt);
          final counts = await queue.counts();
          return SyncRunResult.failed(
            error,
            pending: counts.waiting,
            failed: counts.failed,
          );
        }
      }

      await queue.recordSuccess(at: clock.now().toUtc(), uploaded: uploaded);
      final counts = await queue.counts();
      return SyncRunResult.success(
        uploaded: uploaded,
        pending: counts.waiting,
        failed: counts.failed,
      );
    } finally {
      await queue.releaseLock();
    }
  }

  Future<void> _collect(DateTime now) async {
    final checkpoint = await queue.checkpoint();
    var since = checkpoint == null
        ? now.subtract(lookback)
        : checkpoint.subtract(AppConstants.checkpointOverlap);
    final valid = <NormalizedCall>[];
    final invalid = <NormalizedCall>[];
    final seen = <String>{};
    DateTime? newest;
    for (var page = 0; page < 20; page++) {
      final raw = await reader.readSince(since, limit: AppConstants.readLimit);
      if (raw.isEmpty) {
        break;
      }
      DateTime? pageNewest;
      for (final call in raw) {
        if (!seen.add(call.androidCallId)) {
          continue;
        }
        final candidate = call.callDate.toUtc();
        if (pageNewest == null || candidate.isAfter(pageNewest)) {
          pageNewest = candidate;
        }
        final reason = CallRecordValidator.validate(
          androidCallId: call.androidCallId,
          phoneNumber: call.phoneNumber,
          callType: call.callType.name,
          callDate: call.callDate,
          durationSeconds: call.durationSeconds,
          now: now,
        );
        if (reason == null) {
          valid.add(call);
        } else {
          invalid.add(call);
        }
      }
      if (pageNewest != null &&
          (newest == null || pageNewest.isAfter(newest))) {
        newest = pageNewest;
      }
      if (raw.length < AppConstants.readLimit || pageNewest == null) {
        break;
      }
      final next = pageNewest.add(const Duration(milliseconds: 1));
      if (!next.isAfter(since)) {
        break;
      }
      since = next;
    }
    await queue.ingestAll(valid);
    await queue.ingestTerminalAll(invalid, 'invalid_call');
    if (newest != null && (checkpoint == null || newest.isAfter(checkpoint))) {
      await queue.setCheckpoint(newest);
    }
  }

  Future<int> _applyAck(List<CallRecord> batch, SyncAck ack) async {
    await queue.markSynced(ack.acknowledged);
    await queue.markRejected(ack.rejected, ack.serverTime);
    final handled = {
      ...ack.acknowledged,
      ...ack.rejected.map((item) => item.androidCallId),
    };
    final missing = batch
        .map((call) => call.androidCallId)
        .where((id) => !handled.contains(id))
        .toList(growable: false);
    if (missing.isNotEmpty) {
      await queue.markForRetry(
        missing,
        'Server did not acknowledge the record',
        ack.serverTime,
      );
    }
    return ack.acknowledged.length;
  }
}
