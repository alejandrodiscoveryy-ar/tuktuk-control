import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:control_tuk_tuk/services/marketplace_identity_geometry.dart';

void main() {
  test('marco de carné es horizontal, centrado y mantiene márgenes', () {
    for (final viewport in [const Size(360, 600), const Size(320, 430)]) {
      final frame = marketplaceIdentityFrame(viewport);
      expect(frame.width / frame.height, closeTo(1.59, 0.001));
      expect(frame.left, greaterThan(0));
      expect(frame.top, greaterThan(0));
      expect(frame.right, lessThan(viewport.width));
      expect(frame.bottom, lessThan(viewport.height));
    }
  });

  test('el recorte usa el marco, no la foto completa', () {
    final original = img.Image(width: 1080, height: 1920);
    const viewport = Size(360, 600);
    final cropped = cropMarketplaceIdentityToFrame(
      orientedPhoto: original,
      viewport: viewport,
      frame: marketplaceIdentityFrame(viewport),
    );
    expect(cropped.width, lessThan(original.width));
    expect(cropped.height, lessThan(original.height));
    expect(cropped.width / cropped.height, closeTo(1.59, 0.01));
  });

  test('Android usa guía exclusivamente para ambas caras del carné', () {
    final source =
        File('lib/presentation/marketplace_onboarding.dart').readAsStringSync();
    expect(source, contains('defaultTargetPlatform == TargetPlatform.android'));
    expect(source, contains("assetKind == 'identity_document'"));
    expect(source, contains('captureGuidedMarketplaceIdentityPhoto'));
    expect(source, contains("assetKind == 'vehicle_photo' ||"));
    final native = File('lib/services/marketplace_identity_capture_io.dart')
        .readAsStringSync();
    expect(native, contains('Usar esta foto'));
    expect(native, contains('Repetir foto'));
    expect(native, contains('File(photo.path).delete()'));
  });
}
