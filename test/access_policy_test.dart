import 'package:flutter_test/flutter_test.dart';
import 'package:spark_sales/features/devices/domain/enrollment_policy.dart';
import 'package:spark_sales/features/sync/domain/sync_access_policy.dart';

void main() {
  const assistant = AssistantAccess(
    id: 'assistant-a',
    isActive: true,
  );
  const device = DeviceAccess(
    id: 'device-a',
    salesAssistantId: 'assistant-a',
    isActive: true,
  );

  test('an inactive employee is rejected', () {
    final decision = EnrollmentPolicy.evaluate(
      assistant: const AssistantAccess(
        id: 'assistant-a',
        isActive: false,
      ),
      devices: const [],
      jwtUserId: 'user-a',
      boundAssistantId: 'assistant-a',
    );
    expect(decision, isA<EnrollmentDenied>());
    expect((decision as EnrollmentDenied).code, 'assistant_inactive');
  });

  test('signing in again reuses the assistant device instead of creating one', () {
    final enrollment = EnrollmentPolicy.evaluate(
      assistant: assistant,
      devices: const [
        DeviceAccess(
          id: 'device-a',
          salesAssistantId: 'assistant-a',
          isActive: false,
        ),
        DeviceAccess(
          id: 'device-b',
          salesAssistantId: 'assistant-a',
          isActive: true,
        ),
      ],
      jwtUserId: 'user-a',
      boundAssistantId: 'assistant-a',
    );
    final allowed = enrollment as EnrollmentAllowed;
    expect(allowed.createDevice, isFalse);
    expect(allowed.deviceId, 'device-b');

    final sync = SyncAccessPolicy.evaluate(
      jwtUserId: 'user-a',
      boundAssistantId: 'assistant-a',
      assistant: assistant,
      device: const DeviceAccess(
        id: 'device-a',
        salesAssistantId: 'assistant-a',
        isActive: false,
      ),
      requestedDeviceId: 'device-a',
    );
    expect((sync as SyncAccessDenied).code, 'device_inactive');
  });

  test('an existing active phone is reused for this assistant', () {
    final decision = EnrollmentPolicy.evaluate(
      assistant: assistant,
      devices: const [device],
      jwtUserId: 'user-a',
      boundAssistantId: 'assistant-a',
    );
    expect(decision, isA<EnrollmentAllowed>());
    final allowed = decision as EnrollmentAllowed;
    expect(allowed.createDevice, isFalse);
    expect(allowed.deviceId, 'device-a');
  });

  test('sync stamps the registered assistant and ignores a client id', () {
    final decision =
        SyncAccessPolicy.evaluate(
              jwtUserId: 'user-a',
              boundAssistantId: 'assistant-a',
              assistant: assistant,
              device: device,
              requestedDeviceId: 'device-a',
            )
            as SyncAccessAllowed;
    final stamped = CallStamp.stamp(access: decision, androidCallId: '100');

    expect(stamped.salesAssistantId, 'assistant-a');
    expect(stamped.deviceId, 'device-a');
    expect(
      IdentityFields.clientSuppliedIdentity({
        'company_id': 'company-b',
        'sales_assistant_id': 'assistant-b',
      }),
      isTrue,
    );
  });

  test('a different assistant cannot use this device', () {
    final decision = SyncAccessPolicy.evaluate(
      jwtUserId: 'user-a',
      boundAssistantId: 'assistant-b',
      assistant: assistant,
      device: device,
      requestedDeviceId: 'device-a',
    );
    expect((decision as SyncAccessDenied).code, 'identity_mismatch');
  });

  test('an unauthorized device id is rejected', () {
    final decision = SyncAccessPolicy.evaluate(
      jwtUserId: 'user-a',
      boundAssistantId: 'assistant-a',
      assistant: assistant,
      device: device,
      requestedDeviceId: 'device-b',
    );
    expect((decision as SyncAccessDenied).code, 'device_not_assigned');
  });
}
