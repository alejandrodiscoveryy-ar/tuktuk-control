import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 10, 15);

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
    test('posición atrasada, futura o error activo requieren atención', () {
      expect(needs(true, now.subtract(const Duration(minutes: 6))), isTrue);
      expect(needs(true, now.add(const Duration(minutes: 1))), isTrue);
      expect(needs(true, now, failed: true), isTrue);
    });
  });
}
