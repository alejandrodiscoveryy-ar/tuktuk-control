import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:control_tuk_tuk/main.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Export ten synthetic Impulsa review PNGs', (tester) async {
    final path = Platform.environment['IMPULSA_PREVIEW_DIR'];
    if (path == null) return;
    final directory = Directory(path)..createSync(recursive: true);
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
    final logo = File('assets/branding/tuktuk_logo.png').readAsBytesSync();
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
          name: 'Conductor Demo', code: '0123456789abcdef0123456789abcdef',
          modality: entry.value, story: story, logoBytes: logo,
          identityVerified: true, vehicleCategory: entry.key));
        expect(bytes, isNotNull);
        final png = img.decodePng(bytes!)!;
        expect(png.width, 1080);
        expect(png.height, story ? 1920 : 1080);
        File('${directory.path}/${entry.key}-${story ? "historia" : "cuadrada"}.png').writeAsBytesSync(bytes);
      }
    }
  });
}
