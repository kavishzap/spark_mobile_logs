class AssistantProfile {
  const AssistantProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.isActive,
  });

  final String id;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final bool isActive;

  factory AssistantProfile.fromJson(Map<String, dynamic> json) {
    return AssistantProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: json['phone_number'] as String?,
      isActive: json['is_active'] == true,
    );
  }
}

class RegisteredDevice {
  const RegisteredDevice({
    required this.id,
    required this.deviceName,
    required this.deviceModel,
    required this.androidVersion,
    required this.appVersion,
    required this.isActive,
    required this.lastSyncAt,
  });

  final String id;
  final String deviceName;
  final String deviceModel;
  final String androidVersion;
  final String appVersion;
  final bool isActive;
  final DateTime? lastSyncAt;

  factory RegisteredDevice.fromJson(Map<String, dynamic> json) {
    final rawSync = json['last_sync_at'] as String?;
    return RegisteredDevice(
      id: json['id'] as String,
      deviceName: json['device_name'] as String? ?? '',
      deviceModel: json['device_model'] as String? ?? '',
      androidVersion: json['android_version'] as String? ?? '',
      appVersion: json['app_version'] as String? ?? '',
      isActive: json['is_active'] == true,
      lastSyncAt: rawSync == null ? null : DateTime.tryParse(rawSync)?.toUtc(),
    );
  }
}

class EnrollmentResult {
  const EnrollmentResult({required this.assistant, required this.device});

  final AssistantProfile assistant;
  final RegisteredDevice device;

  factory EnrollmentResult.fromJson(Map<String, dynamic> json) {
    return EnrollmentResult(
      assistant: AssistantProfile.fromJson(
        Map<String, dynamic>.from(json['assistant'] as Map),
      ),
      device: RegisteredDevice.fromJson(
        Map<String, dynamic>.from(json['device'] as Map),
      ),
    );
  }
}
