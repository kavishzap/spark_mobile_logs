import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spark_sales/features/auth/domain/session_state.dart';
import 'package:spark_sales/features/auth/presentation/connection_screen.dart';
import 'package:spark_sales/features/auth/presentation/login_screen.dart';
import 'package:spark_sales/features/auth/presentation/session_controller.dart';
import 'package:spark_sales/features/auth/presentation/splash_screen.dart';
import 'package:spark_sales/features/call_logs/presentation/call_history_screen.dart';
import 'package:spark_sales/features/dashboard/presentation/dashboard_screen.dart';
import 'package:spark_sales/features/settings/presentation/disclosure_screen.dart';
import 'package:spark_sales/features/settings/presentation/settings_screen.dart';
import 'package:spark_sales/features/sync/presentation/sync_activity_screen.dart';
import 'package:spark_sales/shared/widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final asyncSession = ref.read(sessionControllerProvider);
      final location = state.matchedLocation;
      if (asyncSession.isLoading) {
        return location == '/splash' ? null : '/splash';
      }
      if (asyncSession.hasError) {
        return location == '/login' ? null : '/login';
      }
      final session = asyncSession.requireValue;
      switch (session.phase) {
        case SessionPhase.unconfigured:
        case SessionPhase.signedOut:
          return location == '/login' ? null : '/login';
        case SessionPhase.connectionIssue:
          return location == '/connection' ? null : '/connection';
        case SessionPhase.needsDisclosure:
          return location == '/disclosure' ? null : '/disclosure';
        case SessionPhase.ready:
          const blocked = {'/splash', '/login', '/disclosure', '/connection'};
          if (blocked.contains(location)) {
            return '/dashboard';
          }
          return null;
      }
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/connection',
        builder: (context, state) => const ConnectionScreen(),
      ),
      GoRoute(
        path: '/disclosure',
        builder: (context, state) => const DisclosureScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calls',
                builder: (context, state) => const CallHistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/sync',
                builder: (context, state) => const SyncActivityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    _subscription = ref.listen(sessionControllerProvider, (previous, next) {
      notifyListeners();
    });
  }

  late final ProviderSubscription<AsyncValue<SessionState>> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
