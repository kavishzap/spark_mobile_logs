import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_sales/core/platform/call_log_platform.dart';
import 'package:spark_sales/features/auth/presentation/session_controller.dart';
import 'package:spark_sales/features/settings/presentation/disclosure_screen.dart';
import 'package:spark_sales/shared/widgets/common_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).asData?.value;
    final assistant = session?.assistant;
    final device = session?.device;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _Group(
            title: 'Employee',
            rows: [
              _Row('Name', assistant?.fullName ?? '—'),
              _Row('Email', assistant?.email ?? '—'),
              _Row('Phone', assistant?.phoneNumber ?? '—'),
            ],
          ),
          const SizedBox(height: 12),
          _Group(
            title: 'Device',
            rows: [
              _Row('Name', device?.deviceName ?? '—'),
              _Row('Model', device?.deviceModel ?? '—'),
              _Row('System version', device?.androidVersion ?? '—'),
              _Row('App version', device?.appVersion ?? '—'),
              _Row(
                'Registration',
                device?.isActive == true ? 'Registered' : 'Inactive',
              ),
              _Row(
                'Call log permission',
                !CallLogPlatform.supported
                    ? 'Not available on iPhone'
                    : session?.permissionGranted == true
                    ? 'Allowed'
                    : 'Not allowed',
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              title: const Text('Privacy and monitoring'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDisclosure(context),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => _signOut(context, ref),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDisclosure(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: const [DisclosureCopy()],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Call collection stops and the local call queue on this phone is deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(sessionControllerProvider.notifier).signOut();
    }
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.rows});

  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final row in rows) row,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '—' : value)),
        ],
      ),
    );
  }
}
