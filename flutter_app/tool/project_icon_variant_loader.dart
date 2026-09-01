import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as image;

const maximumProjectIconDownloadBytes = 16 * 1024 * 1024;

enum ProjectIconAlpha { transparent, opaque, monochrome }

typedef ProjectIconBytesFetcher = Future<Uint8List> Function(Uri uri);

Uri resolveProjectIconVariantUri(String iconUrl, String variantName) {
  final master = Uri.tryParse(iconUrl);
  if (master == null ||
      master.scheme != 'https' ||
      master.host.isEmpty ||
      !master.path.toLowerCase().endsWith('.png')) {
    throw const FormatException('icon_url debe ser una URL PNG HTTPS válida.');
  }
  if (!RegExp(r'^[a-z0-9-]+\.png$').hasMatch(variantName)) {
    throw FormatException('Nombre de variante no válido: $variantName.');
  }
  final cleanMaster = Uri.parse(
    '${master.scheme}://${master.authority}${master.path}',
  );
  return cleanMaster.replace(
    path:
        '${cleanMaster.path.substring(0, cleanMaster.path.length - 4)}/$variantName',
  );
}

Future<Uint8List> loadProjectIconVariant({
  required String iconUrl,
  required String variantName,
  required int size,
  required ProjectIconAlpha alpha,
  required Future<Uint8List> Function() fallback,
  HttpClient? client,
  ProjectIconBytesFetcher? fetch,
}) async {
  final ownedClient = client == null;
  final httpClient =
      client ?? (HttpClient()..connectionTimeout = const Duration(seconds: 15));
  try {
    try {
      final uri = resolveProjectIconVariantUri(iconUrl, variantName);
      final bytes = fetch == null
          ? await _downloadVariant(httpClient, uri, variantName)
          : await fetch(uri);
      validateProjectIconVariant(
        bytes,
        label: variantName,
        size: size,
        alpha: alpha,
      );
      return bytes;
    } catch (_) {
      final bytes = await fallback();
      validateProjectIconVariant(
        bytes,
        label: 'fallback de $variantName',
        size: size,
        alpha: alpha,
      );
      return bytes;
    }
  } finally {
    if (ownedClient) httpClient.close(force: true);
  }
}

Future<Uint8List> _downloadVariant(
  HttpClient client,
  Uri uri,
  String variantName,
) async {
  final request = await client.getUrl(uri).timeout(const Duration(seconds: 20));
  final response = await request.close().timeout(const Duration(seconds: 20));
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException(
      'La variante $variantName respondió HTTP ${response.statusCode}.',
      uri: uri,
    );
  }
  final builder = BytesBuilder(copy: false);
  var total = 0;
  await for (final chunk in response.timeout(const Duration(seconds: 30))) {
    total += chunk.length;
    if (total > maximumProjectIconDownloadBytes) {
      throw FormatException('La variante $variantName supera 16 MiB.');
    }
    builder.add(chunk);
  }
  return builder.takeBytes();
}

void validateProjectIconVariant(
  Uint8List bytes, {
  required String label,
  required int size,
  required ProjectIconAlpha alpha,
}) {
  final decoded = image.decodePng(bytes);
  if (decoded == null || decoded.width != size || decoded.height != size) {
    throw FormatException('$label debe ser un PNG ${size}x$size válido.');
  }
  var visible = 0;
  var transparent = 0;
  var nonWhiteVisible = 0;
  for (final pixel in decoded) {
    if (pixel.a.toInt() > 16) {
      visible++;
      if (pixel.r.toInt() != 255 ||
          pixel.g.toInt() != 255 ||
          pixel.b.toInt() != 255) {
        nonWhiteVisible++;
      }
    }
    if (pixel.a.toInt() < 255) transparent++;
  }
  if (visible < (size * size * .003).ceil()) {
    throw FormatException('$label no contiene arte visible suficiente.');
  }
  if (alpha == ProjectIconAlpha.opaque && transparent != 0) {
    throw FormatException('$label debe ser completamente opaco.');
  }
  if (alpha != ProjectIconAlpha.opaque && transparent == 0) {
    throw FormatException('$label debe conservar transparencia.');
  }
  if (alpha == ProjectIconAlpha.monochrome && nonWhiteVisible != 0) {
    throw FormatException('$label debe contener una silueta blanca.');
  }
}
