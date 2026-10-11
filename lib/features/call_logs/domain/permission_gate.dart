enum CollectionBlock {
  none,
  signedOut,
  disclosureRequired,
  permissionDenied,
  monitoringDisabled,
}

class PermissionGate {
  const PermissionGate._();

  static CollectionBlock evaluate({
    required bool signedIn,
    required bool disclosureAccepted,
    required bool permissionGranted,
    required bool monitoringEnabled,
  }) {
    if (!signedIn) {
      return CollectionBlock.signedOut;
    }
    if (!disclosureAccepted) {
      return CollectionBlock.disclosureRequired;
    }
    if (!permissionGranted) {
      return CollectionBlock.permissionDenied;
    }
    if (!monitoringEnabled) {
      return CollectionBlock.monitoringDisabled;
    }
    return CollectionBlock.none;
  }
}
