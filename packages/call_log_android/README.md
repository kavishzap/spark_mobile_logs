# call_log_android

Android plugin that reads the cellular call log and requests `READ_CALL_LOG`.

It is a plugin, rather than a method channel registered only on `MainActivity`, so the WorkManager background Flutter engine can read call history too. Spark Mauritius Sales Monitoring System depends on this package. Run and test the app from the repository root.
