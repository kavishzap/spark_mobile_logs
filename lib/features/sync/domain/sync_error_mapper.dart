import 'dart:convert';

import 'package:spark_sales/core/errors/app_exception.dart';

class SyncErrorMapper {
  const SyncErrorMapper._();

  static const revocationCodes = {
    'assistant_inactive',
    'assistant_not_found',
    'device_inactive',
    'device_not_assigned',
    'company_unauthorized',
    'name_mismatch',
    'identity_mismatch',
    'unauthenticated',
    'email_unconfirmed',
  };

  static AppException fromStatus(int status, Object? details) {
    final decoded = _decode(details);
    final code = _code(status, decoded);
    final message = _message(status, decoded);
    final revokes = revocationCodes.contains(code);
    final retryable =
        !revokes &&
        (status == 0 || status == 408 || status == 429 || status >= 500);
    return AppException(
      code,
      message,
      retryable: retryable,
      revokesAccess: revokes,
    );
  }

  static Object? _decode(Object? details) {
    if (details is String) {
      try {
        return jsonDecode(details);
      } catch (_) {
        return details;
      }
    }
    return details;
  }

  static String _code(int status, Object? decoded) {
    if (decoded is Map && decoded['error'] is String) {
      return decoded['error'] as String;
    }
    if (status == 401) {
      return 'unauthenticated';
    }
    return 'sync_failed';
  }

  static String _message(int status, Object? decoded) {
    if (decoded is Map && decoded['message'] is String) {
      return decoded['message'] as String;
    }
    if (decoded is String && decoded.trim().isNotEmpty) {
      return decoded.trim();
    }
    if (status == 0) {
      return 'No network connection. Calls stay on this phone until sync can finish.';
    }
    return 'Sync failed ($status).';
  }
}
