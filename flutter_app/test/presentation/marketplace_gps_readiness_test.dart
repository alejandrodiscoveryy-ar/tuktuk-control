import 'package:control_tuk_tuk/services/marketplace_operational_gps_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 10, 15);

  group('Recuperación automática del flujo GPS bloqueado', () {
    bool due({
      bool foreground = true,
      bool expected = true,
      bool ride = true,
      bool blocked = false,
      DateTime? confirmed,
      DateTime? attempted,
    }) => marketplaceGpsForegroundRecoveryDue(
      foreground: foreground,
      locationExpected: expected,
      activeService: ride,
      permissionOrSensorBlocked: blocked,
      lastConfirmedAt: confirmed,
      lastAttemptAt: attempted,
      nowUtc: now,
    );

    test('sin carrera no reinicia por un GPS normal de cuatro minutos', () {
      expect(due(ride: false,
        confirmed: now.subtract(const Duration(minutes: 4))), isFalse);
      expect(due(ride: false,
        confirmed: now.subtract(const Duration(minutes: 7))), isTrue);
    });
    test('durante carrera recupera un flujo atrasado pero no uno reciente', () {
      expect(due(confirmed: now.subtract(const Duration(seconds: 45))), isFalse);
      expect(due(confirmed: now.subtract(const Duration(seconds: 100))), isTrue);
    });
    test('nunca intenta iniciar servicios Android en segundo plano', () {
      expect(due(foreground: false,
        confirmed: now.subtract(const Duration(minutes: 5))), isFalse);
      expect(due(blocked: true,
        confirmed: now.subtract(const Duration(minutes: 5))), isFalse);
      expect(due(expected: false,
        confirmed: now.subtract(const Duration(minutes: 5))), isFalse);
    });
    test('limita reintentos para evitar bucles y desgaste de batería', () {
      final stale = now.subtract(const Duration(minutes: 8));
      expect(due(confirmed: stale, attempted:
        now.subtract(const Duration(seconds: 50))), isFalse);
      expect(due(confirmed: stale, attempted:
        now.subtract(const Duration(minutes: 3))), isTrue);
      expect(due(ride: false, confirmed: stale, attempted:
        now.subtract(const Duration(minutes: 3))), isFalse);
    });
  });

  group('GPS: Trabajando no equivale a ubicación confirmada', () {
    bool needs(bool expected, DateTime? confirmed, {bool failed = false}) =>
        marketplaceGpsNeedsAttention(
          locationExpected: expected,
          lastConfirmedAt: confirmed,
          nowUtc: now,
          hasFailure: failed,
        );

    test('descansando sin ubicación no advierte', () {
      expect(needs(false, null), isFalse);
    });
    test('sin confirmación del servidor sí advierte', () {
      expect(needs(true, null), isTrue);
    });
    test('una publicación reciente confirmada es válida', () {
      expect(needs(true, now.subtract(const Duration(minutes: 2))), isFalse);
    });
    test('en carrera avisa tras 75 segundos sin GPS confirmado', () {
      final recent = now.subtract(const Duration(seconds: 50));
      final stale = now.subtract(const Duration(seconds: 90));
      expect(marketplaceGpsNeedsAttention(
        locationExpected: true, lastConfirmedAt: recent,
        nowUtc: now, hasFailure: false, activeService: true,
      ), isFalse);
      expect(marketplaceGpsNeedsAttention(
        locationExpected: true, lastConfirmedAt: stale,
        nowUtc: now, hasFailure: false, activeService: true,
      ), isTrue);
      // Fuera de carrera, mantiene la politica existente de cinco minutos.
      expect(marketplaceGpsNeedsAttention(
        locationExpected: true, lastConfirmedAt: stale,
        nowUtc: now, hasFailure: false,
      ), isFalse);
    });

    test('posición atrasada, futura o error activo requieren atención', () {
      expect(needs(true, now.subtract(const Duration(minutes: 6))), isTrue);
      expect(needs(true, now.add(const Duration(minutes: 1))), isTrue);
      expect(needs(true, now, failed: true), isTrue);
    });
  });
}
