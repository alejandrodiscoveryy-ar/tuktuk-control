import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:control_tuk_tuk/main.dart';
import 'package:image/image.dart' as img;

const code = '0123456789abcdef0123456789abcdef';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('copy and QR use the one personal URL, not an internal identifier', () {
    final uri = marketplaceDriverPromoUri(code);
    expect(uri.host, 'www.vrixora.com');
    expect(uri.path, '/cliente/tuk/');
    expect(uri.queryParameters, {'conductor': code});
    expect(marketplaceDriverPromoCopy('Gerson', code), contains(uri.toString()));
    final copy = marketplaceDriverPromoCopy('Gerson', code);
    expect(copy, contains('Soy Gerson, conductor de TukTuk.'));
    expect(copy, contains('Tu conductor de confianza, a un toque.'));
    expect(copy, isNot(contains('otro conductor')));
    expect(copy, isNot(contains('flota')));
    expect(() => marketplaceDriverPromoUri('invalid'), throwsArgumentError);
    expect(marketplaceDriverPromoQr(code).moduleCount, 41);
  });

  for (final story in [false, true]) {
    testWidgets('export embeds QR modules with quiet zone in ${story ? 'story' : 'square'} PNG', (tester) async {
      final bytes = await tester.runAsync(() => renderMarketplaceDriverPromoCard(
        name: 'Gerson', code: code, modality: 'Triciclo · Pasajeros', story: story));
      expect(bytes, isNotNull);
      final png = img.decodePng(bytes!)!;
      expect(png.width, 1080);
      expect(png.height, story ? 1920 : 1080);
      final qr = marketplaceDriverPromoQr(code);
      final x = story ? 368 : 78;
      final y = story ? 1160 : 578;
      expect(png.getPixel(x + 5, y + 5).r, 255);
      for (var row = 0; row < qr.moduleCount; row++) {
        for (var col = 0; col < qr.moduleCount; col++) {
          final pixel = png.getPixel(x + (col + 4) * 7 + 3, y + (row + 4) * 7 + 3);
          final expected = qr.isDark(row, col) ? 0 : 255;
          expect([pixel.r, pixel.g, pixel.b], [expected, expected, expected], reason: 'module $row,$col');
        }
      }
    });
  }

  test('sharing and download remain gated by own enabled profile and generated image', () {
    final source = File('lib/presentation/marketplace_driver_promotion.dart').readAsStringSync();
    expect(source, contains('get_my_marketplace_promo_profile'));
    expect(source, contains('set_my_marketplace_promo_profile'));
    expect(source, contains('target_share_photo'));
    expect(source, contains('files: [XFile.fromData'));
    expect(source, contains('text: copy'));
    expect(source, contains('assets/branding/tuktuk_logo_transparent.png'));
    expect(source, contains('driver_promo_download.downloadPromoPng'));
    expect(source, contains('auth.currentUser?.id == _actor'));
    expect(source, isNot(contains('claim_referral_code')));
    expect(source, isNot(contains('Si no estoy disponible')));
    expect(source, isNot(contains('Toda una flota a tu disposición')));
    expect(source, contains('Solicita tu transporte desde mi enlace personal.'));
  });
}
