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

  test('mantiene el arte maskable opaco dentro de la zona segura', () {
    final master = image.Image(width: 100, height: 100, numChannels: 4);
    for (var y = 10; y < 90; y++) {
      for (var x = 10; x < 90; x++) {
        master.setPixelRgba(x, y, 255, 255, 255, 255);
      }
    }

    final rendered = image.decodePng(
      renderOpaqueWebIcon(
        master,
        size: 192,
        contentScale: .72,
        backgroundRed: 11,
        backgroundGreen: 15,
        backgroundBlue: 20,
      ),
    )!;
    final bounds = _nonBackgroundBounds(rendered, (11, 15, 20))!;

    expect(bounds.width / rendered.width, lessThanOrEqualTo(.73));
    expect(bounds.height / rendered.height, lessThanOrEqualTo(.73));
    expect(rendered.every((pixel) => pixel.a.toInt() == 255), isTrue);
    expect(rendered.getPixel(0, 0).r.toInt(), 11);
    expect(rendered.getPixel(0, 0).g.toInt(), 15);
    expect(rendered.getPixel(0, 0).b.toInt(), 20);
  });

  test('rechaza un maestro totalmente transparente', () {
    final master = image.Image(width: 16, height: 16, numChannels: 4);

    expect(
      () => renderTransparentWebIcon(master, size: 32, contentScale: .92),
      throwsFormatException,
    );
  });

  test('fallback adaptive recorta padding y ocupa 264 px sin deformar', () {
    final master = _adaptiveMasterWithTransparentPadding();
    final original = image.encodePng(master);

    final foreground = image.decodePng(
      renderTransparentWebIcon(
        master,
        size: 432,
        contentScale: 66 / 108,
      ),
    )!;
    final monochrome = image.decodePng(
      renderMonochromeTransparentIcon(
        master,
        size: 432,
        contentScale: 66 / 108,
      ),
    )!;
    final foregroundBounds = visibleAlphaBounds(foreground)!;
    final monochromeBounds = visibleAlphaBounds(monochrome)!;

    expect(foregroundBounds.width, 264);
    expect(foregroundBounds.height, 179);
    expect(
      foregroundBounds.width / foregroundBounds.height,
      closeTo(624 / 424, .01),
    );
    expect(
      (foregroundBounds.left - (432 - foregroundBounds.right - 1)).abs(),
      lessThanOrEqualTo(1),
    );
    expect(
      (foregroundBounds.top - (432 - foregroundBounds.bottom - 1)).abs(),
      lessThanOrEqualTo(1),
    );
    expect(monochromeBounds.width, foregroundBounds.width);
    expect(monochromeBounds.height, foregroundBounds.height);
    expect(image.encodePng(master), original);

    var hasSemitransparentEdge = false;
    var alphaMismatchCount = 0;
    var nonWhiteVisibleCount = 0;
    for (final pixel in foreground) {
      final alpha = pixel.a.toInt();
      if (alpha > 0 && alpha < 255) hasSemitransparentEdge = true;
      final monochromePixel = monochrome.getPixel(pixel.x, pixel.y);
      if (monochromePixel.a.toInt() != alpha) alphaMismatchCount++;
      if (alpha > 0) {
        if (monochromePixel.r.toInt() != 255 ||
            monochromePixel.g.toInt() != 255 ||
            monochromePixel.b.toInt() != 255) {
          nonWhiteVisibleCount++;
        }
      }
    }
    expect(hasSemitransparentEdge, isTrue);
    expect(alphaMismatchCount, 0);
    expect(nonWhiteVisibleCount, 0);
  });

  test('los recursos Web/PWA generados cumplen dimensiones y ocupación', () {
    final background = _hexRgb(_readManifest()['background_color'] as String);
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
      final maskable = entry.key.contains('maskable');
      final bounds = maskable
          ? _nonBackgroundBounds(icon, background)!
          : visibleAlphaBounds(icon)!;
      final occupiedExtent =
          (bounds.width > bounds.height ? bounds.width : bounds.height) /
              entry.value.size;

      expect(icon.width, entry.value.size, reason: entry.key);
      expect(icon.height, entry.value.size, reason: entry.key);
      expect(occupiedExtent, closeTo(entry.value.scale, .015),
          reason: entry.key);
      if (maskable) {
        expect(icon.every((pixel) => pixel.a.toInt() == 255), isTrue,
            reason: entry.key);
        final corner = icon.getPixel(0, 0);
        expect(
          (corner.r.toInt(), corner.g.toInt(), corner.b.toInt()),
          background,
          reason: entry.key,
        );
      } else {
        expect(icon.getPixel(0, 0).a, 0, reason: entry.key);
      }
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

AlphaBounds? _nonBackgroundBounds(
  image.Image source,
  (int, int, int) background,
) {
  var left = source.width;
  var top = source.height;
  var right = -1;
  var bottom = -1;
  for (final pixel in source) {
    if (pixel.r.toInt() == background.$1 &&
        pixel.g.toInt() == background.$2 &&
        pixel.b.toInt() == background.$3) {
      continue;
    }
    if (pixel.x < left) left = pixel.x;
    if (pixel.y < top) top = pixel.y;
    if (pixel.x > right) right = pixel.x;
    if (pixel.y > bottom) bottom = pixel.y;
  }
  if (right < left || bottom < top) return null;
  return AlphaBounds(left: left, top: top, right: right, bottom: bottom);
}

Map<String, dynamic> _readManifest() =>
    jsonDecode(File('web/manifest.json').readAsStringSync())
        as Map<String, dynamic>;

(int, int, int) _hexRgb(String value) {
  final rgb = int.parse(value.substring(1), radix: 16);
  return ((rgb >> 16) & 0xff, (rgb >> 8) & 0xff, rgb & 0xff);
}

image.Image _adaptiveMasterWithTransparentPadding() {
  final master = image.Image(width: 1024, height: 1024, numChannels: 4);
  for (var y = 300; y < 724; y++) {
    for (var x = 200; x < 824; x++) {
      final edge = x == 200 || x == 823 || y == 300 || y == 723;
      master.setPixelRgba(x, y, 10, 20, 30, edge ? 96 : 255);
    }
  }
  return master;
}
