import 'package:spark_sales/core/errors/app_exception.dart';

enum SyncOutcome { success, skipped, failed, revoked }

class SyncRunResult {
  const SyncRunResult._({
    required this.outcome,
    this.code,
    this.message,
    this.uploaded = 0,
    this.pending = 0,
    this.failed = 0,
    this.retryable = false,
  });

  final SyncOutcome outcome;
  final String? code;
  final String? message;
  final int uploaded;
  final int pending;
  final int failed;
  final bool retryable;

  bool get shouldRetryWork => outcome == SyncOutcome.failed && retryable;

  factory SyncRunResult.success({
    required int uploaded,
    required int pending,
    required int failed,
  }) {
    return SyncRunResult._(
      outcome: SyncOutcome.success,
      uploaded: uploaded,
      pending: pending,
      failed: failed,
    );
  }

  factory SyncRunResult.skipped(String code) {
    return SyncRunResult._(outcome: SyncOutcome.skipped, code: code);
  }

  factory SyncRunResult.failed(
    AppException error, {
    int pending = 0,
    int failed = 0,
  }) {
    return SyncRunResult._(
      outcome: SyncOutcome.failed,
      code: error.code,
      message: error.message,
      pending: pending,
      failed: failed,
      retryable: error.retryable,
    );
  }

  factory SyncRunResult.revoked(AppException error) {
    return SyncRunResult._(
      outcome: SyncOutcome.revoked,
      code: error.code,
      message: error.message,
    );
  }
}

class RejectedCall {
  const RejectedCall({required this.androidCallId, required this.reason});

  final String androidCallId;
  final String reason;

  factory RejectedCall.fromJson(Map<String, dynamic> json) {
    return RejectedCall(
      androidCallId: json['android_call_id']?.toString() ?? '',
      reason: json['reason']?.toString() ?? 'rejected',
    );
  }
}

class SyncAck {
  const SyncAck({
    required this.acknowledged,
    required this.rejected,
    required this.serverTime,
  });

  final List<String> acknowledged;
  final List<RejectedCall> rejected;
  final DateTime serverTime;

  factory SyncAck.fromJson(Map<String, dynamic> json) {
    final acknowledged =
        (json['acknowledged'] as List?)
            ?.map((item) => item.toString())
            .where((id) => id.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    final rejected =
        (json['rejected'] as List?)
            ?.whereType<Map>()
            .map(
              (item) => RejectedCall.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((item) => item.androidCallId.isNotEmpty)
            .toList(growable: false) ??
        const <RejectedCall>[];
    final serverTime =
        DateTime.tryParse(json['server_time']?.toString() ?? '')?.toUtc() ??
        DateTime.now().toUtc();
    return SyncAck(
      acknowledged: acknowledged,
      rejected: rejected,
      serverTime: serverTime,
    );
  }
}
