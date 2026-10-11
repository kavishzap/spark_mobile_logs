class AppException implements Exception {
  const AppException(
    this.code,
    this.message, {
    this.retryable = false,
    this.revokesAccess = false,
  });

  final String code;
  final String message;
  final bool retryable;
  final bool revokesAccess;

  @override
  String toString() => message;
}
