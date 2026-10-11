import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_sales/core/platform/call_log_platform.dart';
import 'package:spark_sales/features/auth/presentation/session_controller.dart';
import 'package:spark_sales/features/call_logs/data/call_queue_repository.dart';
import 'package:spark_sales/features/sync/presentation/sync_controller.dart';
import 'package:spark_sales/shared/formatters.dart';
import 'package:spark_sales/shared/widgets/common_widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).asData?.value;
    final stats = ref.watch(dashboardStatsProvider);
    final sync = ref.watch(syncControllerProvider).asData?.value;
    final scheme = Theme.of(context).colorScheme;
    final lastSync = _latest(sync?.lastSuccessAt, session?.device?.lastSyncAt);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(syncControllerProvider.notifier).syncNow(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              session?.assistant?.fullName.isNotEmpty == true
                  ? session!.assistant!.fullName
                  : 'Sales assistant',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(session?.device?.deviceModel ?? 'Registered phone'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusChip(
                  label: session?.device?.isActive == true
                      ? 'Device registered'
                      : 'Device inactive',
                  color: session?.device?.isActive == true
                      ? scheme.primary
                      : scheme.error,
                ),
                StatusChip(
                  label: !CallLogPlatform.supported
                      ? 'Call log unavailable'
                      : session?.permissionGranted == true
                      ? 'Call log allowed'
                      : 'Permission missing',
                  color: CallLogPlatform.supported &&
                          session?.permissionGranted == true
                      ? scheme.primary
                      : scheme.error,
                ),
              ],
            ),
            if (!CallLogPlatform.supported) ...[
              const SizedBox(height: 12),
              const _Banner(
                message:
                    'This iPhone can sign in and register, but iOS does not let apps read the cellular call log. Call synchronization runs on the Android company phone.',
              ),
            ],
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last successful synchronization',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(formatTimestamp(lastSync)),
                  const SizedBox(height: 4),
                  Text(
                    '${sync?.pending ?? stats.asData?.value.pending ?? 0} waiting to sync',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            stats.when(
              data: (value) => _StatsGrid(stats: value),
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) =>
                  Text('Could not load today\'s calls. $error'),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: !CallLogPlatform.supported || sync?.busy == true
                  ? null
                  : () => ref.read(syncControllerProvider.notifier).syncNow(),
              icon: sync?.busy == true
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: const Text('Sync Now'),
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _latest(DateTime? local, DateTime? remote) {
    if (local == null) {
      return remote;
    }
    if (remote == null) {
      return local;
    }
    return local.isAfter(remote) ? local : remote;
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Stat(label: 'Incoming today', value: '${stats.incoming}'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Stat(label: 'Outgoing today', value: '${stats.outgoing}'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Stat(label: 'Missed today', value: '${stats.missed}'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Stat(
                label: 'Duration today',
                value: formatDuration(stats.durationSeconds),
              ),
            ),
          ],
        ),
        if (stats.rejected > 0 || stats.blocked > 0) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Rejected ${stats.rejected} · Blocked ${stats.blocked}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message),
    );
  }
}
