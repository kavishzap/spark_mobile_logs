import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_sales/app/app.dart';
import 'package:spark_sales/features/sync/data/background_sync.dart';
import 'package:workmanager/workmanager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensureSupabase();
  if (Platform.isAndroid) {
    await Workmanager().initialize(callbackDispatcher);
  }
  runApp(const ProviderScope(child: SparkSalesApp()));
}
