import 'package:flutter/material.dart';
import 'package:spark_sales/core/constants/app_constants.dart';
import 'package:spark_sales/shared/widgets/brand_mark.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BrandMark(),
                SizedBox(height: 20),
                Text(
                  AppConstants.appName,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text('Company call records'),
                SizedBox(height: 28),
                CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
