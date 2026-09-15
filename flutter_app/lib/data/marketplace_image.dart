part of '../main.dart';

const _marketplaceDriverPhotoSize = 720;
const _marketplaceVehiclePhotoMaxWidth = 1280;
const _marketplaceVehiclePhotoMaxHeight = 960;
const _marketplacePreferredPhotoBytes = 1500000;

String _marketplaceUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));

  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final hex =
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();

  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

class MarketplaceNormalizedImage {
  const MarketplaceNormalizedImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;

  String get mimeType => 'image/jpeg';
  String get extension => 'jpg';
}

MarketplaceNormalizedImage normalizeMarketplaceImage({
  required Uint8List sourceBytes,
  required String assetKind,
}) {
  img.Image? decoded;

  try {
    decoded = img.decodeImage(sourceBytes);
  } catch (_) {
    throw const FormatException('La imagen seleccionada no es válida.');
  }

  if (decoded == null) {
    throw const FormatException('La imagen seleccionada no es válida.');
  }

  final oriented = img.bakeOrientation(decoded);

  late final img.Image normalized;

  switch (assetKind) {
    case 'driver_photo':
      normalized = img.copyResizeCropSquare(
        oriented,
        size: _marketplaceDriverPhotoSize,
        interpolation: img.Interpolation.cubic,
      );

    case 'vehicle_photo':
      final widthScale = _marketplaceVehiclePhotoMaxWidth / oriented.width;
      final heightScale = _marketplaceVehiclePhotoMaxHeight / oriented.height;

      final scale = min(
        1.0,
        min(widthScale, heightScale),
      );

      if (scale < 1.0) {
        normalized = img.copyResize(
          oriented,
          width: max(1, (oriented.width * scale).round()),
          height: max(1, (oriented.height * scale).round()),
          interpolation: img.Interpolation.cubic,
        );
      } else {
        normalized = oriented;
      }

    default:
      throw ArgumentError.value(
        assetKind,
        'assetKind',
        'Tipo de imagen Marketplace no soportado.',
      );
  }

  var encoded = img.encodeJpg(
    normalized,
    quality: 82,
  );

  for (final quality in const [76, 70, 64, 58]) {
    if (encoded.length <= _marketplacePreferredPhotoBytes) break;

    encoded = img.encodeJpg(
      normalized,
      quality: quality,
    );
  }

  if (encoded.length > 5000000) {
    throw const FormatException(
      'La imagen optimizada todavía supera el límite permitido.',
    );
  }

  return MarketplaceNormalizedImage(
    bytes: encoded,
    width: normalized.width,
    height: normalized.height,
  );
}
