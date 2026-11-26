import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only confirmed or cached suspension blocks local control', () {
    for (final state in ConductorAppAccessState.values) {
      expect(conductorLocalAccessBlocked(suspensionCached: false, access: state),
        state == ConductorAppAccessState.suspended);
      expect(conductorLocalAccessBlocked(suspensionCached: true, access: state), isTrue);
    }
  });

  test('sync indicator never reports green for unverified or failed sync', () {
    ConductorSyncIndicator status({
      ConductorAppAccessState access = ConductorAppAccessState.allowed,
      bool authenticated = true, bool syncing = false, bool failed = false,
      int pending = 0, bool last = true,
    }) => conductorSyncIndicator(authenticated: authenticated, access: access,
      syncing: syncing, failed: failed, pending: pending, hasLastSync: last);
    expect(status(), ConductorSyncIndicator.synchronized);
    expect(status(pending: 2), ConductorSyncIndicator.pending);
    expect(status(last: false), ConductorSyncIndicator.pending);
    expect(status(syncing: true), ConductorSyncIndicator.syncing);
    expect(status(failed: true), ConductorSyncIndicator.offline);
    expect(status(access: ConductorAppAccessState.checking), ConductorSyncIndicator.checking);
    expect(status(access: ConductorAppAccessState.unavailable), ConductorSyncIndicator.offline);
    expect(status(access: ConductorAppAccessState.suspended), ConductorSyncIndicator.offline);
    expect(status(authenticated: false), ConductorSyncIndicator.signedOut);
  });
}
