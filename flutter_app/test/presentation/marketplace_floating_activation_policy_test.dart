import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Boton flotante automatico', () {
    test('Trabajar en Android activa el icono sin preferencia extra', () {
      expect(marketplaceFloatingVisible(isAndroid: true, working: true), isTrue);
      expect(marketplaceFloatingVisible(isAndroid: true, working: false), isFalse);
      expect(marketplaceFloatingVisible(isAndroid: false, working: true), isFalse);
    });

    test('solo pedir permiso a conductor trabajando cuando falta', () {
      expect(
        marketplaceFloatingPermissionRequired(
          isAndroid: true, working: true, canDraw: false,
        ),
        isTrue,
      );
      expect(
        marketplaceFloatingPermissionRequired(
          isAndroid: true, working: true, canDraw: true,
        ),
        isFalse,
      );
      expect(
        marketplaceFloatingPermissionRequired(
          isAndroid: true, working: false, canDraw: false,
        ),
        isFalse,
      );
      expect(
        marketplaceFloatingPermissionRequired(
          isAndroid: false, working: true, canDraw: false,
        ),
        isFalse,
      );
    });
  });
}
