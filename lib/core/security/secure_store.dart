import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class SecureStore {
  SecureStore({FlutterSecureStorage? storage, Uuid? uuid})
    : _storage = storage ?? const FlutterSecureStorage(),
      _uuid = uuid ?? const Uuid();

  static const installationKey = 'installation_id';
  static const assistantNameKey = 'assistant_full_name';
  static const deviceKey = 'device_id';
  static const disclosureKey = 'disclosure_accepted_at';
  static const monitoringKey = 'monitoring_enabled';

  final FlutterSecureStorage _storage;
  final Uuid _uuid;

  Future<String> installationId() async {
    final existing = await _storage.read(key: installationKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final created = _uuid.v4();
    await _storage.write(key: installationKey, value: created);
    return created;
  }

  Future<String?> readAssistantName() => _storage.read(key: assistantNameKey);

  Future<void> writeAssistantName(String fullName) {
    return _storage.write(key: assistantNameKey, value: fullName.trim());
  }

  Future<String?> readDeviceId() => _storage.read(key: deviceKey);

  Future<void> writeDeviceId(String deviceId) {
    return _storage.write(key: deviceKey, value: deviceId);
  }

  Future<bool> disclosureAccepted() async {
    final value = await _storage.read(key: disclosureKey);
    return value != null && value.isNotEmpty;
  }

  Future<void> acceptDisclosure(DateTime at) {
    return _storage.write(
      key: disclosureKey,
      value: at.toUtc().toIso8601String(),
    );
  }

  /// Removes the device session. The installation id stays on this phone.
  Future<void> clearSession() async {
    await _storage.delete(key: deviceKey);
    await _storage.delete(key: assistantNameKey);
    await _storage.delete(key: disclosureKey);
    await _storage.delete(key: monitoringKey);
  }
}
