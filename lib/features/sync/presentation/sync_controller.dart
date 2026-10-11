import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_sales/app/dependencies.dart';
import 'package:spark_sales/features/auth/domain/session_state.dart';
import 'package:spark_sales/features/auth/presentation/session_controller.dart';
import 'package:spark_sales/features/call_logs/data/call_queue_repository.dart';
import 'package:spark_sales/features/sync/domain/sync_models.dart';
import 'package:spark_sales/features/sync/domain/sync_uploader.dart';

final syncGenerationProvider = NotifierProvider<SyncGeneration, int>(
  SyncGeneration.new,
);

class SyncGeneration extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final syncControllerProvider =
    AsyncNotifierProvider<SyncController, SyncSnapshot>(SyncController.new);

class SyncController extends AsyncNotifier<SyncSnapshot> {
  @override
  Future<SyncSnapshot> build() {
    return ref.watch(callQueueRepositoryProvider).snapshot();
  }

  Future<void> syncNow() async {
    final current = state.asData?.value;
    if (current?.busy == true) {
      return;
    }
    if (current != null) {
      state = AsyncData(current.copyWith(busy: true));
    }
    final session = ref.read(sessionControllerProvider).asData?.value;
    if (session == null || session.phase != SessionPhase.ready) {
      if (current != null) {
        state = AsyncData(current.copyWith(busy: false));
      }
      return;
    }

    try {
      final result = await ref
          .read(callSyncServiceProvider)
          .synchronize(
            SyncRequest(
              signedIn: true,
              disclosureAccepted: session.disclosureAccepted,
              permissionGranted: session.permissionGranted,
              monitoringEnabled: session.monitoringEnabled,
              deviceId: session.device?.id,
            ),
          );
      if (result.outcome == SyncOutcome.revoked) {
        await ref
            .read(sessionControllerProvider.notifier)
            .revoke(
              result.message ?? 'Access to call synchronization was removed.',
            );
      } else if (result.code == 'permission_denied') {
        await ref.read(sessionControllerProvider.notifier).refreshAccess();
      }
    } catch (error, stackTrace) {
      debugPrint('Sync failed: $error\n$stackTrace');
      try {
        await ref
            .read(callQueueRepositoryProvider)
            .recordFailure(
              'Could not synchronize calls.',
              DateTime.now().toUtc(),
            );
      } catch (recordError) {
        debugPrint('Could not record sync failure: $recordError');
      }
    }
    try {
      final snapshot = await ref.read(callQueueRepositoryProvider).snapshot();
      state = AsyncData(snapshot.copyWith(busy: false));
    } catch (error, stackTrace) {
      debugPrint('Could not refresh sync status: $error\n$stackTrace');
      if (current != null) {
        state = AsyncData(current.copyWith(busy: false));
      }
    }
    ref.read(syncGenerationProvider.notifier).bump();
  }

  Future<void> retryFailed() async {
    await ref.read(callQueueRepositoryProvider).resetFailed();
    await syncNow();
  }
}

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  ref.watch(syncGenerationProvider);
  final repository = ref.watch(callQueueRepositoryProvider);
  return repository.todayStats(DateTime.now());
});
