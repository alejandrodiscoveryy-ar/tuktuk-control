import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:control_tuk_tuk/main.dart';

const code = '0123456789abcdef0123456789abcdef';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('business card is white, standard print size and uses the real QR', (tester) async {
    final png = await tester.runAsync(() => renderMarketplaceDriverPrintCard(
      name: 'Conductor Ejemplo', code: code, alias: 'conductor-ejemplo',
      modality: 'Auto · Pasajeros', identityVerified: true));
    expect(png, isNotNull);
    final picture = img.decodePng(png!)!;
    expect(picture.width, 1004);
    expect(picture.height, 650);
    final paper = picture.getPixel(980, 600);
    expect([paper.r, paper.g, paper.b], [255, 255, 255]);
    final qr = marketplaceDriverPromoQr(code, alias: 'conductor-ejemplo');
    const x = 674, y = 217, module = 6;
    final qrWidth = (qr.moduleCount + 8) * module;
    for (var z = 0; z < qrWidth; z += 3) {
      final quietTop = picture.getPixel(x + z, y + 1);
      expect([quietTop.r, quietTop.g, quietTop.b], [255, 255, 255]);
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

}
