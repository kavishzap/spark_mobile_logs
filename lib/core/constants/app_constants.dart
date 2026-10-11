class AppConstants {
  const AppConstants._();

  static const appName = 'Spark Mauritius Sales Monitoring System';
  static const callSyncUniqueName = 'spark-sales-call-sync';
  static const callSyncTaskName = 'callSync';
  static const periodicInterval = Duration(minutes: 15);
  static const checkpointOverlap = Duration(hours: 6);
  static const batchSize = 50;
  static const readLimit = 2000;
  static const maxRetryCount = 10;
  static const terminalRetryCount = 10;
  static const lockStaleAfter = Duration(minutes: 2);
}
