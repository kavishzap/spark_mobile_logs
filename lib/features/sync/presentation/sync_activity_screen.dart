import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_sales/core/platform/call_log_platform.dart';
import 'package:spark_sales/features/sync/presentation/sync_controller.dart';
import 'package:spark_sales/shared/formatters.dart';
import 'package:spark_sales/shared/widgets/common_widgets.dart';

class SyncActivityScreen extends ConsumerWidget {
  const SyncActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sync activity')),
      body: sync.when(
        data: (snapshot) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _statusLabel(snapshot.status, snapshot.busy),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Last sync ${formatTimestamp(snapshot.lastSuccessAt)}'),
                  const SizedBox(height: 4),
                  Text(
                    'Last attempt ${formatTimestamp(snapshot.lastAttemptAt)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Metric(
              label: 'Records uploaded',
              value: '${snapshot.lastUploaded}',
            ),
            const SizedBox(height: 8),
            _Metric(
              label: 'Pending records',
              value: '${snapshot.pending + snapshot.syncing}',
            ),
            const SizedBox(height: 8),
            _Metric(label: 'Failed records', value: '${snapshot.failed}'),
            if (snapshot.lastError != null) ...[
              const SizedBox(height: 12),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last synchronization error',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(snapshot.lastError!),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              CallLogPlatform.supported
                  ? 'Background sync is scheduled for about every 15 minutes while monitoring is on. '
                        'Android may delay it because of battery optimization, Doze, or the phone maker\'s restrictions.'
                  : 'Call synchronization is not available on iPhone. iOS does not let this app read the cellular call log.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: !CallLogPlatform.supported || snapshot.busy
                  ? null
                  : () =>
                        ref.read(syncControllerProvider.notifier).retryFailed(),
              child: snapshot.busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Retry synchronization'),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.sync_problem,
          message: 'Could not load sync activity. $error',
        ),
      ),
    );
  }

  String _statusLabel(String status, bool busy) {
    if (busy) {
      return 'Synchronizing';
    }
    return switch (status) {
      'success' => 'Up to date',
      'failed' => 'Sync needs attention',
      'idle' => 'Waiting for new calls',
      _ => 'Sync status: $status',
    };
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
