import 'dart:io';

/// Cellular call history can be read on Android. iOS does not offer that API.
class CallLogPlatform {
  const CallLogPlatform._();

  static bool get supported => Platform.isAndroid;
}
