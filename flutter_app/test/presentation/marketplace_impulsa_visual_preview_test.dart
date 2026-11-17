import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:control_tuk_tuk/main.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Export Impulsa review PNGs and physical horizontal cards', (tester) async {
    final path = Platform.environment['IMPULSA_PREVIEW_DIR'];
    if (path == null) return;
    final directory = Directory(path)..createSync(recursive: true);
    await tester.runAsync(() async {
      final campaign = FontLoader('ImpulsaMontserrat');
      for (final filename in ['Montserrat-Bold.ttf', 'Montserrat-ExtraBold.ttf']) {
        campaign.addFont(rootBundle.load('assets/branding/impulsa/$filename'));
      }
      await campaign.load();
    });
    final fonts = Platform.environment['IMPULSA_FONT_DIR'];
    if (fonts != null) {
      await tester.runAsync(() async {
        final loader = FontLoader('Roboto');
        for (final filename in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf', 'Roboto-Medium.ttf']) {
          final file = File('$fonts/$filename');
          if (file.existsSync()) {
            loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
          }
        }
        await loader.load();
        final icons = File('$fonts/MaterialIcons-Regular.otf');
        if (icons.existsSync()) {
          final iconLoader = FontLoader('MaterialIcons');
          iconLoader.addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
          await iconLoader.load();
        }
      });
    }
    // Never use the legacy Control asset for campaign visual review.
    // The CI supplies the current official master icon from project branding.
    final logoPath = Platform.environment['IMPULSA_OFFICIAL_ICON'];
    expect(logoPath, isNotNull, reason: 'Official TukTuk master icon is required');
    final logo = File(logoPath!).readAsBytesSync();
    expect(img.decodeImage(logo), isNotNull);
    const identity = ProjectIdentity(
      projectId: 'impulsa-review', name: 'Agencia TukTuk',
      primaryColorHex: '#06B6D4', secondaryColorHex: '#0F172A',
    );
    const profiles = {
      'tricycle': 'Triciclo · Carga · Mensajería · Pasajeros',
      'light_car': 'Auto · Pasajeros',
      'motorcycle': 'Moto · Pasajeros · Mensajería',
      'comfort': 'Confort · Pasajeros',
      'bicitaxi': 'Bicitaxi · Pasajeros',
    };
    for (final entry in profiles.entries) {
      for (final story in [false, true]) {
        final bytes = await tester.runAsync(() => renderMarketplaceDriverPromoCard(
          name: entry.key == 'tricycle' ? 'Frank Camilo Núñez Nieves' : 'Conductor Demo', code: '0123456789abcdef0123456789abcdef',
          alias: entry.key == 'tricycle' ? 'frank' : 'conductor-demo', modality: entry.value, story: story, logoBytes: logo,
          identity: identity, identityVerified: true, vehicleCategory: entry.key));
        expect(bytes, isNotNull);
        final png = img.decodePng(bytes!)!;
        expect(png.width, 1080);
        expect(png.height, story ? 1920 : 1080);
        File('${directory.path}/${entry.key}-${story ? "historia" : "cuadrada"}.png').writeAsBytesSync(bytes);
        if (!story) {
          final print = await tester.runAsync(() => renderMarketplaceDriverPrintCard(
            name: entry.key == 'tricycle' ? 'Frank Camilo Núñez Nieves'
              : 'Conductor Demo',
            code: '0123456789abcdef0123456789abcdef',
            alias: entry.key == 'tricycle' ? 'frank' : 'conductor-demo',
            modality: entry.value, logoBytes: logo, identityVerified: true));
          expect(print, isNotNull);
          final horizontal = img.decodePng(print!)!;
          expect(horizontal.width, 1004);
          expect(horizontal.height, 650);
          File('${directory.path}/${entry.key}-presentacion.png').writeAsBytesSync(print);
          File('${directory.path}/${entry.key}-presentacion.pdf')
            .writeAsBytesSync(marketplaceDriverPrintPdf(print));
        }
      }
    }
    final printable = await tester.runAsync(() => renderMarketplaceDriverPrintCard(
      name: 'Conductor Ejemplo Apellido Largo',
      code: '0123456789abcdef0123456789abcdef',
      alias: 'conductor-ejemplo', modality: 'Triciclo · Pasajeros',
      identityVerified: true, logoBytes: logo));
    expect(printable, isNotNull);
    File('${directory.path}/presentacion-85x55.png').writeAsBytesSync(printable!);
    final printPdf = marketplaceDriverPrintPdf(printable);
    expect(printPdf.length, greaterThan(1000));
    File('${directory.path}/presentacion-85x55.pdf').writeAsBytesSync(printPdf);
  });
}
