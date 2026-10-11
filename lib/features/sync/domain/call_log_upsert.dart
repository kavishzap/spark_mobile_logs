class StoredCallLog {
  const StoredCallLog({
    required this.id,
    required this.deviceId,
    required this.androidCallId,
  });

  final String id;
  final String deviceId;
  final String androidCallId;

  String get conflictKey => '$deviceId|$androidCallId';
}

class CallLogUpsert {
  const CallLogUpsert._();

  static Map<String, StoredCallLog> apply(
    Map<String, StoredCallLog> existing,
    List<StoredCallLog> incoming,
  ) {
    final next = Map<String, StoredCallLog>.of(existing);
    for (final row in incoming) {
      final previous = next[row.conflictKey];
      next[row.conflictKey] = previous == null
          ? row
          : StoredCallLog(
              id: previous.id,
              deviceId: row.deviceId,
              androidCallId: row.androidCallId,
            );
    }
    return next;
  }
}
