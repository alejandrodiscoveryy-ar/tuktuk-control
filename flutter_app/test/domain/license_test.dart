import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 29, 12);

  Map<String, dynamic> license({
    String status = 'active',
    DateTime? expiresAt,
    int maxDevices = 1,
  }) =>
      {
        'status': status,
        'expires_at': expiresAt?.toIso8601String(),
        'max_devices': maxDevices,
        'plan': 'personal',
      };

  LicenseSnapshot evaluate(
    Map<String, dynamic>? value, {
    Map<String, dynamic>? deviceValidation,
    DateTime? profileCreatedAt,
  }) =>
      LicenseAccessEvaluator.fromRemote(
        license: value,
        profileCreatedAt: profileCreatedAt,
        now: now,
        deviceValidation: deviceValidation,
      );

  test('active vigente y dispositivo aceptado permite escritura', () {
    final result = evaluate(
      license(expiresAt: now.add(const Duration(days: 10))),
      deviceValidation: {'valid': true, 'reason': 'active'},
    );

    expect(result.licenseStatus, LicenseStatus.active);
    expect(result.canWrite, isTrue);
  });

  for (final status in ['pending', 'expired', 'suspended', 'revoked']) {
    test('$status mantiene la aplicación en solo lectura', () {
      final result = evaluate(license(status: status));

      expect(result.canWrite, isFalse);
      expect(result.isReadOnly, isTrue);
    });
  }

  test('active con vencimiento pasado queda en solo lectura', () {
    final result = evaluate(
      license(expiresAt: now.subtract(const Duration(seconds: 1))),
      deviceValidation: {'valid': true, 'reason': 'active'},
    );

    expect(result.licenseStatus, LicenseStatus.expired);
    expect(result.canWrite, isFalse);
  });

  test('límite de dispositivos impide escritura', () {
    final result = evaluate(
      license(expiresAt: now.add(const Duration(days: 10))),
      deviceValidation: {
        'valid': false,
        'reason': 'device_limit_reached',
      },
    );

    expect(result.licenseStatus, LicenseStatus.deviceLimitReached);
    expect(result.canWrite, isFalse);
  });

  test('periodo inicial permite 30 días y luego pasa a solo lectura', () {
    final activeTrial = evaluate(
      null,
      profileCreatedAt: now.subtract(const Duration(days: 29)),
    );
    final expiredTrial = evaluate(
      null,
      profileCreatedAt: now.subtract(const Duration(days: 31)),
    );

    expect(activeTrial.licenseStatus, LicenseStatus.trial);
    expect(activeTrial.canWrite, isTrue);
    expect(expiredTrial.licenseStatus, LicenseStatus.expired);
    expect(expiredTrial.canWrite, isFalse);
  });

  test('licencia reactivada recupera escritura', () {
    final suspended = evaluate(license(status: 'suspended'));
    final reactivated = evaluate(
      license(expiresAt: now.add(const Duration(days: 30))),
      deviceValidation: {'valid': true, 'reason': 'active'},
    );

    expect(suspended.canWrite, isFalse);
    expect(reactivated.canWrite, isTrue);
  });

  test('sin conexión no reactiva una licencia inactiva almacenada', () {
    final cached = evaluate(license(status: 'revoked'));
    final offline = LicenseAccessEvaluator.revalidateCached(
      cached,
      now.add(const Duration(days: 1)),
    );

    expect(offline.canWrite, isFalse);
    expect(offline.licenseStatus, LicenseStatus.revoked);
  });
}
