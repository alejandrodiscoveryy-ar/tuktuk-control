import 'package:control_tuk_tuk/services/marketplace_operational_gps_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MarketplaceOperationalLocationPolicy', () {
    test('solo considera activos los estados que requieren seguimiento', () {
      expect(
        MarketplaceOperationalLocationPolicy.isActiveServiceStatus('accepted'),
        isTrue,
      );
      expect(
        MarketplaceOperationalLocationPolicy.isActiveServiceStatus('en_route'),
        isTrue,
      );
      expect(
        MarketplaceOperationalLocationPolicy.isActiveServiceStatus('pickup'),
        isTrue,
      );
      expect(
        MarketplaceOperationalLocationPolicy.isActiveServiceStatus(
          'in_progress',
        ),
        isTrue,
      );
      expect(
        MarketplaceOperationalLocationPolicy.isActiveServiceStatus('incident'),
        isTrue,
      );

      expect(
        MarketplaceOperationalLocationPolicy.isActiveServiceStatus('published'),
        isFalse,
      );
      expect(
        MarketplaceOperationalLocationPolicy.isActiveServiceStatus('completed'),
        isFalse,
      );
      expect(
        MarketplaceOperationalLocationPolicy.isActiveServiceStatus(
          'cancelled_by_customer',
        ),
        isFalse,
      );
    });

    test('reduce frecuencia cuando solo esta disponible', () {
      expect(
        MarketplaceOperationalLocationPolicy.sampleInterval(
          activeService: false,
        ),
        const Duration(minutes: 2),
      );
      expect(
        MarketplaceOperationalLocationPolicy.heartbeatInterval(
          activeService: false,
        ),
        const Duration(seconds: 120),
      );
      expect(
        MarketplaceOperationalLocationPolicy.distanceThresholdMeters(
          activeService: false,
        ),
        75,
      );
    });

    test('Android sigue enviando ubicacion estando disponible', () {
      expect(
        MarketplaceOperationalLocationPolicy.usesContinuousStream(
          isAndroid: true,
          activeService: false,
        ),
        isTrue,
      );
      expect(
        MarketplaceOperationalLocationPolicy.streamInterval(
          activeService: false,
        ),
        const Duration(seconds: 60),
      );
    });

    test(
      'el navegador no finge seguimiento continuo cuando esta disponible',
      () {
        expect(
          MarketplaceOperationalLocationPolicy.usesContinuousStream(
            isAndroid: false,
            activeService: false,
          ),
          isFalse,
        );
        expect(
          MarketplaceOperationalLocationPolicy.usesContinuousStream(
            isAndroid: false,
            activeService: true,
          ),
          isTrue,
        );
      },
    );

    test('en web usa posicion actual cuando el conductor esta disponible', () {
      expect(
        MarketplaceOperationalLocationPolicy.shouldReadLastKnownPosition(
          activeService: false,
          isWeb: true,
        ),
        isFalse,
      );
      expect(
        MarketplaceOperationalLocationPolicy.shouldReadLastKnownPosition(
          activeService: false,
          isWeb: false,
        ),
        isTrue,
      );
      expect(
        MarketplaceOperationalLocationPolicy.shouldReadLastKnownPosition(
          activeService: true,
          isWeb: false,
        ),
        isFalse,
      );
    });
    test('usa backoff ante fallos transitorios sin agotar bateria', () {
      expect(
        MarketplaceOperationalLocationPolicy.failureRetryDelay(
          activeService: false,
        ),
        const Duration(minutes: 5),
      );
      expect(
        MarketplaceOperationalLocationPolicy.failureRetryDelay(
          activeService: true,
        ),
        const Duration(seconds: 30),
      );
    });

    test('descarta fixes retrasados o con reloj futuro', () {
      final now = DateTime.utc(2026, 10, 27, 18, 0, 0);
      bool recent(int ageSeconds, {required bool activeService}) =>
          MarketplaceOperationalLocationPolicy.isFreshStreamFix(
            capturedAt: now.subtract(Duration(seconds: ageSeconds)),
            nowUtc: now,
            activeService: activeService,
          );

      expect(recent(110, activeService: false), isTrue);
      expect(recent(130, activeService: false), isFalse);
      expect(recent(40, activeService: true), isTrue);
      expect(recent(50, activeService: true), isFalse);
      expect(recent(-5, activeService: false), isTrue);
      expect(recent(-6, activeService: false), isFalse);
    });

    test('valida metricas GPS sin aceptar NaN ni valores negativos', () {
      expect(MarketplaceOperationalLocationPolicy.safeMetric(20, min: 0, max: 5000), 20);
      expect(MarketplaceOperationalLocationPolicy.safeMetric(-1, min: 0, max: 5000), isNull);
      expect(MarketplaceOperationalLocationPolicy.safeMetric(double.nan, min: 0, max: 5000), isNull);
      expect(MarketplaceOperationalLocationPolicy.safeMetric(5001, min: 0, max: 5000), isNull);
    });

    test('cada incidencia GPS conserva el mensaje original', () {
      expect(marketplaceGpsWarningMessage(null),
          'GPS sin confirmar. Toca para comprobar la ubicación.');
      expect(marketplaceGpsWarningMessage(MarketplaceGpsIssue.locationDisabled),
          contains('GPS desactivado'));
      expect(marketplaceGpsWarningMessage(MarketplaceGpsIssue.permissionDenied),
          contains('permiso GPS'));
      expect(marketplaceGpsWarningMessage(MarketplaceGpsIssue.deliveryFailed),
          contains('Comprueba tu conexión'));
    });

    test('usa seguimiento mas frecuente durante servicio activo', () {
      expect(
        MarketplaceOperationalLocationPolicy.sampleInterval(
          activeService: true,
        ),
        const Duration(seconds: 15),
      );
      expect(
        MarketplaceOperationalLocationPolicy.heartbeatInterval(
          activeService: true,
        ),
        const Duration(seconds: 30),
      );
      expect(
        MarketplaceOperationalLocationPolicy.distanceThresholdMeters(
          activeService: true,
        ),
        15,
      );
    });
  });
}
