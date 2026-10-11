import 'package:spark_sales/features/devices/domain/enrollment_models.dart';

enum SessionPhase {
  unconfigured,
  signedOut,
  connectionIssue,
  needsDisclosure,
  ready,
}

class SessionState {
  const SessionState({
    required this.phase,
    this.assistant,
    this.device,
    this.message,
    this.busy = false,
    this.permissionGranted = false,
    this.monitoringEnabled = true,
    this.disclosureAccepted = false,
  });

  const SessionState.unconfigured()
    : this(phase: SessionPhase.unconfigured, monitoringEnabled: false);

  const SessionState.signedOut({String? message})
    : this(
        phase: SessionPhase.signedOut,
        message: message,
        monitoringEnabled: false,
      );

  final SessionPhase phase;
  final AssistantProfile? assistant;
  final RegisteredDevice? device;
  final String? message;
  final bool busy;
  final bool permissionGranted;
  final bool monitoringEnabled;
  final bool disclosureAccepted;

  bool get canCollect =>
      phase == SessionPhase.ready &&
      permissionGranted &&
      disclosureAccepted &&
      monitoringEnabled;

  SessionState copyWith({
    SessionPhase? phase,
    AssistantProfile? assistant,
    RegisteredDevice? device,
    String? message,
    bool clearMessage = false,
    bool? busy,
    bool? permissionGranted,
    bool? monitoringEnabled,
    bool? disclosureAccepted,
  }) {
    return SessionState(
      phase: phase ?? this.phase,
      assistant: assistant ?? this.assistant,
      device: device ?? this.device,
      message: clearMessage ? null : message ?? this.message,
      busy: busy ?? this.busy,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      monitoringEnabled: monitoringEnabled ?? this.monitoringEnabled,
      disclosureAccepted: disclosureAccepted ?? this.disclosureAccepted,
    );
  }
}
