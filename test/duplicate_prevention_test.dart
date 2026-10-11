import 'package:flutter_test/flutter_test.dart';
import 'package:spark_sales/features/sync/domain/call_log_upsert.dart';

void main() {
  const original = StoredCallLog(
    id: 'row-1',
    deviceId: 'device-a',
    androidCallId: '100',
  );

  test('upsert keeps one row for the same device and android id', () {
    final first = CallLogUpsert.apply(const {}, [original]);
    final second = CallLogUpsert.apply(first, [
      const StoredCallLog(
        id: 'row-2',
        deviceId: 'device-a',
        androidCallId: '100',
      ),
    ]);

    expect(second.length, 1);
    expect(second[original.conflictKey]?.id, 'row-1');
  });

  test('the same android id on another device is a different row', () {
    final stored = CallLogUpsert.apply(const {}, [
      original,
      const StoredCallLog(
        id: 'row-c',
        deviceId: 'device-b',
        androidCallId: '100',
      ),
    ]);

    expect(stored.length, 2);
  });
}
