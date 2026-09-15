import 'dart:typed_data';

import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _jpeg(int width, int height) {
  final image = img.Image(width: width, height: height);
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

void main() {
  group('Marketplace image normalization', () {
    test('driver photo is always normalized to 720 x 720 JPEG', () {
      final result = normalizeMarketplaceImage(
        sourceBytes: _jpeg(3000, 2000),
        assetKind: 'driver_photo',
      );

      expect(result.width, 720);
      expect(result.height, 720);
      expect(result.mimeType, 'image/jpeg');
      expect(result.extension, 'jpg');
      expect(result.bytes.length, lessThan(5000000));
    });

    test('large landscape vehicle preserves proportion within 1280 x 960', () {
      final result = normalizeMarketplaceImage(
        sourceBytes: _jpeg(3000, 2000),
        assetKind: 'vehicle_photo',
      );

      expect(result.width, 1280);
      expect(result.height, 853);
      expect(result.bytes.length, lessThan(5000000));
    });

    test('portrait vehicle preserves proportion within 1280 x 960', () {
      final result = normalizeMarketplaceImage(
        sourceBytes: _jpeg(1200, 2000),
        assetKind: 'vehicle_photo',
      );

      expect(result.width, 576);
      expect(result.height, 960);
      expect(result.bytes.length, lessThan(5000000));
    });

    test('small vehicle image is not enlarged', () {
      final result = normalizeMarketplaceImage(
        sourceBytes: _jpeg(800, 600),
        assetKind: 'vehicle_photo',
      );

      expect(result.width, 800);
      expect(result.height, 600);
    });

    test('invalid image is rejected', () {
      expect(
        () => normalizeMarketplaceImage(
          sourceBytes: Uint8List.fromList([1, 2, 3, 4]),
          assetKind: 'driver_photo',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('unsupported marketplace image kind is rejected', () {
      expect(
        () => normalizeMarketplaceImage(
          sourceBytes: _jpeg(800, 600),
          assetKind: 'unknown',
        ),
        throwsArgumentError,
      );
    });
  });
}
