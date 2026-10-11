import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.adminEmail,
    required this.lookback,
    required this.localRetention,
  });

  static const _compileTime = AppConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    adminEmail: String.fromEnvironment(
      'ADMIN_EMAIL',
      defaultValue: 'admin@example.com',
    ),
    lookback: Duration(
      days: int.fromEnvironment('LOOKBACK_DAYS', defaultValue: 30),
    ),
    localRetention: Duration(
      days: int.fromEnvironment('LOCAL_RETENTION_DAYS', defaultValue: 90),
    ),
  );

  static AppConfig instance = _compileTime;
  static bool _loaded = false;

  /// Reads the project `.env` bundled with the app. Release builds include
  /// that file, so `flutter run` and `flutter build` use the same values.
  static Future<void> load() async {
    if (_loaded) {
      return;
    }
    Map<String, String> env = const {};
    try {
      env = parseEnvFile(await rootBundle.loadString('.env'));
    } catch (error) {
      debugPrint('Could not read .env: $error');
    }
    instance = AppConfig(
      supabaseUrl: _value(env, const [
        'NEXT_PUBLIC_SUPABASE_URL',
        'SUPABASE_URL',
      ], _compileTime.supabaseUrl),
      supabaseAnonKey: _value(env, const [
        'NEXT_PUBLIC_SUPABASE_ANON_KEY',
        'SUPABASE_ANON_KEY',
      ], _compileTime.supabaseAnonKey),
      adminEmail: _value(env, const [
        'ADMIN_EMAIL',
      ], _compileTime.adminEmail),
      lookback: Duration(
        days: _days(env, 'LOOKBACK_DAYS', _compileTime.lookback.inDays),
      ),
      localRetention: Duration(
        days: _days(
          env,
          'LOCAL_RETENTION_DAYS',
          _compileTime.localRetention.inDays,
        ),
      ),
    );
    _loaded = true;
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String adminEmail;
  final Duration lookback;
  final Duration localRetention;

  bool get isConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
}

Map<String, String> parseEnvFile(String contents) {
  final values = <String, String>{};
  for (final rawLine in contents.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    final separator = line.indexOf('=');
    if (separator <= 0) {
      continue;
    }
    final key = line.substring(0, separator).trim();
    var value = line.substring(separator + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    values[key] = value;
  }
  return values;
}

String _value(Map<String, String> env, List<String> keys, String fallback) {
  for (final key in keys) {
    final value = env[key]?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return fallback;
}

int _days(Map<String, String> env, String key, int fallback) {
  final parsed = int.tryParse(env[key]?.trim() ?? '');
  if (parsed == null || parsed < 0) {
    return fallback;
  }
  return parsed;
}
