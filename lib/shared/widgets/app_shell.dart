import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_sales/features/auth/domain/session_state.dart';
import 'package:spark_sales/features/auth/presentation/session_controller.dart';
import 'package:spark_sales/features/sync/presentation/sync_controller.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  var _wasOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncIfReady();
      _watchConnectivity();
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(sessionControllerProvider.notifier).refreshAccess().then((_) {
        _syncIfReady();
      });
    }
  }

  Future<void> _watchConnectivity() async {
    final current = await _connectivity.checkConnectivity();
    if (!mounted) {
      return;
    }
    _wasOffline = !_isOnline(current);
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final online = _isOnline(results);
      if (online && _wasOffline) {
        _syncIfReady();
      }
      _wasOffline = !online;
    });
  }

  bool _isOnline(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  void _syncIfReady() {
    final phase = ref.read(sessionControllerProvider).asData?.value.phase;
    if (phase == SessionPhase.ready) {
      ref.read(syncControllerProvider.notifier).syncNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionControllerProvider, (previous, next) {
      final wasReady = previous?.asData?.value.phase == SessionPhase.ready;
      final isReady = next.asData?.value.phase == SessionPhase.ready;
      if (isReady && !wasReady) {
        ref.read(syncControllerProvider.notifier).syncNow();
      }
    });

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (index) {
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.call_outlined),
            selectedIcon: Icon(Icons.call),
            label: 'Calls',
          ),
          NavigationDestination(icon: Icon(Icons.sync), label: 'Sync'),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
