class TimestampCodec {
  const TimestampCodec._();

  static DateTime fromAndroidMillis(int millis) {
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  static String toUtcIso8601(DateTime value) {
    return value.toUtc().toIso8601String();
  }

  /// Accepts an ISO-8601 timestamp that includes a timezone.
  static DateTime? parseUtc(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final text = value.trim();
    final hasZone =
        text.endsWith('Z') ||
        text.contains('+') ||
        RegExp(r'-\d{2}:\d{2}$').hasMatch(text);
    if (!hasZone) {
      return null;
    }
    return DateTime.tryParse(text)?.toUtc();
  }
}
