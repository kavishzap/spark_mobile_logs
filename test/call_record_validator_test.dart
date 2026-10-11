import 'package:flutter_test/flutter_test.dart';
import 'package:spark_sales/features/call_logs/domain/call_record_validator.dart';

void main() {
  final now = DateTime.utc(2026, 10, 11, 12);

  String? validate({
    String id = '12345',
    String phone = '+23051234567',
    String type = 'outgoing',
    DateTime? date,
    int duration = 185,
  }) {
    return CallRecordValidator.validate(
      androidCallId: id,
      phoneNumber: phone,
      callType: type,
      callDate: date ?? now,
      durationSeconds: duration,
      now: now,
    );
  }

  test('accepts a normal cellular call', () {
    expect(validate(), isNull);
    expect(validate(phone: 'unknown'), isNull);
    expect(validate(phone: 'private', type: 'missed', duration: 0), isNull);
  });

  test('rejects unsupported types, future dates, and bad durations', () {
    expect(validate(type: 'voicemail'), 'invalid_call_type');
    expect(
      validate(date: now.add(const Duration(hours: 1))),
      'call_date_in_future',
    );
    expect(validate(duration: 90000), 'invalid_duration');
    expect(validate(id: ''), 'invalid_android_call_id');
  });
}
