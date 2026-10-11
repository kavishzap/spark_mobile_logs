import 'package:spark_sales/core/constants/app_constants.dart';

class RetryPolicy {
  const RetryPolicy._();

  static Duration delayFor(int retryCount) {
    if (retryCount <= 0) {
      return Duration.zero;
    }
    final exponent = retryCount.clamp(1, 6);
    final minutes = (1 << exponent).clamp(1, 60);
    return Duration(minutes: minutes);
  }

  static bool isReady({
    required int retryCount,
    required DateTime? lastAttemptAt,
    required DateTime now,
  }) {
    if (retryCount >= AppConstants.maxRetryCount) {
      return false;
    }
    if (lastAttemptAt == null) {
      return true;
    }
    final earliest = lastAttemptAt.toUtc().add(delayFor(retryCount));
    return !now.toUtc().isBefore(earliest);
  }
}
