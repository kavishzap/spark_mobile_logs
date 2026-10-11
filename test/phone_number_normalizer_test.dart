import 'package:flutter_test/flutter_test.dart';
import 'package:spark_sales/features/call_logs/domain/phone_number_normalizer.dart';

void main() {
  test('normalizes missing, private, and formatted numbers', () {
    expect(PhoneNumberNormalizer.normalize(null), 'unknown');
    expect(PhoneNumberNormalizer.normalize(''), 'unknown');
    expect(PhoneNumberNormalizer.normalize('-1'), 'unknown');
    expect(PhoneNumberNormalizer.normalize('-2'), 'private');
    expect(PhoneNumberNormalizer.normalize('Restricted'), 'private');
    expect(PhoneNumberNormalizer.normalize('+230 5123-4567'), '+23051234567');
  });
}
