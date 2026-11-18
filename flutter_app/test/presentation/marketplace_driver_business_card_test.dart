import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:control_tuk_tuk/main.dart';

const code = '0123456789abcdef0123456789abcdef';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('approved premium card is horizontal, print sized and uses the real QR', (tester) async {
    final png = await tester.runAsync(() => renderMarketplaceDriverPrintCard(
      name: 'Conductor Ejemplo', code: code, alias: 'conductor-ejemplo',
      modality: 'Auto · Pasajeros', identityVerified: true));
    expect(png, isNotNull);
    final picture = img.decodePng(png!)!;
    expect(picture.width, 1004);
    expect(picture.height, 650);
    final footer = picture.getPixel(980, 600);
    expect(footer.r, lessThan(40)); // TukTuk charcoal footer.
    expect(footer.g, lessThan(50));
    expect(footer.b, lessThan(60));
    final header = picture.getPixel(600, 24);
    expect(header.r, lessThan(45)); // No blue header fill.
    expect(header.b, lessThan(55));
    final impulse = picture.getPixel(760, 117);
    expect(impulse.r, greaterThan(impulse.b)); // Warm orange mark.
    final qr = marketplaceDriverPromoQr(code, alias: 'conductor-ejemplo');
    const x = 727, y = 200, module = 5;
    final qrWidth = (qr.moduleCount + 8) * module;
    for (var z = 0; z < qrWidth; z += 3) {
      for (final pixel in [
        picture.getPixel(x + z, y + 1),
        picture.getPixel(x + z, y + qrWidth - 2),
        picture.getPixel(x + 1, y + z),
        picture.getPixel(x + qrWidth - 2, y + z),
      ]) {
        expect([pixel.r, pixel.g, pixel.b], [255, 255, 255]);
      }
    }
    for (var row = 0; row < qr.moduleCount; row++) {
      for (var col = 0; col < qr.moduleCount; col++) {
        final pixel = picture.getPixel(x + (col + 4) * module + 2,
          y + (row + 4) * module + 2);
        final expected = qr.isDark(row, col) ? 0 : 255;
        expect([pixel.r, pixel.g, pixel.b], [expected, expected, expected]);
      }
    }
  });

  testWidgets('same personal link, no photo or vehicle required', (tester) async {
    final one = await tester.runAsync(() => renderMarketplaceDriverPrintCard(
      name: 'Conductor Ejemplo', code: code, modality: 'Moto · Mensajería'));
    final two = await tester.runAsync(() => renderMarketplaceDriverPrintCard(
      name: 'Conductor Ejemplo', code: code, alias: 'abc-moto',
      modality: 'Moto · Mensajería'));
    expect(one, isNotNull);
    expect(two, isNotNull);
    expect(one, isNot(orderedEquals(two!)));
    expect(marketplaceDriverPromoDisplayLink(code, alias: 'abc-moto'),
      'vrixora.com/tuk/abc-moto');
    expect(marketplaceDriverPromoUri(code, alias: 'abc-moto').toString(),
      'https://www.vrixora.com/tuk/abc-moto');
  });

  testWidgets('lossless one-page PDF is exactly 85 by 55 millimeters', (tester) async {
    final png = await tester.runAsync(() => renderMarketplaceDriverPrintCard(
      name: 'Ana Pérez', code: code, modality: 'Triciclo · Pasajeros'));
    final pdf = marketplaceDriverPrintPdf(png!);
    expect(ascii.decode(pdf.sublist(0, 8)), '%PDF-1.4');
    final first = latin1.decode(pdf.sublist(0, 1100));
    expect(first, contains('/MediaBox [0 0 240.94488 155.90551]'));
    expect(first, contains('/BitsPerComponent 8'));
    expect(first, contains('/Width 1004 /Height 650'));
    expect(first, contains('/ColorSpace /DeviceRGB'));
    expect(latin1.decode(pdf.sublist(pdf.length - 120)), contains('%%EOF'));
    expect(pdf.length, greaterThan(1004 * 650 * 3));
    expect(() => marketplaceDriverPrintPdf(Uint8List.fromList([0, 1])),
      throwsArgumentError);
  });

  testWidgets('authorized portrait is embedded and never replaced with a sample face', (tester) async {
    final photo = img.Image(width: 16, height: 16);
    img.fill(photo, color: img.ColorRgb8(242, 27, 76));
    Future<img.Image> card(Uint8List? bytes) async {
      final output = await tester.runAsync(() => renderMarketplaceDriverPrintCard(
        name: 'Ana Pérez', code: code, modality: 'Triciclo · Pasajeros',
        identityVerified: true, photoBytes: bytes));
      return img.decodePng(output!)!;
    }
    final placeholder = await card(null);
    final portrait = await card(Uint8List.fromList(img.encodePng(photo)));
    final before = placeholder.getPixel(160, 330);
    final after = portrait.getPixel(160, 330);
    expect([after.r, after.g, after.b], isNot([before.r, before.g, before.b]));
    expect(after.r, greaterThan(200));
    expect(after.g, lessThan(100));
  });

  testWidgets('long public names fit completely without ellipsis in print and PDF', (tester) async {
    const names = [
      'Pedro Alejandro Cruz',
      'María de los Ángeles Fernández Rodríguez',
      'María de los Ángeles Fernández Rodríguez de la Cruz y Martínez',
    ];
    for (final name in names) {
      final layout = marketplaceDriverPrintNameLayout(name);
      expect(layout.text!.toPlainText(), name);
      expect(layout.didExceedMaxLines, isFalse);
      expect(layout.computeLineMetrics().length, lessThanOrEqualTo(3));
      expect(layout.height, lessThanOrEqualTo(124));
      expect((layout.text! as TextSpan).style!.fontSize!, lessThanOrEqualTo(46));
      layout.dispose();

      final png = await tester.runAsync(() => renderMarketplaceDriverPrintCard(
        name: name, code: code, modality: 'Triciclo · Pasajeros',
        identityVerified: true));
      final picture = img.decodePng(png!)!;
      expect(picture.width, 1004);
      expect(picture.height, 650);
      expect(marketplaceDriverPrintPdf(png), isNotEmpty);
    }
  });

  test('premium template contains no fabricated driver statistics or vehicle artwork', () {
    final source = File('lib/presentation/marketplace_driver_business_card.dart').readAsStringSync();
    expect(source, isNot(contains('4.9')));
    expect(source, isNot(contains('328 viajes')));
    expect(source, isNot(contains('1,200')));
    expect(source, isNot(contains('assets/branding/impulsa/light_car.webp')));
    expect(source, contains('photoBytes'));
    expect(source, contains('marketplaceDriverPromoQr(code, alias: alias)'));
    expect(source, contains('Solicita mi servicio'));
  });

  test('Impulsa alone occupies the top-right, verification is by the name', () {
    final source = File('lib/presentation/marketplace_driver_business_card.dart').readAsStringSync();
    expect(source, isNot(contains("'Verificado', 841")));
    expect(source, contains("'Impulsa', 754, 71"));
    expect(source, contains("'Agencia', brandLeft + 2, 23"));
    expect(source, contains("TextSpan(text: 'TUK', style: TextStyle(color: Colors.white))"));
    expect(source, contains("TextSpan(text: 'TUK', style: TextStyle(color: gold))"));
    expect(source, contains('brandPainter.paint(canvas, Offset(brandLeft, 55))'));
    expect(source, isNot(contains("'Agencia TukTuk', icon == null ? 55 : 149")));
    expect(source, isNot(contains("'TUK', brandLeft")));
    expect(source, isNot(contains("'Agencia TukTuk', 55, 581")));
    expect(source, contains("'Tu conductor de confianza, a un toque.'"));
    expect(source, contains('const gold = Color(0xFFE5A84E)'));
    expect(source, contains('const mint = Color(0xFF35D6A2)'));
    expect(source, contains('if (identityVerified) {'));
    expect(source, contains('_promoVerifiedSeal(canvas, Offset(310, verificationTop + 1), 24)'));
    expect(source, isNot(contains('0xFF0564DC')));
    expect(source, isNot(contains('0xFF0864D1')));
  });

}
