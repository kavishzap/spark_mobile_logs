class DurationParser {
  const DurationParser._();

  static const maxSeconds = 24 * 60 * 60;

  static int parseSeconds(Object? value) {
    final parsed = switch (value) {
      final int number => number,
      final num number => number.round(),
      final String text => int.tryParse(text.trim()) ?? 0,
      _ => 0,
    };
    if (parsed < 0) {
      return 0;
    }
    if (parsed > maxSeconds) {
      return maxSeconds;
    }
    return parsed;
  }
}
