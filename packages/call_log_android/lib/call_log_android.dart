import 'package:flutter/services.dart';

class CallLogPermissionStatus {
  const CallLogPermissionStatus({
    required this.granted,
    required this.shouldShowRationale,
  });

  final bool granted;
  final bool shouldShowRationale;
}

class CallLogAndroid {
  CallLogAndroid({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.spark.sales/call_log');

  final MethodChannel _channel;

  Future<CallLogPermissionStatus> permissionStatus() async {
    final raw = await _channel.invokeMapMethod<String, Object?>(
      'permissionStatus',
    );
    return CallLogPermissionStatus(
      granted: raw?['granted'] == true,
      shouldShowRationale: raw?['shouldShowRationale'] == true,
    );
  }

  Future<bool> requestPermission() async {
    final granted = await _channel.invokeMethod<bool>('requestPermission');
    return granted ?? false;
  }

  Future<bool> openAppSettings() async {
    final opened = await _channel.invokeMethod<bool>('openAppSettings');
    return opened ?? false;
  }

  Future<List<Map<dynamic, dynamic>>> readCalls({
    required int sinceMillis,
    int limit = 2000,
  }) async {
    final raw = await _channel.invokeMethod<List<dynamic>>('readCalls', {
      'sinceMillis': sinceMillis,
      'limit': limit,
    });
    if (raw == null) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map((row) => Map<dynamic, dynamic>.from(row))
        .toList(growable: false);
  }
}
