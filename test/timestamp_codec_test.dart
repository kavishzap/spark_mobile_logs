import 'package:flutter_test/flutter_test.dart';
import 'package:spark_sales/features/call_logs/domain/timestamp_codec.dart';

void main() {
  test('converts Android epoch millis to UTC ISO-8601', () {
    final utc = DateTime.utc(2026, 10, 11, 10, 30);
    final parsed = TimestampCodec.fromAndroidMillis(utc.millisecondsSinceEpoch);

    expect(parsed.isUtc, isTrue);
    expect(parsed, utc);
    expect(TimestampCodec.toUtcIso8601(parsed), '2026-10-11T10:30:00.000Z');
  });

  test('accepts zoned timestamps and rejects values without a timezone', () {
    expect(
      TimestampCodec.parseUtc('2026-10-11T14:30:00+04:00'),
      DateTime.utc(2026, 10, 11, 10, 30),
    );
    expect(TimestampCodec.parseUtc('2026-10-11T10:30:00'), isNull);
    expect(TimestampCodec.parseUtc(null), isNull);
  });
}
