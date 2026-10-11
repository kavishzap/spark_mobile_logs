class AssistantAccess {
  const AssistantAccess({required this.id, required this.isActive});

  final String id;
  final bool isActive;
}

class DeviceAccess {
  const DeviceAccess({
    required this.id,
    required this.salesAssistantId,
    required this.isActive,
  });

  final String id;
  final String salesAssistantId;
  final bool isActive;
}

sealed class EnrollmentDecision {
  const EnrollmentDecision();
}

class EnrollmentAllowed extends EnrollmentDecision {
  const EnrollmentAllowed({required this.createDevice, this.deviceId});

  final bool createDevice;
  final String? deviceId;
}

class EnrollmentDenied extends EnrollmentDecision {
  const EnrollmentDenied(this.code, this.message);

  final String code;
  final String message;
}

class EnrollmentPolicy {
  const EnrollmentPolicy._();

  static EnrollmentDecision evaluate({
    required AssistantAccess assistant,
    required List<DeviceAccess> devices,
    required String jwtUserId,
    required String boundAssistantId,
  }) {
    if (jwtUserId.isEmpty || boundAssistantId.isEmpty) {
      return const EnrollmentDenied(
        'unauthenticated',
        'Sign in before registering this phone.',
      );
    }
    if (assistant.id != boundAssistantId) {
      return const EnrollmentDenied(
        'identity_mismatch',
        'This sign-in does not match the registered assistant.',
      );
    }
    if (!assistant.isActive) {
      return const EnrollmentDenied(
        'assistant_inactive',
        'This sales assistant account is inactive. Contact your administrator.',
      );
    }

    final own = devices
        .where((device) => device.salesAssistantId == assistant.id)
        .toList();
    if (own.isNotEmpty) {
      final active = own.where((device) => device.isActive);
      final chosen = active.isEmpty ? own.first : active.first;
      return EnrollmentAllowed(createDevice: false, deviceId: chosen.id);
    }
    return const EnrollmentAllowed(createDevice: true);
  }
}
