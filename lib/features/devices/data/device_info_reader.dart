import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DeviceHardware {
  const DeviceHardware({
    required this.deviceName,
    required this.deviceModel,
    required this.androidVersion,
    required this.appVersion,
  });

  final String deviceName;
  final String deviceModel;
  final String androidVersion;
  final String appVersion;

  Map<String, dynamic> toJson({required String fullName}) {
    return {
      'full_name': fullName,
      'device_name': deviceName,
      'device_model': deviceModel,
      'android_version': androidVersion,
      'app_version': appVersion,
    };
  }
}

class DeviceInfoReader {
  const DeviceInfoReader();

  Future<DeviceHardware> read() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    final plugin = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final ios = await plugin.iosInfo;
      final machine = ios.utsname.machine.trim();
      final name = ios.name.trim();
      return DeviceHardware(
        deviceName: name.isEmpty ? 'iPhone' : name,
        deviceModel: machine.isEmpty ? ios.model : machine,
        androidVersion: 'iOS ${ios.systemVersion}',
        appVersion: appVersion,
      );
    }
    final android = await plugin.androidInfo;
    final manufacturer = android.manufacturer.trim();
    final model = android.model.trim();
    final name = '$manufacturer $model'.trim();
    return DeviceHardware(
      deviceName: name.isEmpty ? model : name,
      deviceModel: model.isEmpty ? 'Unknown' : model,
      androidVersion: android.version.release,
      appVersion: appVersion,
    );
  }
}
