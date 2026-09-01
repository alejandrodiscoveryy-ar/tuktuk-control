import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import '../../tool/project_icon_renderer.dart';

void main() {
  test('recorta sólo transparencia exterior y ocupa 92% sin deformar', () {
    final master = image.Image(width: 100, height: 100, numChannels: 4);
    for (var y = 30; y < 70; y++) {
      for (var x = 20; x < 80; x++) {
        master.setPixelRgba(x, y, 10, 20, 30, 255);
      }
    }
    final original = image.encodePng(master);

    final rendered = image.decodePng(
      renderTransparentWebIcon(master, size: 100, contentScale: .92),
    )!;
    final bounds = visibleAlphaBounds(rendered)!;

    expect(bounds.width, 92);
    expect(bounds.height, 61);
    expect(bounds.width / bounds.height, closeTo(1.5, .02));
    expect(bounds.left, 4);
    expect(image.encodePng(master), original);
    expect(rendered.getPixel(0, 0).a, 0);
  });

  test('mantiene el arte maskable dentro de la zona segura', () {
    final master = image.Image(width: 100, height: 100, numChannels: 4);
    for (var y = 10; y < 90; y++) {
      for (var x = 10; x < 90; x++) {
        master.setPixelRgba(x, y, 255, 255, 255, 255);
      }
    }

    final rendered = image.decodePng(
      renderTransparentWebIcon(master, size: 192, contentScale: .72),
    )!;
    final bounds = visibleAlphaBounds(rendered)!;

    expect(bounds.width / rendered.width, lessThanOrEqualTo(.73));
    expect(bounds.height / rendered.height, lessThanOrEqualTo(.73));
  });

  test('rechaza un maestro totalmente transparente', () {
    final master = image.Image(width: 16, height: 16, numChannels: 4);

    expect(
      () => renderTransparentWebIcon(master, size: 32, contentScale: .92),
      throwsFormatException,
    );
  });

  test('los recursos Web/PWA generados cumplen dimensiones y ocupación', () {
    final expectations = <String, ({int size, double scale})>{
      'web/favicon.png': (size: 32, scale: .92),
      'web/icons/Icon-192.png': (size: 192, scale: .92),
      'web/icons/Icon-512.png': (size: 512, scale: .92),
      'web/icons/Icon-shortcut-192.png': (size: 192, scale: .70),
      'web/icons/Icon-maskable-192.png': (size: 192, scale: .72),
      'web/icons/Icon-maskable-512.png': (size: 512, scale: .72),
    };

    for (final entry in expectations.entries) {
      final icon = image.decodePng(File(entry.key).readAsBytesSync())!;
      final bounds = visibleAlphaBounds(icon)!;
      final occupiedExtent =
          (bounds.width > bounds.height ? bounds.width : bounds.height) /
              entry.value.size;

      expect(icon.width, entry.value.size, reason: entry.key);
      expect(icon.height, entry.value.size, reason: entry.key);
      expect(occupiedExtent, closeTo(entry.value.scale, .015),
          reason: entry.key);
      expect(icon.getPixel(0, 0).a, 0, reason: entry.key);
    }
  });

  test('manifest referencia variantes any y maskable correctas', () {
    final manifest = _readManifest();
    final icons = <String, Map<String, dynamic>>{
      for (final value in (manifest['icons'] as List<dynamic>))
        if (value is Map<String, dynamic>) value['src'] as String: value,
    };

    expect(icons['icons/Icon-192.png']?['sizes'], '192x192');
    expect(icons['icons/Icon-192.png']?['purpose'], 'any');
    expect(icons['icons/Icon-512.png']?['sizes'], '512x512');
    expect(icons['icons/Icon-512.png']?['purpose'], 'any');
    expect(icons['icons/Icon-maskable-192.png']?['purpose'], 'maskable');
    expect(icons['icons/Icon-maskable-512.png']?['purpose'], 'maskable');
    expect(icons, isNot(contains('icons/Icon-shortcut-192.png')));
  });

  test('manifest cumple campos de instalación Chromium', () {
    final manifest = _readManifest();

    expect(manifest['name'], 'TukTuk Control');
    expect(manifest['short_name'], 'TukTuk Control');
    expect(manifest['start_url'], './');
    expect(manifest['scope'], './');
    expect(manifest['display'], 'standalone');
    expect(manifest['background_color'], '#0B0F14');
    expect(manifest['theme_color'], '#06B6D4');
    expect(manifest['prefer_related_applications'], isFalse);
  });

  test('rutas del manifest se resuelven dentro de /tuktuk/app/', () {
    final manifest = _readManifest();
    final manifestUrl =
        Uri.parse('https://www.vrixora.com/tuktuk/app/manifest.json');

    expect(
      manifestUrl.resolve(manifest['start_url'] as String).path,
      '/tuktuk/app/',
    );
    expect(
      manifestUrl.resolve(manifest['scope'] as String).path,
      '/tuktuk/app/',
    );
    for (final icon in (manifest['icons'] as List<dynamic>)) {
      expect(
        manifestUrl
            .resolve((icon as Map<String, dynamic>)['src'] as String)
            .path,
        startsWith('/tuktuk/app/icons/'),
      );
    }
  });

  test('index expone un manifiesto estático y un fallback shortcut externo',
      () {
    final index = File('web/index.html').readAsStringSync();

    expect(index, contains('<link rel="manifest" href="manifest.json">'));
    expect(index, isNot(contains('manifest-mobile.json')));
    expect(index, isNot(contains('userAgent')));
    expect(
        index, contains('sizes="192x192" href="icons/Icon-shortcut-192.png"'));
  });
}

Map<String, dynamic> _readManifest() =>
    jsonDecode(File('web/manifest.json').readAsStringSync())
        as Map<String, dynamic>;
