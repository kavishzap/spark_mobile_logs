import 'package:spark_sales/features/devices/domain/enrollment_policy.dart';

sealed class SyncAccessDecision {
  const SyncAccessDecision();
}

class SyncAccessAllowed extends SyncAccessDecision {
  const SyncAccessAllowed({
    required this.salesAssistantId,
    required this.deviceId,
  });

  final String salesAssistantId;
  final String deviceId;
}

class SyncAccessDenied extends SyncAccessDecision {
  const SyncAccessDenied(this.code, this.message);

  final String code;
  final String message;
}

class SyncAccessPolicy {
  const SyncAccessPolicy._();

  /// [requestedDeviceId] is the only device identity the client may send.
  /// The assistant is taken from that registered device and checked against
  /// the signed-in email.
  static SyncAccessDecision evaluate({
    required String jwtUserId,
    required String boundAssistantId,
    required AssistantAccess? assistant,
    required DeviceAccess? device,
    required String requestedDeviceId,
  }) {
    if (jwtUserId.isEmpty || boundAssistantId.isEmpty) {
      return const SyncAccessDenied(
        'unauthenticated',
        'Sign in again to synchronize calls.',
      );
    }
    if (assistant == null) {
      return const SyncAccessDenied(
        'assistant_not_found',
        'No sales assistant profile is linked to this sign-in.',
      );
    }
    if (!assistant.isActive) {
      return const SyncAccessDenied(
        'assistant_inactive',
        'This sales assistant account is inactive.',
      );
    }
    if (assistant.id != boundAssistantId) {
      return const SyncAccessDenied(
        'identity_mismatch',
        'This sign-in does not match the registered assistant.',
      );
    }
    if (device == null || device.id != requestedDeviceId) {
      return const SyncAccessDenied(
        'device_not_assigned',
        'This phone is not the registered device.',
      );
    }
    if (!device.isActive) {
      return const SyncAccessDenied(
        'device_inactive',
        'This phone was deactivated.',
      );
    }
    if (device.salesAssistantId != assistant.id) {
      return const SyncAccessDenied(
        'device_not_assigned',
        'This phone is not assigned to the signed-in assistant.',
      );
    }
    return SyncAccessAllowed(
      salesAssistantId: device.salesAssistantId,
      deviceId: device.id,
    );
  }
}

class StampedCall {
  const StampedCall({
    required this.salesAssistantId,
    required this.deviceId,
    required this.androidCallId,
  });

  final String salesAssistantId;
  final String deviceId;
  final String androidCallId;
}

class CallStamp {
  const CallStamp._();

  static StampedCall stamp({
    required SyncAccessAllowed access,
    required String androidCallId,
  }) {
    return StampedCall(
      salesAssistantId: access.salesAssistantId,
      deviceId: access.deviceId,
      androidCallId: androidCallId,
    );
  }
}

class IdentityFields {
  const IdentityFields._();

  static bool clientSuppliedIdentity(Map<String, dynamic> body) {
    return body.containsKey('company_id') ||
        body.containsKey('sales_assistant_id');
  }
}
