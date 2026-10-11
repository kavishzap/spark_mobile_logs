import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_sales/features/call_logs/data/call_queue_repository.dart';
import 'package:spark_sales/features/call_logs/domain/call_record.dart';
import 'package:spark_sales/features/call_logs/presentation/call_history_controller.dart';
import 'package:spark_sales/features/sync/presentation/sync_controller.dart';
import 'package:spark_sales/shared/formatters.dart';
import 'package:spark_sales/shared/widgets/common_widgets.dart';

class CallHistoryScreen extends ConsumerStatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  ConsumerState<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends ConsumerState<CallHistoryScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(callHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Call history')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Search phone number',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                ref.read(callHistoryProvider.notifier).setSearch(value);
              },
            ),
          ),
          SizedBox(
            height: 48,
            child: history.maybeWhen(
              data: (state) => _Filters(state: state),
              orElse: () => const SizedBox.shrink(),
            ),
          ),
          Expanded(
            child: history.when(
              skipLoadingOnReload: true,
              data: (state) {
                if (state.calls.isEmpty) {
                  return const EmptyState(
                    icon: Icons.call,
                    message: 'No calls match this view.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(syncControllerProvider.notifier).syncNow(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: state.calls.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _CallTile(call: state.calls[index]),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EmptyState(
                icon: Icons.error_outline,
                message: 'Could not load calls. $error',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Filters extends ConsumerWidget {
  const _Filters({required this.state});

  final CallHistoryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(callHistoryProvider.notifier);
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _chip('All calls', state.type == null, () => controller.setType(null)),
        _chip(
          'Incoming',
          state.type == CallType.incoming,
          () => controller.setType(CallType.incoming),
        ),
        _chip(
          'Outgoing',
          state.type == CallType.outgoing,
          () => controller.setType(CallType.outgoing),
        ),
        _chip(
          'Missed',
          state.type == CallType.missed,
          () => controller.setType(CallType.missed),
        ),
        _chip(
          'Today',
          state.preset == DateRangePreset.today,
          () => controller.setPreset(DateRangePreset.today),
        ),
        _chip(
          'Last 7 days',
          state.preset == DateRangePreset.last7Days,
          () => controller.setPreset(DateRangePreset.last7Days),
        ),
        _chip(
          state.preset == DateRangePreset.custom
              ? 'Custom range'
              : 'Custom date range',
          state.preset == DateRangePreset.custom,
          () => _pickRange(context, controller),
        ),
        if (state.preset != DateRangePreset.all)
          _chip(
            'Any date',
            false,
            () => controller.setPreset(DateRangePreset.all),
          ),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }

  Future<void> _pickRange(
    BuildContext context,
    CallHistoryController controller,
  ) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 366)),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: state.customStart ?? now.subtract(const Duration(days: 7)),
        end: state.customEnd ?? now,
      ),
    );
    if (range == null) {
      return;
    }
    await controller.setCustomRange(range.start, range.end);
  }
}

class _CallTile extends StatelessWidget {
  const _CallTile({required this.call});

  final CallRecord call;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (call.callType) {
      CallType.incoming => (Icons.call_received, scheme.primary),
      CallType.outgoing => (Icons.call_made, scheme.tertiary),
      CallType.missed => (Icons.call_missed, scheme.error),
      CallType.rejected => (Icons.call_end, scheme.error),
      CallType.blocked => (Icons.block, scheme.outline),
    };
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(displayPhone(call.phoneNumber)),
        subtitle: Text(
          '${formatCallDate(call.callDate)} · ${formatCallTime(call.callDate)} · ${formatDuration(call.durationSeconds)}',
        ),
        trailing: StatusChip(
          label: call.syncStatus.name,
          color: switch (call.syncStatus) {
            SyncStatus.synced => scheme.primary,
            SyncStatus.failed => scheme.error,
            SyncStatus.syncing => scheme.tertiary,
            SyncStatus.pending => scheme.outline,
          },
        ),
      ),
    );
  }
}
