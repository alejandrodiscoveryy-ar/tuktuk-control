import 'dart:typed_data';

import 'package:image/image.dart' as image;

/// Renders a web icon from a master PNG without changing the source image.
///
/// Only fully transparent rows and columns around the artwork are removed.
/// The cropped artwork is then scaled proportionally and centered on a
/// transparent square canvas.
Uint8List renderTransparentWebIcon(
  image.Image master, {
  required int size,
  required double contentScale,
}) {
  if (size <= 0) throw ArgumentError.value(size, 'size');
  if (contentScale <= 0 || contentScale > 1) {
    throw ArgumentError.value(contentScale, 'contentScale');
  }

  return _renderWebIcon(master, size: size, contentScale: contentScale);
}

/// Uses the transparent renderer geometry and then converts the artwork to a
/// white silhouette without changing any alpha value.
Uint8List renderMonochromeTransparentIcon(
  image.Image master, {
  required int size,
  required double contentScale,
}) {
  final rendered = image.decodePng(
    renderTransparentWebIcon(
      master,
      size: size,
      contentScale: contentScale,
    ),
  )!;
  for (final pixel in rendered) {
    if (pixel.a.toInt() == 0) continue;
    pixel.setRgba(255, 255, 255, pixel.a.toInt());
  }
  return Uint8List.fromList(image.encodePng(rendered, level: 9));
}

/// Renders a proportionally scaled icon on a fully opaque solid background.
Uint8List renderOpaqueWebIcon(
  image.Image master, {
  required int size,
  required double contentScale,
  required int backgroundRed,
  required int backgroundGreen,
  required int backgroundBlue,
}) {
  for (final channel in [backgroundRed, backgroundGreen, backgroundBlue]) {
    if (channel < 0 || channel > 255) {
      throw ArgumentError.value(channel, 'background channel');
    }
  }
  return _renderWebIcon(
    master,
    size: size,
    contentScale: contentScale,
    background: (backgroundRed, backgroundGreen, backgroundBlue),
  );
}

Uint8List _renderWebIcon(
  image.Image master, {
  required int size,
  required double contentScale,
  (int, int, int)? background,
}) {
  if (size <= 0) throw ArgumentError.value(size, 'size');
  if (contentScale <= 0 || contentScale > 1) {
    throw ArgumentError.value(contentScale, 'contentScale');
  }

  final bounds = visibleAlphaBounds(master);
  if (bounds == null) {
    throw const FormatException('El PNG maestro no contiene arte visible.');
  }

  final cropped = image.copyCrop(
    master,
    x: bounds.left,
    y: bounds.top,
    width: bounds.width,
    height: bounds.height,
  );
  final targetExtent = (size * contentScale).round().clamp(1, size);
  final scale = targetExtent /
      (cropped.width > cropped.height ? cropped.width : cropped.height);
  final targetWidth = (cropped.width * scale).round().clamp(1, size);
  final targetHeight = (cropped.height * scale).round().clamp(1, size);
  final resized = image.copyResize(
    cropped,
    width: targetWidth,
    height: targetHeight,
    interpolation: image.Interpolation.cubic,
  );
  final canvas = image.Image(width: size, height: size, numChannels: 4);
  if (background case (final red, final green, final blue)) {
    for (final pixel in canvas) {
      pixel.setRgba(red, green, blue, 255);
    }
  }
  image.compositeImage(
    canvas,
    resized,
    dstX: (size - targetWidth) ~/ 2,
    dstY: (size - targetHeight) ~/ 2,
  );
  return Uint8List.fromList(image.encodePng(canvas, level: 9));
}

AlphaBounds? visibleAlphaBounds(image.Image source) {
  var left = source.width;
  var top = source.height;
  var right = -1;
  var bottom = -1;

  for (final pixel in source) {
    if (pixel.a.toInt() == 0) continue;
    if (pixel.x < left) left = pixel.x;
    if (pixel.y < top) top = pixel.y;
    if (pixel.x > right) right = pixel.x;
    if (pixel.y > bottom) bottom = pixel.y;
  }
  if (right < left || bottom < top) return null;
  return AlphaBounds(left: left, top: top, right: right, bottom: bottom);
}

class AlphaBounds {
  const AlphaBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => right - left + 1;
  int get height => bottom - top + 1;
}
