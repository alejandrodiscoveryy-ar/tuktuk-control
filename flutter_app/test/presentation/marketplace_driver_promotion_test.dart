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
    expect(copy, isNot(contains('verificado')));
    expect(marketplaceDriverPromoCopy('Gerson', code, identityVerified: true),
      contains('Soy Gerson, conductor verificado de la Agencia TukTuk.'));
    expect(copy, contains('Solicita mi servicio desde este enlace:'));
    expect(copy, contains('¡Tu próximo viaje comienza conmigo!'));
    expect(copy, contains('Tu conductor de confianza, a un toque.'));
    expect(copy, isNot(contains('otro conductor')));
    expect(copy, isNot(contains('flota')));
    expect(() => marketplaceDriverPromoUri('invalid'), throwsArgumentError);
    expect(marketplaceDriverPromoQr(code).moduleCount, 41);
  });

  test('public card lookup retries a database timeout once and never retries missing profile', () async {
    var calls = 0;
    final profile = await loadMarketplaceSharedPromoProfile(() async {
      calls++;
      if (calls == 1) throw StateError('canceling statement due to statement timeout');
      return {'data': {'public_name': 'Demo', 'verified': true, 'promo_alias': 'demo'}};
    }, pause: (_) async {});
    expect(calls, 2);
    expect(profile?['promo_alias'], 'demo');
    calls = 0;
    expect(await loadMarketplaceSharedPromoProfile(() async {
      calls++; return {'data': null};
    }, pause: (_) async {}), isNull);
    expect(calls, 1);
    calls = 0;
    await expectLater(loadMarketplaceSharedPromoProfile(() async {
      calls++; throw StateError('CUSTOMER_RATE_LIMITED');
    }, pause: (_) async {}), throwsStateError);
    expect(calls, 1);
  });

  test('commercial link is short and shared by copy and QR', () {
    final uri = marketplaceDriverPromoUri(code, alias: 'gerson');
    expect(uri.toString(), 'https://www.vrixora.com/tuk/gerson');
    expect(marketplaceDriverPromoDisplayLink(code, alias: 'gerson'), 'vrixora.com/tuk/gerson');
    expect(marketplaceDriverPromoDisplayLink(code, alias: 'otro-conductor'), 'vrixora.com/tuk/otro-conductor');
    expect(marketplaceDriverPromoCopy('Gerson', code, alias: 'gerson'), contains(uri.toString()));
    expect(marketplaceDriverPromoCopy('Gerson', code, alias: 'gerson'), isNot(contains(code)));
    expect(marketplaceDriverPromoQr(code, alias: 'gerson').moduleCount, 41);
    expect(marketplaceDriverPromoAlias('../gerson'), isNull);
    expect(marketplaceDriverPromoAlias('gerson-'), isNull);
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
      ProjectIdentity identity = ProjectIdentity.fallback, bool verified = false,
      String? photoAssetId, String? alias}) =>
        marketplacePromoCacheFingerprint(actor: actor, code: code, alias: alias, name: name,
          modality: modality, photoAuthorized: authorized, photoUrl: Uri.parse(url),
          identity: identity, identityVerified: verified, photoAssetId: photoAssetId);
    final original = key();
    expect(key(alias: 'gerson'), isNot(original));
    expect(key(verified: true), isNot(original));
    expect(key(photoAssetId: 'new-photo'), isNot(original));
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

  test('approved booking asset contains no illustrative QR', () {
    final artwork = img.decodeWebP(File('assets/branding/tuktuk_promo_booking.webp').readAsBytesSync())!;
    expect(artwork.width, 850);
    expect(artwork.height, 365);
    // The reserved well must be blank; only the renderer may add a QR.
    for (var y = 55; y < 300; y += 4) {
      for (var x = 550; x < 795; x += 4) {
        final p = artwork.getPixel(x, y);
        expect(p.r, greaterThan(230));
        expect(p.g, greaterThan(230));
        expect(p.b, greaterThan(230));
      }
    }
  });

  for (final story in [false, true]) {
    testWidgets('export embeds QR modules with quiet zone in ${story ? 'story' : 'square'} PNG', (tester) async {
      final bytes = await tester.runAsync(() => renderMarketplaceDriverPromoCard(
        name: 'Gerson', code: code, alias: 'gerson', modality: 'Triciclo · Pasajeros', story: story));
      expect(bytes, isNotNull);
      final png = img.decodePng(bytes!)!;
      expect(png.width, 1080);
      expect(png.height, story ? 1920 : 1080);
      // Outside the QR the booking panel stays dark, never a white slab.
      final panelPixel = png.getPixel(50, story ? 1520 : 879);
      expect(panelPixel.r < 230 || panelPixel.g < 230 || panelPixel.b < 230, isTrue);
      final qr = marketplaceDriverPromoQr(code, alias: 'gerson');
      final x = story ? 690 : 704;
      final y = story ? 1192 : 594;
      final module = story ? 6 : 5;
      final qrSize = (qr.moduleCount + 8) * module;
      // All four sides preserve a full four-module white quiet zone.
      for (var p = 0; p < qrSize; p++) {
        for (var margin = 0; margin < 4 * module; margin++) {
          for (final pixel in [
            png.getPixel(x + p, y + margin),
            png.getPixel(x + p, y + qrSize - 1 - margin),
            png.getPixel(x + margin, y + p),
            png.getPixel(x + qrSize - 1 - margin, y + p),
          ]) {
            expect([pixel.r, pixel.g, pixel.b], [255, 255, 255]);
          }
        }
      }
      for (var row = 0; row < qr.moduleCount; row++) {
        for (var col = 0; col < qr.moduleCount; col++) {
          final pixel = png.getPixel(x + (col + 4) * module + 3, y + (row + 4) * module + 3);
          final expected = qr.isDark(row, col) ? 0 : 255;
          expect([pixel.r, pixel.g, pixel.b], [expected, expected, expected], reason: 'module $row,$col');
        }
      }
    });
  }

  for (final story in [false, true]) {
    testWidgets('verification badge is exported only for confirmed identity: story=$story', (tester) async {
      final normal = await tester.runAsync(() => renderMarketplaceDriverPromoCard(
        name: 'Alex', code: code, modality: 'Auto · Pasajeros', story: story));
      final verified = await tester.runAsync(() => renderMarketplaceDriverPromoCard(
        name: 'Alex', code: code, modality: 'Auto · Pasajeros', story: story,
        identityVerified: true));
      int bluePixels(Uint8List bytes) {
        final png = img.decodePng(bytes)!;
        var count = 0;
        for (var y = story ? 300 : 230; y < (story ? 455 : 360); y++) {
          for (var x = story ? 486 : 367; x < (story ? 1022 : 704); x++) {
            final p = png.getPixel(x, y);
            if (p.r == 29 && p.g == 155 && p.b == 240) count++;
          }
        }
        return count;
      }
      expect(bluePixels(normal!), 0);
      expect(bluePixels(verified!), greaterThan(300));
    });
  }

  testWidgets('vehicle category changes the watermark in both formats without changing QR', (tester) async {
    for (final story in [false, true]) {
      final car = await tester.runAsync(() => renderMarketplaceDriverPromoCard(
        name: 'Alex', code: code, modality: 'Transporte · Pasajeros',
        story: story, vehicleCategory: 'light_car'));
      for (final category in ['motorcycle', 'tricycle', 'bicitaxi', 'comfort', 'bicycle', 'van', 'truck']) {
        final other = await tester.runAsync(() => renderMarketplaceDriverPromoCard(
          name: 'Alex', code: code, modality: 'Transporte · Pasajeros',
          story: story, vehicleCategory: category));
        final a = img.decodePng(car!)!, b = img.decodePng(other!)!;
        var changes = 0;
        for (var y = story ? 550 : 166; y < (story ? 990 : 464); y += 3) {
          for (var x = story ? 425 : 704; x < 1050; x += 3) {
            final p = a.getPixel(x,y), q = b.getPixel(x,y);
            if (p.r != q.r || p.g != q.g || p.b != q.b) {
              changes++;
            }
          }
        }
        expect(changes, greaterThan(25), reason: category);
        final x = story ? 690 : 704;
        final y = story ? 1192 : 594;
        final module = story ? 6 : 5;
        final size = (marketplaceDriverPromoQr(code).moduleCount + 8) * module;
        for (var dy = 0; dy < size; dy += module) {
          for (var dx = 0; dx < size; dx += module) {
            final p = a.getPixel(x + dx, y + dy), q = b.getPixel(x + dx, y + dy);
            expect([p.r, p.g, p.b], [q.r, q.g, q.b]);
          }
        }
      }
    }
  });


  for (final story in [false, true]) {
    testWidgets('printed link changes with alias in exported PNG: story=$story', (tester) async {
      Future<Uint8List> card(String alias) async => (await tester.runAsync(() =>
        renderMarketplaceDriverPromoCard(name: 'Conductor Demo', code: code,
          alias: alias, modality: 'Triciclo · Pasajeros', story: story,
          identityVerified: true, vehicleCategory: 'tricycle')))!;
      final a = img.decodePng(await card('gerson'))!;
      final b = img.decodePng(await card('otro-conductor'))!;
      var different = 0;
      for (var y = story ? 1530 : 889; y < (story ? 1642 : 971); y++) {
        for (var x = 180; x < 1000; x++) {
          final p = a.getPixel(x, y), q = b.getPixel(x, y);
          if (p.r != q.r || p.g != q.g || p.b != q.b) different++;
        }
      }
      expect(different, greaterThan(200));
    });
  }

  test('both formats are visible without selector and have independent actions', () {
    final source = File('lib/presentation/marketplace_driver_promotion.dart').readAsStringSync();
    expect(source, isNot(contains('SegmentedButton<bool>')));
    expect(source, contains('_formatCard(context, story: false, ready: ready)'));
    expect(source, contains('_formatCard(context, story: true, ready: ready)'));
    expect(source, contains('mi-tuktuk-share-story'));
    expect(source, contains('mi-tuktuk-share-square'));
    expect(source, contains('mi-tuktuk-download-story'));
    expect(source, contains('mi-tuktuk-download-square'));
    expect(source, contains('_shareCard(story: story)'));
    expect(source, contains('_downloadCard(story: story)'));
    expect(source, contains('_artworkFor(story)'));
    expect(source, contains('_fileNameFor(story)'));
    expect(source, contains("story ? 'Mi-TukTuk-historia.png' : 'Mi-TukTuk.png'"));
    expect(source, contains('text: copy'));
  });

  test('sharing and download remain gated by own enabled profile and generated image', () {
    final source = File('lib/presentation/marketplace_driver_promotion.dart').readAsStringSync();
    expect(source, contains('prepare_my_marketplace_promo_card_v1'));
    expect(source, isNot(contains('publish_my_marketplace_promo_card_v1')));
    expect(source, contains('revoke_my_marketplace_promo_card_v1'));
    expect(source, isNot(contains('Activar mi perfil')));
    expect(source, isNot(contains('CheckboxListTile')));
    expect(source, isNot(contains('_ensurePublished')));
    expect(source, isNot(contains('Al compartir, descargar o copiar el enlace')));
    expect(source, contains('active Mi TukTuk desde Administración'));
    expect(source, contains('_copyText(marketplaceDriverPromoUri(_code!, alias: _alias).toString())'));
    expect(source, contains('ExpansionTile('));
    expect(source, contains('showDialog<bool>'));
    expect(source, contains('confirmed == true && mounted'));
    expect(source, contains('final ready = previewReady;'));
    expect(source, contains("storage.from('marketplace-media').createSignedUrl"));
    expect(source, contains('files: [XFile.fromData'));
    expect(source, contains('text: copy'));
    expect(source, isNot(contains('assets/branding/tuktuk_logo_transparent.png')));
    expect(source, contains('widget.store.refreshProjectIdentity()'));
    expect(source, contains('widget.store.projectIdentity'));
    expect(source, contains('loadMarketplacePromoBrandLogo(identity)'));
    expect(source, contains('identity.iconUrl'));
    expect(source, isNot(contains('identity.logoUrl')));
    expect(source, contains('Rect.fromLTWH(72, headerY, iconSize, iconSize)'));
    expect(source, contains('const _marketplacePromoArtworkVersion = 17;'));
    expect(source, contains("result['identity_verified'] == true"));
    expect(source, contains('identityVerified: identityVerified'));
    expect(source, contains('vehicleCategory: vehicleCategory'));
    expect(source, contains('_promoVehicleWatermark(canvas, vehicleCategory, vehicleArea, accent)'));
    expect(source, contains('identityVerified, vehicleCategory'));
    expect(source, contains('Color(0xFF1D9BF0)'));
    expect(source, contains('weight: FontWeight.w900'));
    expect(source, contains('_promoReferenceBooking(canvas, bookingArea)'));
    expect(source, contains('_promoLightFrame(canvas, ctaShape, neon'));
    expect(source, contains('_promoGlossyPill(canvas, linkShape, modalityAccent)'));
    expect(source, contains('painter.computeLineMetrics().last'));
    expect(source, contains('final vehicleRibbon = ui.Path()'));
    expect(source, contains('final bottomBand = ui.Path()'));
    expect(source, contains('italic: true'));
    expect(source, contains('final lowerSweep = ui.Path()'));
    expect(source, contains('final module = story ? 6.0 : 5.0;'));
    expect(source, contains('Icons.directions_car'));
    expect(source, contains('vehicleGlyph.paint'));
    expect(source, isNot(contains(r"_promoText(canvas, 'Tu próximo viaje\ncomienza conmigo'")));
    expect(source, contains('Rect.fromLTWH(425, 550, 600, 440)'));
    expect(source, contains('final qrX = story ? 690.0 : 704.0;'));
    expect(source, contains('identityVerified ? (area.width < 400 ? 60.0 : 76.0) : 0.0'));
    expect(source, contains('Rect.fromLTWH(40, 1160, 1000, 365)'));
    expect(source, contains('_cache.read(actor, fingerprint)'));
    expect(source, contains('_cache.save(actor, fingerprint, square, story)'));
    expect(source, contains('_load(force: true)'));
    expect(source, contains('_cache.clear(actor)'));
    expect(source.indexOf('_cache.read(actor, fingerprint)'), lessThan(source.indexOf('await downloadMarketplacePromoPortrait(Uri.parse(signed))')));
    expect(source, contains('driver_promo_download.downloadPromoPng'));
    expect(source, contains('auth.currentUser?.id == _actor'));
    expect(source, isNot(contains('claim_referral_code')));
    expect(source, isNot(contains('Si no estoy disponible')));
    expect(source, isNot(contains('Toda una flota a tu disposición')));
    expect(source, contains('Solicita mi servicio desde este enlace:'));
    expect(source, contains("_promoText(canvas, 'Solicita mi'"));
    expect(source, contains("_promoText(canvas, 'servicio'"));
    expect(source, contains('rootBundle.load(artwork)'));
    expect(source, contains('final vehicleSweep = ui.Path()'));
    expect(source, contains('final pin = ui.Path()'));
    expect(source, contains('final arrow = ui.Path()'));
    expect(source, contains("'Conductor de la Agencia TukTuk'"));
    expect(source, contains("'Agencia TukTuk'"));
    expect(source, isNot(contains("_promoText(canvas, 'MI TUKTUK'")));
    expect(source, contains('identity.primaryColorHex'));
    expect(source, contains('identity.secondaryColorHex'));
  });
}
