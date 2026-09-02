import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import '../../tool/project_icon_variant_loader.dart';

void main() {
  const masterUrl =
      'https://example.supabase.co/storage/v1/object/public/project-branding/'
      'project/favicon-12345678-1234-1234-1234-123456789abc.png?token=old';

  test('resuelve cada variante junto al PNG maestro sin query', () {
    expect(
      resolveProjectIconVariantUri(masterUrl, 'android-launcher-192.png')
          .toString(),
      'https://example.supabase.co/storage/v1/object/public/project-branding/'
      'project/favicon-12345678-1234-1234-1234-123456789abc/'
      'android-launcher-192.png',
    );
    expect(
      () => resolveProjectIconVariantUri(masterUrl, '../icon.png'),
      throwsFormatException,
    );
  });

  test('prefiere una variante remota válida sin ejecutar el fallback',
      () async {
    var fallbackCalls = 0;
    Uri? requested;
    final remote = _png(size: 192, opaque: true, red: 20);

    final result = await loadProjectIconVariant(
      iconUrl: masterUrl,
      variantName: 'android-launcher-192.png',
      size: 192,
      alpha: ProjectIconAlpha.opaque,
      fetch: (uri) async {
        requested = uri;
        return remote;
      },
      fallback: () async {
        fallbackCalls++;
        return _png(size: 192, opaque: true, red: 200);
      },
    );

    expect(requested?.path, endsWith('/android-launcher-192.png'));
    expect(result, remote);
    expect(fallbackCalls, 0);
  });

  test('una variante inválida activa únicamente su fallback individual',
      () async {
    var launcherFallbacks = 0;
    var roundFallbacks = 0;
    final validRound = _png(size: 192, opaque: true, red: 30);

    final launcher = await loadProjectIconVariant(
      iconUrl: masterUrl,
      variantName: 'android-launcher-192.png',
      size: 192,
      alpha: ProjectIconAlpha.opaque,
      fetch: (_) async => _png(size: 191, opaque: true, red: 10),
      fallback: () async {
        launcherFallbacks++;
        return _png(size: 192, opaque: true, red: 40);
      },
    );
    final round = await loadProjectIconVariant(
      iconUrl: masterUrl,
      variantName: 'round-192.png',
      size: 192,
      alpha: ProjectIconAlpha.opaque,
      fetch: (_) async => validRound,
      fallback: () async {
        roundFallbacks++;
        return _png(size: 192, opaque: true, red: 50);
      },
    );

    expect(image.decodePng(launcher)!.getPixel(0, 0).r.toInt(), 40);
    expect(round, validRound);
    expect(launcherFallbacks, 1);
    expect(roundFallbacks, 0);
  });

  test('adaptive con ocupación visible de 264 px conserva la variante remota',
      () async {
    for (final variant in [
      ('adaptive-foreground-432.png', ProjectIconAlpha.transparent),
      ('adaptive-monochrome-432.png', ProjectIconAlpha.monochrome),
    ]) {
      var fallbackCalls = 0;
      final remote = _adaptivePng(
        extent: 264,
        monochrome: variant.$2 == ProjectIconAlpha.monochrome,
      );

      final result = await loadProjectIconVariant(
        iconUrl: masterUrl,
        variantName: variant.$1,
        size: 432,
        alpha: variant.$2,
        maximumVisibleExtent: 264,
        visibleExtentTolerance: 2,
        fetch: (_) async => remote,
        fallback: () async {
          fallbackCalls++;
          return _adaptivePng(extent: 264, monochrome: true);
        },
      );

      expect(result, remote, reason: variant.$1);
      expect(fallbackCalls, 0, reason: variant.$1);
    }
  });

  test('adaptive antigua de 312 px es rechazada y usa el fallback de 264 px',
      () async {
    for (final variant in [
      ('adaptive-foreground-432.png', ProjectIconAlpha.transparent),
      ('adaptive-monochrome-432.png', ProjectIconAlpha.monochrome),
    ]) {
      var fallbackCalls = 0;
      final fallback = _adaptivePng(
        extent: 264,
        monochrome: variant.$2 == ProjectIconAlpha.monochrome,
      );

      final result = await loadProjectIconVariant(
        iconUrl: masterUrl,
        variantName: variant.$1,
        size: 432,
        alpha: variant.$2,
        maximumVisibleExtent: 264,
        visibleExtentTolerance: 2,
        fetch: (_) async => _adaptivePng(
          extent: 312,
          monochrome: variant.$2 == ProjectIconAlpha.monochrome,
        ),
        fallback: () async {
          fallbackCalls++;
          return fallback;
        },
      );

      expect(result, fallback, reason: variant.$1);
      expect(fallbackCalls, 1, reason: variant.$1);
    }
  });

  test('otras variantes no reciben un límite de ocupación', () async {
    var fallbackCalls = 0;
    final remote = _adaptivePng(
      size: 512,
      extent: 312,
      monochrome: false,
    );

    final result = await loadProjectIconVariant(
      iconUrl: masterUrl,
      variantName: 'pwa-512.png',
      size: 512,
      alpha: ProjectIconAlpha.transparent,
      fetch: (_) async => remote,
      fallback: () async {
        fallbackCalls++;
        return _adaptivePng(
          size: 512,
          extent: 264,
          monochrome: false,
        );
      },
    );

    expect(result, remote);
    expect(fallbackCalls, 0);
  });

  test('valida dimensiones, transparencia y opacidad', () {
    expect(
      () => validateProjectIconVariant(
        _png(size: 32, opaque: false, red: 10),
        label: 'favicon',
        size: 32,
        alpha: ProjectIconAlpha.transparent,
      ),
      returnsNormally,
    );
    expect(
      () => validateProjectIconVariant(
        _png(size: 32, opaque: false, red: 10),
        label: 'launcher',
        size: 32,
        alpha: ProjectIconAlpha.opaque,
      ),
      throwsFormatException,
    );
    expect(
      () => validateProjectIconVariant(
        _png(size: 32, opaque: false, red: 10),
        label: 'monochrome',
        size: 32,
        alpha: ProjectIconAlpha.monochrome,
      ),
      throwsFormatException,
    );
    expect(
      () => validateProjectIconVariant(
        _png(size: 32, opaque: false, red: 255, green: 255, blue: 255),
        label: 'monochrome',
        size: 32,
        alpha: ProjectIconAlpha.monochrome,
      ),
      returnsNormally,
    );
    expect(
      () => validateProjectIconVariant(
        _png(size: 32, opaque: true, red: 10),
        label: 'foreground',
        size: 32,
        alpha: ProjectIconAlpha.transparent,
      ),
      throwsFormatException,
    );
  });
}

Uint8List _png({
  required int size,
  required bool opaque,
  required int red,
  int green = 20,
  int blue = 30,
}) {
  final result = image.Image(width: size, height: size, numChannels: 4);
  for (final pixel in result) {
    final visible = opaque || (pixel.x > 1 && pixel.y > 1);
    pixel.setRgba(red, green, blue, visible ? 255 : 0);
  }
  return Uint8List.fromList(image.encodePng(result));
}

Uint8List _adaptivePng({
  int size = 432,
  required int extent,
  required bool monochrome,
}) {
  final result = image.Image(width: size, height: size, numChannels: 4);
  final offset = (size - extent) ~/ 2;
  for (var y = offset; y < offset + extent; y++) {
    for (var x = offset; x < offset + extent; x++) {
      result.setPixelRgba(
        x,
        y,
        monochrome ? 255 : 10,
        monochrome ? 255 : 20,
        monochrome ? 255 : 30,
        255,
      );
    }
  }
  return Uint8List.fromList(image.encodePng(result));
}
