enum CallType {
  incoming,
  outgoing,
  missed,
  rejected,
  blocked;

  static CallType? tryParse(String? value) {
    if (value == null) {
      return null;
    }
    for (final type in CallType.values) {
      if (type.name == value) {
        return type;
      }
    }
    return null;
  }
}

enum SyncStatus {
  pending,
  syncing,
  synced,
  failed;

  static SyncStatus parse(String? value) {
    for (final status in SyncStatus.values) {
      if (status.name == value) {
        return status;
      }
    }
    return SyncStatus.failed;
  }
}

class CallRecord {
  const CallRecord({
    required this.androidCallId,
    required this.phoneNumber,
    required this.callType,
    required this.callDate,
    required this.durationSeconds,
    required this.syncStatus,
    required this.retryCount,
    this.lastAttemptAt,
    this.lastError,
  });

  final String androidCallId;
  final String phoneNumber;
  final CallType callType;
  final DateTime callDate;
  final int durationSeconds;
  final SyncStatus syncStatus;
  final int retryCount;
  final DateTime? lastAttemptAt;
  final String? lastError;

  int get dateMillis => callDate.toUtc().millisecondsSinceEpoch;

  Map<String, Object?> toPayload() {
    return {
      'android_call_id': androidCallId,
      'phone_number': phoneNumber,
      'call_type': callType.name,
      'call_date': callDate.toUtc().toIso8601String(),
      'duration_seconds': durationSeconds,
    };
  }
}
