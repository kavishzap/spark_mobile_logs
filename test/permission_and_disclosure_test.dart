import 'package:flutter_test/flutter_test.dart';
import 'package:spark_sales/features/call_logs/domain/permission_gate.dart';
import 'package:spark_sales/features/settings/presentation/monitoring_disclosure.dart';

void main() {
  test('permission denial blocks collection', () {
    expect(
      PermissionGate.evaluate(
        signedIn: true,
        disclosureAccepted: true,
        permissionGranted: false,
        monitoringEnabled: true,
      ),
      CollectionBlock.permissionDenied,
    );
  });

  test(
    'monitoring disabled, sign-out, and missing disclosure also stop collection',
    () {
      expect(
        PermissionGate.evaluate(
          signedIn: true,
          disclosureAccepted: true,
          permissionGranted: true,
          monitoringEnabled: false,
        ),
        CollectionBlock.monitoringDisabled,
      );
      expect(
        PermissionGate.evaluate(
          signedIn: false,
          disclosureAccepted: true,
          permissionGranted: true,
          monitoringEnabled: true,
        ),
        CollectionBlock.signedOut,
      );
      expect(
        PermissionGate.evaluate(
          signedIn: true,
          disclosureAccepted: false,
          permissionGranted: true,
          monitoringEnabled: true,
        ),
        CollectionBlock.disclosureRequired,
      );
    },
  );

  test(
    'the disclosure explains collection, access, sync, disablement, and retention',
    () {
      final text = MonitoringDisclosure.sections
          .map((section) => '${section.title} ${section.body}')
          .join('\n')
          .toLowerCase();
      expect(text, contains('phone number'));
      expect(text, contains('duration'));
      expect(text, contains('whatsapp'));
      expect(text, contains('microphone'));
      expect(text, contains('recordings'));
      expect(text, contains('15 minutes'));
      expect(text, contains('administrators'));
      expect(text, contains('sign out'));
      expect(text, contains('retention'));
    },
  );
}
