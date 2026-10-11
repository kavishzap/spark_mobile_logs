import 'package:flutter_test/flutter_test.dart';
import 'package:spark_sales/features/call_logs/domain/call_record.dart';
import 'package:spark_sales/features/call_logs/domain/call_type_mapper.dart';

void main() {
  test('maps supported Android call types', () {
    expect(
      CallTypeMapper.fromAndroid(CallTypeMapper.incoming),
      CallType.incoming,
    );
    expect(
      CallTypeMapper.fromAndroid(CallTypeMapper.outgoing),
      CallType.outgoing,
    );
    expect(CallTypeMapper.fromAndroid(CallTypeMapper.missed), CallType.missed);
    expect(
      CallTypeMapper.fromAndroid(CallTypeMapper.rejected),
      CallType.rejected,
    );
    expect(
      CallTypeMapper.fromAndroid(CallTypeMapper.blocked),
      CallType.blocked,
    );
  });

  test('drops unsupported and unknown Android call types', () {
    expect(CallTypeMapper.fromAndroid(CallTypeMapper.voicemail), isNull);
    expect(
      CallTypeMapper.fromAndroid(CallTypeMapper.answeredExternally),
      isNull,
    );
    expect(CallTypeMapper.fromAndroid(0), isNull);
    expect(CallTypeMapper.fromAndroid(null), isNull);
  });
}
