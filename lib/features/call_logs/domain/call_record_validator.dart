class CallRecordValidator {
  const CallRecordValidator._();

  static final _callId = RegExp(r'^[A-Za-z0-9_.:\-]{1,128}$');
  static final _phone = RegExp(r'^(unknown|private|\+?[0-9*#]{2,32})$');
  static const allowedTypes = {
    'incoming',
    'outgoing',
    'missed',
    'rejected',
    'blocked',
  };
  static const futureSkew = Duration(minutes: 5);
  static const maxAge = Duration(days: 366);

  static String? validate({
    required String androidCallId,
    required String phoneNumber,
    required String callType,
    required DateTime callDate,
    required int durationSeconds,
    required DateTime now,
  }) {
    if (!_callId.hasMatch(androidCallId)) {
      return 'invalid_android_call_id';
    }
    if (!_phone.hasMatch(phoneNumber)) {
      return 'invalid_phone_number';
    }
    if (!allowedTypes.contains(callType)) {
      return 'invalid_call_type';
    }
    if (durationSeconds < 0 || durationSeconds > 86400) {
      return 'invalid_duration';
    }
    final utc = callDate.toUtc();
    final current = now.toUtc();
    if (utc.isAfter(current.add(futureSkew))) {
      return 'call_date_in_future';
    }
    if (utc.isBefore(current.subtract(maxAge))) {
      return 'call_date_too_old';
    }
    return null;
  }
}
