import 'dart:math' as math;
import 'dart:ui';

import 'package:image/image.dart' as img;

/// Rectángulo que ve el conductor en el visor. El margen mantiene visibles
/// las cuatro esquinas del carné, incluso en pantallas estrechas.
const double marketplaceIdentityAspectRatio = 1.59;

Rect marketplaceIdentityFrame(Size viewport) {
  if (viewport.width <= 0 || viewport.height <= 0) {
    throw ArgumentError.value(viewport, 'viewport', 'Visor no válido');
  }
  final width = math.min(
    viewport.width * 0.86,
    viewport.height * 0.72 * marketplaceIdentityAspectRatio,
  );
  final height = width / marketplaceIdentityAspectRatio;
  return Rect.fromLTWH(
    (viewport.width - width) / 2,
    (viewport.height - height) / 2,
    width,
    height,
  );
}

/// Proyecta el marco de la previsualización `BoxFit.cover` a los píxeles del
/// JPEG ya orientado. Nunca sale de los límites de la imagen.
img.Image cropMarketplaceIdentityToFrame({
  required img.Image orientedPhoto,
  required Size viewport,
  required Rect frame,
}) {
  if (viewport.width <= 0 || viewport.height <= 0 || frame.isEmpty) {
    throw ArgumentError('Geometría de recorte inválida');
  }
  final scale = math.max(
    viewport.width / orientedPhoto.width,
    viewport.height / orientedPhoto.height,
  );
  final left = (viewport.width - orientedPhoto.width * scale) / 2;
  final top = (viewport.height - orientedPhoto.height * scale) / 2;
  final x1 = ((frame.left - left) / scale)
      .round()
      .clamp(0, orientedPhoto.width - 1)
      .toInt();
  final y1 = ((frame.top - top) / scale)
      .round()
      .clamp(0, orientedPhoto.height - 1)
      .toInt();
  final x2 = ((frame.right - left) / scale)
      .round()
      .clamp(x1 + 1, orientedPhoto.width)
      .toInt();
  final y2 = ((frame.bottom - top) / scale)
      .round()
      .clamp(y1 + 1, orientedPhoto.height)
      .toInt();
  return img.copyCrop(
    orientedPhoto,
    x: x1,
    y: y1,
    width: x2 - x1,
    height: y2 - y1,
  );
}
