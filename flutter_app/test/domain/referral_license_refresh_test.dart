import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReferralLicenseRefreshCoordinator', () {
    test('fuerza referidos y después fuerza la licencia', () async {
      final calls = <String>[];
      bool? referralsForced;
      bool? licenseForced;
      final coordinator = ReferralLicenseRefreshCoordinator(
        refreshReferrals: ({required bool force}) async {
          referralsForced = force;
          calls.add('referrals');
        },
        refreshLicense: ({required bool force}) async {
          licenseForced = force;
          calls.add('license');
          return LicenseSnapshot.local;
        },
      );

      await coordinator.refresh();

      expect(referralsForced, isTrue);
      expect(licenseForced, isTrue);
      expect(calls, ['referrals', 'license']);
    });
  });

  group('LicenseResumeRefreshPolicy', () {
    LicenseSnapshot snapshot(LicenseStatus status, {bool canWrite = false}) =>
        LicenseSnapshot(
          planId: 'personal',
          licenseStatus: status,
          canWrite: canWrite,
          validatedFromServer: true,
          lastServerValidation: DateTime.utc(2026, 8, 29),
        );

    test('expired fuerza revalidación inmediata al reanudar', () {
      expect(
        LicenseResumeRefreshPolicy.requiresImmediateValidation(
          snapshot(LicenseStatus.expired),
        ),
        isTrue,
      );
    });

    test('active normal conserva los intervalos de caché', () {
      expect(
        LicenseResumeRefreshPolicy.requiresImmediateValidation(
          snapshot(LicenseStatus.active, canWrite: true),
        ),
        isFalse,
      );
    });

    test('estados bloqueados siguen sin permiso de escritura', () {
      for (final status in [
        LicenseStatus.pending,
        LicenseStatus.suspended,
        LicenseStatus.revoked,
      ]) {
        final blocked = snapshot(status);
        expect(blocked.canWrite, isFalse, reason: status.name);
        expect(
          LicenseResumeRefreshPolicy.requiresImmediateValidation(blocked),
          isFalse,
          reason: status.name,
        );
      }
    });
  });
}
