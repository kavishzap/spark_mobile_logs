import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_sales/app/dependencies.dart';
import 'package:spark_sales/core/config/app_config.dart';
import 'package:spark_sales/core/platform/call_log_platform.dart';
import 'package:spark_sales/core/constants/app_constants.dart';
import 'package:spark_sales/core/errors/app_exception.dart';
import 'package:spark_sales/features/auth/domain/session_state.dart';
import 'package:spark_sales/features/devices/domain/enrollment_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, SessionState>(
      SessionController.new,
    );

class SessionController extends AsyncNotifier<SessionState> {
  @override
  Future<SessionState> build() {
    return _establish();
  }

  Future<void> signIn(String email, String password) async {
    final previous = state.asData?.value ?? const SessionState.signedOut();
    state = AsyncData(previous.copyWith(busy: true, clearMessage: true));
    try {
      final fullName = await ref
          .read(authRepositoryProvider)
          .signIn(email, password);
      await ref.read(secureStoreProvider).writeAssistantName(fullName);
      state = AsyncData(await _establish());
    } on AuthException catch (error) {
      state = AsyncData(SessionState.signedOut(message: _friendlyAuth(error)));
    } catch (error) {
      state = AsyncData(
        previous.copyWith(
          busy: false,
          message: error is AppException
              ? error.message
              : 'Could not sign in. Try again.',
        ),
      );
    }
  }

  Future<void> retryConnection() async {
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData(current.copyWith(busy: true, clearMessage: true));
    }
    state = AsyncData(await _establish());
  }

  Future<void> completePermission() async {
    final secure = ref.read(secureStoreProvider);
    await secure.acceptDisclosure(DateTime.now().toUtc());
    await ref.read(syncSchedulerProvider).ensureScheduled();
    final current = state.requireValue;
    state = AsyncData(
      current.copyWith(
        phase: SessionPhase.ready,
        permissionGranted: true,
        disclosureAccepted: true,
        monitoringEnabled: true,
        busy: false,
        clearMessage: true,
      ),
    );
  }

  Future<void> refreshAccess() async {
    final current = state.asData?.value;
    if (current == null ||
        current.phase == SessionPhase.signedOut ||
        current.phase == SessionPhase.unconfigured) {
      return;
    }
    if (current.phase == SessionPhase.connectionIssue) {
      state = AsyncData(await _establish());
      return;
    }
    try {
      final permission = await ref
          .read(callLogReaderProvider)
          .permissionStatus();
      final secure = ref.read(secureStoreProvider);
      final disclosure = await secure.disclosureAccepted();
      final needsDisclosure =
          CallLogPlatform.supported && (!disclosure || !permission.granted);
      final scheduler = ref.read(syncSchedulerProvider);
      if (needsDisclosure || !CallLogPlatform.supported) {
        await scheduler.cancel();
      } else {
        await scheduler.ensureScheduled();
      }
      state = AsyncData(
        current.copyWith(
          phase: needsDisclosure
              ? SessionPhase.needsDisclosure
              : SessionPhase.ready,
          permissionGranted: permission.granted,
          disclosureAccepted: disclosure,
          monitoringEnabled: true,
        ),
      );
    } catch (error) {
      debugPrint('Access refresh failed: $error');
    }
  }

  Future<void> signOut() async {
    await _deprovision();
    state = const AsyncData(SessionState.signedOut());
  }

  Future<void> revoke(String message) async {
    await _deprovision();
    state = AsyncData(SessionState.signedOut(message: message));
  }

  Future<SessionState> _establish() async {
    if (!AppConfig.instance.isConfigured) {
      return const SessionState.unconfigured();
    }
    final auth = ref.read(authRepositoryProvider);
    if (auth.currentSession == null) {
      return const SessionState.signedOut();
    }
    try {
      final fullName = await ref.read(secureStoreProvider).readAssistantName();
      if (fullName == null || fullName.trim().isEmpty) {
        await _deprovision();
        return const SessionState.signedOut(
          message: 'Sign in with your name and work email.',
        );
      }
      final hardware = await ref.read(deviceInfoReaderProvider).read();
      final enrollment = await ref
          .read(enrollmentApiProvider)
          .enroll(hardware.toJson(fullName: fullName.trim()));
      await ref.read(secureStoreProvider).writeDeviceId(enrollment.device.id);
      return _sessionFromEnrollment(enrollment);
    } on AppException catch (error) {
      if (error.revokesAccess) {
        await _deprovision();
        return SessionState.signedOut(message: error.message);
      }
      return SessionState(
        phase: SessionPhase.connectionIssue,
        message: error.message,
      );
    } catch (error) {
      debugPrint('Enrollment failed: $error');
      return const SessionState(
        phase: SessionPhase.connectionIssue,
        message: '${AppConstants.appName} could not verify this phone. Try again.',
      );
    }
  }

  Future<SessionState> _sessionFromEnrollment(
    EnrollmentResult enrollment,
  ) async {
    final secure = ref.read(secureStoreProvider);
    final disclosure = await secure.disclosureAccepted();
    final permission = await ref.read(callLogReaderProvider).permissionStatus();
    final needsDisclosure =
        CallLogPlatform.supported && (!disclosure || !permission.granted);
    final scheduler = ref.read(syncSchedulerProvider);
    if (!needsDisclosure && CallLogPlatform.supported) {
      await scheduler.ensureScheduled();
    } else {
      await scheduler.cancel();
    }
    return SessionState(
      phase: needsDisclosure
          ? SessionPhase.needsDisclosure
          : SessionPhase.ready,
      assistant: enrollment.assistant,
      device: enrollment.device,
      permissionGranted: permission.granted,
      monitoringEnabled: true,
      disclosureAccepted: disclosure,
    );
  }

  Future<void> _deprovision() async {
    try {
      await ref.read(syncSchedulerProvider).cancel();
    } catch (error) {
      debugPrint('Could not cancel background sync: $error');
    }
    await ref.read(callQueueRepositoryProvider).wipe();
    await ref.read(secureStoreProvider).clearSession();
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (error) {
      debugPrint('Sign out failed: $error');
    }
  }

  String _friendlyAuth(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid') || message.contains('credentials')) {
      return 'Email or password is incorrect.';
    }
    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('host')) {
      return 'No network connection. Try again when the phone is online.';
    }
    return error.message;
  }
}
