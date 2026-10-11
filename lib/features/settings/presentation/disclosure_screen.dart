import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_sales/app/dependencies.dart';
import 'package:spark_sales/core/errors/app_exception.dart';
import 'package:spark_sales/features/auth/presentation/session_controller.dart';
import 'package:spark_sales/features/settings/presentation/monitoring_disclosure.dart';

class DisclosureScreen extends ConsumerStatefulWidget {
  const DisclosureScreen({super.key});

  @override
  ConsumerState<DisclosureScreen> createState() => _DisclosureScreenState();
}

class _DisclosureScreenState extends ConsumerState<DisclosureScreen> {
  var _accepted = false;
  var _busy = false;
  var _permanentlyDenied = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Call monitoring')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              'This company phone records cellular call metadata and sends it to your employer.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            const DisclosureCopy(),
            const SizedBox(height: 16),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _accepted,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _accepted = value ?? false),
              title: const Text(
                'I understand that this company phone records cellular call metadata.',
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_permanentlyDenied) ...[
              const SizedBox(height: 12),
              const PermissionDeniedNotice(),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy ? null : _openSettings,
                child: const Text('Open app settings'),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _requestAccess,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Allow call log access'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () =>
                        ref.read(sessionControllerProvider.notifier).signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestAccess() async {
    if (!_accepted) {
      setState(() {
        _error =
            'Confirm that you understand this company phone records cellular call metadata.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final reader = ref.read(callLogReaderProvider);
      final granted = await reader.requestPermission();
      if (!mounted) {
        return;
      }
      if (!granted) {
        final status = await reader.permissionStatus();
        if (!mounted) {
          return;
        }
        setState(() {
          _permanentlyDenied = !status.shouldShowRationale;
          _error =
              'Call synchronization cannot run until call log access is allowed.';
          _busy = false;
        });
        return;
      }
      await ref.read(sessionControllerProvider.notifier).completePermission();
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Call log permission could not be requested.';
        _busy = false;
      });
    }
  }

  Future<void> _openSettings() async {
    await ref.read(callLogReaderProvider).openAppSettings();
  }
}

class DisclosureCopy extends StatelessWidget {
  const DisclosureCopy({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final section in MonitoringDisclosure.sections) ...[
          _DisclosureBlock(section: section),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _DisclosureBlock extends StatelessWidget {
  const _DisclosureBlock({required this.section});

  final DisclosureSection section;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(section.body),
          ],
        ),
      ),
    );
  }
}

class PermissionDeniedNotice extends StatelessWidget {
  const PermissionDeniedNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Call synchronization cannot run until this phone allows call log access. '
        'Enable it in system settings, then return to the app.',
        style: TextStyle(color: scheme.onErrorContainer),
      ),
    );
  }
}
