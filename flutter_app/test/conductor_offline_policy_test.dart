import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local access only blocks confirmed suspension', () {
    for (final status in ConductorAppAccessState.values) {
      expect(conductorLocalAccessBlocked(suspensionCached: false, access: status),
          status == ConductorAppAccessState.suspended);
      expect(conductorLocalAccessBlocked(suspensionCached: true, access: status),
          isTrue);
    }
  });

  test('green sync requires authorized account, last success and empty queue', () {
    ConductorSyncIndicator state({
      bool authenticated = true,
      ConductorAppAccessState access = ConductorAppAccessState.allowed,
      bool syncing = false,
      bool failed = false,
      int pending = 0,
      bool hasLastSync = true,
    }) => conductorSyncIndicator(authenticated: authenticated, access: access,
      syncing: syncing, failed: failed, pending: pending, hasLastSync: hasLastSync);
    expect(state(), ConductorSyncIndicator.synchronized);
    expect(state(pending: 1), ConductorSyncIndicator.pending);
    expect(state(hasLastSync: false), ConductorSyncIndicator.pending);
    expect(state(syncing: true), ConductorSyncIndicator.syncing);
    expect(state(failed: true), ConductorSyncIndicator.offline);
    expect(state(access: ConductorAppAccessState.unavailable), ConductorSyncIndicator.offline);
    expect(state(access: ConductorAppAccessState.checking), ConductorSyncIndicator.checking);
    expect(state(authenticated: false), ConductorSyncIndicator.signedOut);
  });
}
