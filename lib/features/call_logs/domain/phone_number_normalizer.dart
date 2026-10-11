class PhoneNumberNormalizer {
  const PhoneNumberNormalizer._();

  static String normalize(String? raw) {
    if (raw == null) {
      return 'unknown';
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '-1') {
      return 'unknown';
    }
    final lowered = trimmed.toLowerCase();
    if (lowered == 'unknown' || lowered == 'null') {
      return 'unknown';
    }
    if (trimmed == '-2' ||
        lowered == 'private' ||
        lowered == 'restricted' ||
        lowered == 'anonymous') {
      return 'private';
    }
    final compact = trimmed.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (compact.isEmpty) {
      return 'unknown';
    }
    return compact;
  }
}
