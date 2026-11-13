import 'dart:io';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:control_tuk_tuk/main.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
    expect(copy, contains('Soy Gerson, conductor de la Agencia TukTuk.'));
    expect(copy, contains('Tu conductor de confianza, a un toque.'));
    expect(copy, isNot(contains('otro conductor')));
    expect(copy, isNot(contains('flota')));
    expect(() => marketplaceDriverPromoUri('invalid'), throwsArgumentError);
    expect(marketplaceDriverPromoQr(code).moduleCount, 41);
  });

  testWidgets('agency promotion uses only the approved master icon', (tester) async {
    const identity = ProjectIdentity(
      projectId: 'test', name: 'TukTuk Conductor',
      primaryColorHex: '#06B6D4', secondaryColorHex: '#0F172A',
      logoUrl: 'https://example.com/control-wordmark.png',
      iconUrl: 'https://example.com/approved-icon.png',
    );
    final pixels = img.Image(width: 4, height: 4);
    img.fill(pixels, color: img.ColorRgb8(10, 200, 100));
    final png = img.encodePng(pixels);
    final requests = <String>[];
    final client = MockClient((request) async {
      requests.add(request.url.path);
      return http.Response.bytes(png, 200);
    });
    addTearDown(client.close);
    final bytes = await tester.runAsync(() =>
      loadMarketplacePromoBrandLogo(identity, client: client));
    expect(bytes, orderedEquals(png));
    expect(requests, ['/approved-icon.png']);
    final failed = MockClient((request) async {
      expect(request.url.path, '/approved-icon.png');
      return http.Response('unavailable', 404);
    });
    addTearDown(failed.close);
    final missing = await tester.runAsync(() =>
      loadMarketplacePromoBrandLogo(identity, client: failed));
    expect(missing, isNull);
    final noIcon = await tester.runAsync(() =>
      loadMarketplacePromoBrandLogo(ProjectIdentity.fallback));
    expect(noIcon, isNull);
  });

  test('cache persists both formats, isolates accounts, replaces and revokes', () async {
    final dir = await Directory.systemTemp.createTemp('promo-artwork-');
    Hive.init(dir.path);
    final box = await Hive.openBox('promo_artwork_test');
    try {
      final cache = MarketplacePromoArtworkCache(box);
      final square = Uint8List.fromList([1, 2, 3]);
      final story = Uint8List.fromList([4, 5, 6]);
      await cache.save('driver-a', 'v1', square, story);
      expect(cache.read('driver-b', 'v1'), isNull);
      expect(cache.read('driver-a', 'v2'), isNull);
      await box.close();
      final reopened = await Hive.openBox('promo_artwork_test');
      final persisted = MarketplacePromoArtworkCache(reopened);
      expect(persisted.read('driver-a', 'v1')?.square, orderedEquals(square));
      expect(persisted.read('driver-a', 'v1')?.story, orderedEquals(story));
      await persisted.save('driver-a', 'v2', story, square);
      expect(persisted.read('driver-a', 'v1'), isNull);
      expect(persisted.read('driver-a', 'v2')?.square, orderedEquals(story));
      await persisted.clear('driver-a');
      expect(persisted.read('driver-a', 'v2'), isNull);
      await reopened.close();
    } finally {
      await Hive.close();
      await dir.delete(recursive: true);
    }
  });

  test('cache fingerprint ignores signed photo token but detects real changes', () {
    String key({String actor = 'driver-a', String name = 'Gerson',
      String modality = 'Auto · Pasajeros', bool authorized = true,
      String url = 'https://example.com/photo/one.png?token=first',
      ProjectIdentity identity = ProjectIdentity.fallback}) =>
        marketplacePromoCacheFingerprint(actor: actor, code: code, name: name,
          modality: modality, photoAuthorized: authorized, photoUrl: Uri.parse(url),
          identity: identity);
    final original = key();
    expect(key(url: 'https://example.com/photo/one.png?token=second'), original);
    expect(key(url: 'https://example.com/photo/two.png?token=first'), isNot(original));
    expect(key(name: 'Otro'), isNot(original));
    expect(key(actor: 'driver-b'), isNot(original));
    expect(key(modality: 'Moto · Mensajería'), isNot(original));
    expect(key(authorized: false), isNot(original));
    expect(key(identity: const ProjectIdentity(projectId: 'other', name: 'TukTuk',
      primaryColorHex: '#06B6D4', secondaryColorHex: '#0F172A',
      iconUrl: 'https://example.com/icon.png')), isNot(original));
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
    expect(source, isNot(contains('assets/branding/tuktuk_logo_transparent.png')));
    expect(source, contains('widget.store.refreshProjectIdentity()'));
    expect(source, contains('widget.store.projectIdentity'));
    expect(source, contains('loadMarketplacePromoBrandLogo(identity)'));
    expect(source, contains('identity.iconUrl'));
    expect(source, isNot(contains('identity.logoUrl')));
    expect(source, contains('Rect.fromLTWH(72, headerY, 136, 136)'));
    expect(source, contains('panelShape'));
    expect(source, contains('_cache.read(_actor!, fingerprint)'));
    expect(source, contains('_cache.save(_actor!, fingerprint, square, story)'));
    expect(source, contains('_load(force: true)'));
    expect(source, contains('_cache.clear(_actor!)'));
    expect(source.indexOf('_cache.read(_actor!, fingerprint)'), lessThan(source.indexOf('await downloadMarketplacePromoPortrait(validPhotoUrl)')));
    expect(source, contains('driver_promo_download.downloadPromoPng'));
    expect(source, contains('auth.currentUser?.id == _actor'));
    expect(source, isNot(contains('claim_referral_code')));
    expect(source, isNot(contains('Si no estoy disponible')));
    expect(source, isNot(contains('Toda una flota a tu disposición')));
    expect(source, contains('Solicita tu transporte desde mi enlace personal.'));
    expect(source, contains("'Conductor de la Agencia TukTuk'"));
    expect(source, contains("'Agencia TukTuk'"));
    expect(source, contains('identity.primaryColorHex'));
    expect(source, contains('identity.secondaryColorHex'));
  });
}
