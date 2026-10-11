import 'package:flutter_test/flutter_test.dart';
import 'package:spark_sales/features/call_logs/domain/duration_parser.dart';

void main() {
  test('parses duration seconds and clamps invalid values', () {
    expect(DurationParser.parseSeconds(185), 185);
    expect(DurationParser.parseSeconds(185.6), 186);
    expect(DurationParser.parseSeconds('42'), 42);
    expect(DurationParser.parseSeconds(null), 0);
    expect(DurationParser.parseSeconds(-4), 0);
    expect(DurationParser.parseSeconds('nope'), 0);
    expect(
      DurationParser.parseSeconds(DurationParser.maxSeconds + 50),
      DurationParser.maxSeconds,
    );
  });
}
