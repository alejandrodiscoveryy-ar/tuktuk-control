import 'package:control_tuk_tuk/main.dart';
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
        const Duration(minutes: 4),
      );
      expect(
        MarketplaceOperationalLocationPolicy.distanceThresholdMeters(
          activeService: false,
        ),
        200,
      );
    });

    test('aumenta precision solo durante servicio activo', () {
      expect(
        MarketplaceOperationalLocationPolicy.sampleInterval(
          activeService: true,
        ),
        const Duration(seconds: 30),
      );
      expect(
        MarketplaceOperationalLocationPolicy.heartbeatInterval(
          activeService: true,
        ),
        const Duration(seconds: 75),
      );
      expect(
        MarketplaceOperationalLocationPolicy.distanceThresholdMeters(
          activeService: true,
        ),
        50,
      );
    });
  });
}
