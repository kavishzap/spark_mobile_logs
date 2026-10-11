import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_sales/core/constants/app_constants.dart';
import 'package:spark_sales/features/auth/presentation/session_controller.dart';

class ConnectionScreen extends ConsumerWidget {
  const ConnectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).asData?.value;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                Icons.cloud_off,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Could not reach ${AppConstants.appName}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(session?.message ?? 'Check the network and try again.'),
              const Spacer(),
              FilledButton(
                onPressed: session?.busy == true
                    ? null
                    : () => ref
                          .read(sessionControllerProvider.notifier)
                          .retryConnection(),
                child: const Text('Try again'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.read(sessionControllerProvider.notifier).signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
