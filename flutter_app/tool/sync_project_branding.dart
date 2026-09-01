import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as image;

import 'project_icon_renderer.dart';
import 'project_icon_variant_loader.dart';

const _projectId = 'dfb41cea-a812-46f2-b511-7a60bd3d78af';
const _defaultSupabaseUrl = 'https://vvxvnywzgtqhlaqpxyqh.supabase.co';
const _defaultPublishableKey = 'sb_publishable_MOmcX334dezcrlRAaQlvbg_Scd-RJTV';
const _maximumDownloadBytes = 16 * 1024 * 1024;

enum _BrandingTarget { web, webMaskable, android, all }

Future<void> main(List<String> arguments) async {
  final root = File.fromUri(Platform.script).parent.parent;
  late final _BrandingTarget target;
  try {
    target = _parseTarget(arguments);
  } catch (error) {
    stderr.writeln('$error\nUso: dart run tool/sync_project_branding.dart '
        '[--web|--web-maskable|--android|--all]');
    exitCode = 64;
    return;
  }

  try {
    final identity = await _loadIdentity();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    Future<image.Image>? masterDownload;
    Future<image.Image> master() =>
        masterDownload ??= _downloadMasterIcon(identity.iconUrl);
    final outputs = <File, Uint8List>{};
    try {
      if (target != _BrandingTarget.android) {
        if (target == _BrandingTarget.webMaskable) {
          await _addWebMaskableResources(
            root,
            identity,
            master,
            client,
            outputs,
          );
        } else {
          await _addWebResources(root, identity, master, client, outputs);
        }
      }
      if (target != _BrandingTarget.web &&
          target != _BrandingTarget.webMaskable) {
        await _addAndroidResources(root, identity, master, client, outputs);
      }
    } finally {
      client.close(force: true);
    }
    _validateGeneratedPngs(outputs);
    await _replaceAtomically(outputs);

    stdout.writeln(
      'Identidad ${_targetLabel(target)} sincronizada: ${identity.name} '
      '(actualizada ${identity.updatedAt ?? 'sin fecha'}).',
    );
    stdout.writeln(
      'Colores: primary=${identity.primaryColor}, '
      'secondary=${identity.secondaryColor}.',
    );
    stdout.writeln('${outputs.length} recursos validados y reemplazados.');
  } catch (error) {
    final validFallback = _existingResourcesAreValid(root, target);
    stderr.writeln(
      'No se pudo sincronizar la identidad ${_targetLabel(target)}: $error\n'
      '${validFallback ? 'Se conservaron recursos locales válidos.' : 'Los recursos locales no están completos o no son válidos.'}',
    );
    if (!validFallback) exitCode = 1;
  }
}

_BrandingTarget _parseTarget(List<String> arguments) {
  if (arguments.isEmpty ||
      (arguments.length == 1 && arguments.single == '--all')) {
    return _BrandingTarget.all;
  }
  if (arguments.length == 1 && arguments.single == '--web') {
    return _BrandingTarget.web;
  }
  if (arguments.length == 1 && arguments.single == '--web-maskable') {
    return _BrandingTarget.webMaskable;
  }
  if (arguments.length == 1 && arguments.single == '--android') {
    return _BrandingTarget.android;
  }
  throw const FormatException('Parámetro de destino no válido.');
}

String _targetLabel(_BrandingTarget target) => switch (target) {
      _BrandingTarget.web => 'Web/PWA',
      _BrandingTarget.webMaskable => 'maskable Web/PWA',
      _BrandingTarget.android => 'Android',
      _BrandingTarget.all => 'Web/PWA y Android',
    };

Future<void> _addWebResources(
  Directory root,
  _PublicProjectIdentity identity,
  Future<image.Image> Function() master,
  HttpClient client,
  Map<File, Uint8List> outputs,
) async {
  final manifest = _file(root, 'web/manifest.json');
  outputs
    ..[_file(root, 'web/favicon.png')] = await _variant(
      identity,
      master,
      client,
      name: 'favicon-32.png',
      size: 32,
      fallback: (source) =>
          renderTransparentWebIcon(source, size: 32, contentScale: .92),
    )
    ..[_file(root, 'web/icons/Icon-192.png')] = await _variant(
      identity,
      master,
      client,
      name: 'pwa-192.png',
      size: 192,
      fallback: (source) =>
          renderTransparentWebIcon(source, size: 192, contentScale: .92),
    )
    ..[_file(root, 'web/icons/Icon-512.png')] = await _variant(
      identity,
      master,
      client,
      name: 'pwa-512.png',
      size: 512,
      fallback: (source) =>
          renderTransparentWebIcon(source, size: 512, contentScale: .92),
    )
    ..[_file(root, 'web/icons/Icon-shortcut-192.png')] = await _variant(
      identity,
      master,
      client,
      name: 'shortcut-192.png',
      size: 192,
      fallback: (source) =>
          renderTransparentWebIcon(source, size: 192, contentScale: .70),
    );
  await _addWebMaskableResources(root, identity, master, client, outputs);
  outputs[manifest] = _updatedManifest(manifest, identity);
}

Future<void> _addWebMaskableResources(
  Directory root,
  _PublicProjectIdentity identity,
  Future<image.Image> Function() master,
  HttpClient client,
  Map<File, Uint8List> outputs,
) async {
  final background = _manifestBackgroundColor(_file(root, 'web/manifest.json'));
  outputs
    ..[_file(root, 'web/icons/Icon-maskable-192.png')] = await _variant(
      identity,
      master,
      client,
      name: 'maskable-192.png',
      size: 192,
      alpha: ProjectIconAlpha.opaque,
      fallback: (source) => renderOpaqueWebIcon(
        source,
        size: 192,
        contentScale: .72,
        backgroundRed: background.$1,
        backgroundGreen: background.$2,
        backgroundBlue: background.$3,
      ),
    )
    ..[_file(root, 'web/icons/Icon-maskable-512.png')] = await _variant(
      identity,
      master,
      client,
      name: 'maskable-512.png',
      size: 512,
      alpha: ProjectIconAlpha.opaque,
      fallback: (source) => renderOpaqueWebIcon(
        source,
        size: 512,
        contentScale: .72,
        backgroundRed: background.$1,
        backgroundGreen: background.$2,
        backgroundBlue: background.$3,
      ),
    );
}

Future<void> _addAndroidResources(
  Directory root,
  _PublicProjectIdentity identity,
  Future<image.Image> Function() master,
  HttpClient client,
  Map<File, Uint8List> outputs,
) async {
  const launcherSizes = <String, int>{
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  const adaptiveSizes = <String, int>{
    'mdpi': 108,
    'hdpi': 162,
    'xhdpi': 216,
    'xxhdpi': 324,
    'xxxhdpi': 432,
  };
  const notificationSizes = <String, int>{
    'mdpi': 24,
    'hdpi': 36,
    'xhdpi': 48,
    'xxhdpi': 72,
    'xxxhdpi': 96,
  };

  final launcher = await _variant(
    identity,
    master,
    client,
    name: 'android-launcher-192.png',
    size: 192,
    alpha: ProjectIconAlpha.opaque,
    fallback: (source) => _renderOnBackground(
      source,
      size: 192,
      contentScale: .74,
      backgroundHex: identity.secondaryColor,
    ),
  );
  final round = await _variant(
    identity,
    master,
    client,
    name: 'round-192.png',
    size: 192,
    alpha: ProjectIconAlpha.opaque,
    fallback: (source) => _renderOnBackground(
      source,
      size: 192,
      contentScale: .60,
      backgroundHex: identity.secondaryColor,
    ),
  );
  for (final entry in launcherSizes.entries) {
    outputs[_file(
      root,
      'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
    )] = _resizePng(launcher, entry.value);
    outputs[_file(
      root,
      'android/app/src/main/res/mipmap-${entry.key}/ic_launcher_round.png',
    )] = _resizePng(round, entry.value);
  }

  final foreground = await _variant(
    identity,
    master,
    client,
    name: 'adaptive-foreground-432.png',
    size: 432,
    fallback: (source) =>
        _renderTransparent(source, size: 432, contentScale: 78 / 108),
  );
  final monochrome = await _variant(
    identity,
    master,
    client,
    name: 'adaptive-monochrome-432.png',
    size: 432,
    alpha: ProjectIconAlpha.monochrome,
    fallback: (source) =>
        _renderMonochrome(source, size: 432, contentScale: 78 / 108),
  );
  for (final entry in adaptiveSizes.entries) {
    outputs[_file(
      root,
      'android/app/src/main/res/mipmap-${entry.key}/ic_launcher_foreground.png',
    )] = _resizePng(foreground, entry.value);
    outputs[_file(
      root,
      'android/app/src/main/res/mipmap-${entry.key}/ic_launcher_monochrome.png',
    )] = _resizePng(monochrome, entry.value);
  }

  final notifications = <int, Uint8List>{};
  for (final remoteSize in {24, 48, 72, 96}) {
    notifications[remoteSize] = await _variant(
      identity,
      master,
      client,
      name: 'notification-$remoteSize.png',
      size: remoteSize,
      alpha: ProjectIconAlpha.monochrome,
      fallback: (source) =>
          _renderMonochrome(source, size: remoteSize, contentScale: .76),
    );
  }
  for (final entry in notificationSizes.entries) {
    final remoteSize = entry.value == 36 ? 48 : entry.value;
    outputs[_file(
      root,
      'android/app/src/main/res/drawable-${entry.key}/ic_stat_tuktuk.png',
    )] = _resizePng(notifications[remoteSize]!, entry.value);
  }

  const adaptiveIcon = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/brand_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
''';
  const themedIcon = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/brand_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
''';
  outputs
    ..[_file(
      root,
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    )] = _xmlBytes(adaptiveIcon)
    ..[_file(
      root,
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml',
    )] = _xmlBytes(adaptiveIcon)
    ..[_file(
      root,
      'android/app/src/main/res/mipmap-anydpi-v33/ic_launcher.xml',
    )] = _xmlBytes(themedIcon)
    ..[_file(
      root,
      'android/app/src/main/res/mipmap-anydpi-v33/ic_launcher_round.xml',
    )] = _xmlBytes(themedIcon)
    ..[_file(root, 'android/app/src/main/res/values/colors.xml')] = _xmlBytes(
      '''<resources>
    <color name="brand_primary">${identity.primaryColor}</color>
    <color name="brand_background">${identity.secondaryColor}</color>
</resources>
''',
    )
    ..[_file(root, 'android/app/src/main/res/values/strings.xml')] = _xmlBytes(
      '''<resources>
    <string name="app_name">${const HtmlEscape(HtmlEscapeMode.element).convert(identity.name)}</string>
</resources>
''',
    );
}

Future<Uint8List> _variant(
  _PublicProjectIdentity identity,
  Future<image.Image> Function() master,
  HttpClient client, {
  required String name,
  required int size,
  required Uint8List Function(image.Image source) fallback,
  ProjectIconAlpha alpha = ProjectIconAlpha.transparent,
}) =>
    loadProjectIconVariant(
      iconUrl: identity.iconUrl,
      variantName: name,
      size: size,
      alpha: alpha,
      client: client,
      fallback: () async => fallback(await master()),
    );

Uint8List _resizePng(Uint8List source, int size) {
  final decoded = image.decodePng(source);
  if (decoded == null) throw const FormatException('Variante PNG inválida.');
  if (decoded.width == size && decoded.height == size) return source;
  return Uint8List.fromList(
    image.encodePng(
      image.copyResize(
        decoded,
        width: size,
        height: size,
        interpolation: image.Interpolation.cubic,
      ),
      level: 9,
    ),
  );
}

File _file(Directory root, String relativePath) => File(
      '${root.path}${Platform.pathSeparator}'
      '${relativePath.replaceAll('/', Platform.pathSeparator)}',
    );

Uint8List _xmlBytes(String value) => Uint8List.fromList(utf8.encode(value));

Future<_PublicProjectIdentity> _loadIdentity() async {
  final supabaseUrl =
      Platform.environment['SUPABASE_URL']?.trim().isNotEmpty == true
          ? Platform.environment['SUPABASE_URL']!.trim()
          : _defaultSupabaseUrl;
  final publishableKey =
      Platform.environment['SUPABASE_PUBLISHABLE_KEY']?.trim().isNotEmpty ==
              true
          ? Platform.environment['SUPABASE_PUBLISHABLE_KEY']!.trim()
          : _defaultPublishableKey;
  final baseUri = Uri.tryParse(supabaseUrl);
  if (baseUri == null || baseUri.scheme != 'https' || baseUri.host.isEmpty) {
    throw const FormatException('SUPABASE_URL debe ser una URL HTTPS válida.');
  }

  final rpcUri = baseUri.resolve('/rest/v1/rpc/get_public_project_identity');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.postUrl(rpcUri).timeout(
          const Duration(seconds: 20),
        );
    request.headers
      ..set(HttpHeaders.contentTypeHeader, 'application/json')
      ..set('apikey', publishableKey)
      ..set(HttpHeaders.authorizationHeader, 'Bearer $publishableKey');
    request.write(jsonEncode({'target_project_id': _projectId}));
    final response = await request.close().timeout(const Duration(seconds: 20));
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'RPC respondió HTTP ${response.statusCode}.',
        uri: rpcUri,
      );
    }
    final decoded = jsonDecode(body);
    final row = switch (decoded) {
      final List<dynamic> rows when rows.isNotEmpty => rows.first,
      final Map<String, dynamic> value => value,
      _ => null,
    };
    if (row is! Map) {
      throw const FormatException('El RPC no devolvió una identidad válida.');
    }
    return _PublicProjectIdentity.fromJson(Map<String, dynamic>.from(row));
  } finally {
    client.close(force: true);
  }
}

Future<image.Image> _downloadMasterIcon(String iconUrl) async {
  final uri = Uri.tryParse(iconUrl);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    throw const FormatException('icon_url debe ser una URL HTTPS válida.');
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request =
        await client.getUrl(uri).timeout(const Duration(seconds: 20));
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'La descarga del icono respondió HTTP ${response.statusCode}.',
        uri: uri,
      );
    }
    final builder = BytesBuilder(copy: false);
    var total = 0;
    await for (final chunk in response.timeout(const Duration(seconds: 30))) {
      total += chunk.length;
      if (total > _maximumDownloadBytes) {
        throw const FormatException('El PNG maestro supera 16 MiB.');
      }
      builder.add(chunk);
    }
    final master = image.decodePng(builder.takeBytes());
    if (master == null) {
      throw const FormatException('icon_url no contiene un PNG válido.');
    }
    if (master.width != 1024 || master.height != 1024) {
      throw FormatException(
        'El PNG maestro debe medir 1024x1024; mide '
        '${master.width}x${master.height}.',
      );
    }
    return master;
  } finally {
    client.close(force: true);
  }
}

Uint8List _renderTransparent(
  image.Image master, {
  required int size,
  required double contentScale,
}) {
  final contentSize = (size * contentScale).round().clamp(1, size);
  final resized = image.copyResize(
    master,
    width: contentSize,
    height: contentSize,
    interpolation: image.Interpolation.cubic,
  );
  final canvas = image.Image(width: size, height: size, numChannels: 4);
  image.compositeImage(
    canvas,
    resized,
    dstX: (size - contentSize) ~/ 2,
    dstY: (size - contentSize) ~/ 2,
  );
  return Uint8List.fromList(image.encodePng(canvas, level: 9));
}

Uint8List _renderOnBackground(
  image.Image master, {
  required int size,
  required double contentScale,
  required String backgroundHex,
}) {
  final color = _parseColor(backgroundHex);
  final canvas = image.Image(width: size, height: size, numChannels: 4);
  for (final pixel in canvas) {
    pixel.setRgba(color.$1, color.$2, color.$3, 255);
  }
  final contentSize = (size * contentScale).round().clamp(1, size);
  final resized = image.copyResize(
    master,
    width: contentSize,
    height: contentSize,
    interpolation: image.Interpolation.cubic,
  );
  image.compositeImage(
    canvas,
    resized,
    dstX: (size - contentSize) ~/ 2,
    dstY: (size - contentSize) ~/ 2,
  );
  return Uint8List.fromList(image.encodePng(canvas, level: 9));
}

Uint8List _renderMonochrome(
  image.Image master, {
  required int size,
  required double contentScale,
}) {
  final contentSize = (size * contentScale).round().clamp(1, size);
  final resized = image.copyResize(
    master,
    width: contentSize,
    height: contentSize,
    interpolation: image.Interpolation.cubic,
  );
  for (final pixel in resized) {
    pixel.setRgba(255, 255, 255, pixel.a.toInt());
  }
  final canvas = image.Image(width: size, height: size, numChannels: 4);
  image.compositeImage(
    canvas,
    resized,
    dstX: (size - contentSize) ~/ 2,
    dstY: (size - contentSize) ~/ 2,
  );
  final bytes = Uint8List.fromList(image.encodePng(canvas, level: 9));
  _validateVisibleAlpha(bytes, 'recurso monocromático ${size}x$size');
  return bytes;
}

(int, int, int) _parseColor(String value) {
  final rgb = int.parse(value.substring(1), radix: 16);
  return ((rgb >> 16) & 0xff, (rgb >> 8) & 0xff, rgb & 0xff);
}

Uint8List _updatedManifest(File manifest, _PublicProjectIdentity identity) {
  if (!manifest.existsSync()) {
    throw StateError('No existe ${manifest.path}.');
  }
  final decoded = jsonDecode(manifest.readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException('web/manifest.json no es un objeto JSON.');
  }
  final values = Map<String, dynamic>.from(decoded)
    ..['short_name'] = 'TukTuk Control'
    ..['theme_color'] = identity.primaryColor;
  return Uint8List.fromList(
    utf8.encode('${const JsonEncoder.withIndent('  ').convert(values)}\n'),
  );
}

(int, int, int) _manifestBackgroundColor(File manifest) {
  if (!manifest.existsSync()) {
    throw StateError('No existe ${manifest.path}.');
  }
  final decoded = jsonDecode(manifest.readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException('web/manifest.json no es un objeto JSON.');
  }
  final background = decoded['background_color']?.toString().toUpperCase();
  if (!_PublicProjectIdentity._isHexColor(background)) {
    throw const FormatException(
      'web/manifest.json no contiene background_color hexadecimal válido.',
    );
  }
  return _parseColor(background!);
}

void _validateGeneratedPngs(Map<File, Uint8List> outputs) {
  for (final entry in outputs.entries) {
    if (!entry.key.path.toLowerCase().endsWith('.png')) continue;
    final expected = _expectedPngSize(entry.key);
    final decoded = image.decodePng(entry.value);
    if (expected == null ||
        decoded == null ||
        decoded.width != expected ||
        decoded.height != expected) {
      throw StateError('Dimensiones inválidas para ${entry.key.path}.');
    }
    if (entry.key.path.contains('ic_stat_tuktuk') ||
        entry.key.path.contains('ic_launcher_monochrome')) {
      _validateVisibleAlpha(entry.value, entry.key.path);
    }
    final normalizedPath = entry.key.path.replaceAll('\\', '/').toLowerCase();
    if (normalizedPath.contains('/web/')) {
      final maskable = normalizedPath.contains('maskable');
      final shortcut = normalizedPath.contains('shortcut');
      final bounds = maskable
          ? _nonBackgroundBounds(decoded, entry.key.path)
          : visibleAlphaBounds(decoded);
      if (bounds == null) {
        throw StateError('${entry.key.path} no contiene arte visible.');
      }
      final occupiedExtent =
          (bounds.width > bounds.height ? bounds.width : bounds.height) /
              expected;
      if (shortcut && (occupiedExtent < .68 || occupiedExtent > .82)) {
        throw StateError(
          '${entry.key.path} debe ocupar entre 68% y 82% del lienzo.',
        );
      }
      if (!maskable &&
          !shortcut &&
          (occupiedExtent < .78 || occupiedExtent > .94)) {
        throw StateError(
          '${entry.key.path} debe ocupar entre 78% y 94% del lienzo.',
        );
      }
      if (maskable && occupiedExtent > .80) {
        throw StateError(
          '${entry.key.path} excede la zona segura maskable.',
        );
      }
    }
  }
}

AlphaBounds? _nonBackgroundBounds(image.Image source, String label) {
  final corner = source.getPixel(0, 0);
  var left = source.width;
  var top = source.height;
  var right = -1;
  var bottom = -1;
  for (final pixel in source) {
    if (pixel.a.toInt() != 255) {
      throw StateError('$label debe ser completamente opaco.');
    }
    if (pixel.r == corner.r && pixel.g == corner.g && pixel.b == corner.b) {
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

int? _expectedPngSize(File file) {
  final path = file.path.replaceAll('\\', '/').toLowerCase();
  final name = file.uri.pathSegments.last.toLowerCase();
  if (name == 'favicon.png') return 32;
  if (name == 'icon-192.png' ||
      name == 'icon-shortcut-192.png' ||
      name == 'icon-maskable-192.png') {
    return 192;
  }
  if (name == 'icon-512.png' ||
      name == 'icon-shortcut-512.png' ||
      name == 'icon-maskable-512.png') {
    return 512;
  }
  final density = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'].firstWhere(
    (value) => path.contains('-$value/'),
    orElse: () => '',
  );
  if (density.isEmpty) return null;
  const launcher = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  const adaptive = {
    'mdpi': 108,
    'hdpi': 162,
    'xhdpi': 216,
    'xxhdpi': 324,
    'xxxhdpi': 432,
  };
  const notification = {
    'mdpi': 24,
    'hdpi': 36,
    'xhdpi': 48,
    'xxhdpi': 72,
    'xxxhdpi': 96,
  };
  if (name == 'ic_launcher.png' || name == 'ic_launcher_round.png') {
    return launcher[density];
  }
  if (name == 'ic_launcher_foreground.png' ||
      name == 'ic_launcher_monochrome.png') {
    return adaptive[density];
  }
  if (name == 'ic_stat_tuktuk.png') return notification[density];
  return null;
}

void _validateVisibleAlpha(Uint8List bytes, String label) {
  final decoded = image.decodePng(bytes);
  if (decoded == null) throw StateError('$label no es un PNG válido.');
  var visible = 0;
  var transparent = 0;
  for (final pixel in decoded) {
    if (pixel.a.toInt() > 16) {
      visible++;
    } else {
      transparent++;
    }
  }
  final minimumVisible = (decoded.width * decoded.height * .003).ceil();
  if (visible < minimumVisible || transparent == 0) {
    throw StateError('$label no contiene una silueta transparente válida.');
  }
}

bool _existingResourcesAreValid(Directory root, _BrandingTarget target) {
  final files = <File>[];
  final requiredFiles = <File>[];
  if (target != _BrandingTarget.android) {
    files.addAll([
      _file(root, 'web/favicon.png'),
      _file(root, 'web/icons/Icon-192.png'),
      _file(root, 'web/icons/Icon-512.png'),
      _file(root, 'web/icons/Icon-shortcut-192.png'),
      _file(root, 'web/icons/Icon-maskable-192.png'),
      _file(root, 'web/icons/Icon-maskable-512.png'),
    ]);
    requiredFiles.add(_file(root, 'web/manifest.json'));
  }
  if (target != _BrandingTarget.web && target != _BrandingTarget.webMaskable) {
    for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      files.addAll([
        _file(root, 'android/app/src/main/res/mipmap-$density/ic_launcher.png'),
        _file(root,
            'android/app/src/main/res/mipmap-$density/ic_launcher_round.png'),
        _file(root,
            'android/app/src/main/res/mipmap-$density/ic_launcher_foreground.png'),
        _file(root,
            'android/app/src/main/res/mipmap-$density/ic_launcher_monochrome.png'),
        _file(root,
            'android/app/src/main/res/drawable-$density/ic_stat_tuktuk.png'),
      ]);
    }
    requiredFiles.addAll([
      _file(root, 'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml'),
      _file(
        root,
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml',
      ),
      _file(root, 'android/app/src/main/res/mipmap-anydpi-v33/ic_launcher.xml'),
      _file(
        root,
        'android/app/src/main/res/mipmap-anydpi-v33/ic_launcher_round.xml',
      ),
      _file(root, 'android/app/src/main/res/values/colors.xml'),
      _file(root, 'android/app/src/main/res/values/strings.xml'),
    ]);
  }
  try {
    if (requiredFiles.any((file) => !file.existsSync())) return false;
    for (final file in files) {
      if (!file.existsSync()) return false;
      final decoded = image.decodePng(file.readAsBytesSync());
      final expected = _expectedPngSize(file);
      if (decoded == null ||
          expected == null ||
          decoded.width != expected ||
          decoded.height != expected) {
        return false;
      }
    }
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> _replaceAtomically(Map<File, Uint8List> outputs) async {
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final staged = <File, File>{};
  final backups = <File, File>{};
  final installed = <File>[];
  try {
    for (final entry in outputs.entries) {
      await entry.key.parent.create(recursive: true);
      final temporary = File('${entry.key.path}.$stamp.tmp');
      await temporary.writeAsBytes(entry.value, flush: true);
      staged[entry.key] = temporary;
    }
    for (final target in outputs.keys) {
      if (await target.exists()) {
        final backup = File('${target.path}.$stamp.bak');
        await target.rename(backup.path);
        backups[target] = backup;
      }
      await staged[target]!.rename(target.path);
      installed.add(target);
    }
    for (final backup in backups.values) {
      await backup.delete();
    }
  } catch (_) {
    for (final target in installed.reversed) {
      if (await target.exists()) await target.delete();
      final backup = backups[target];
      if (backup != null && await backup.exists()) {
        await backup.rename(target.path);
      }
    }
    for (final entry in backups.entries) {
      if (!await entry.key.exists() && await entry.value.exists()) {
        await entry.value.rename(entry.key.path);
      }
    }
    rethrow;
  } finally {
    for (final temporary in staged.values) {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}

class _PublicProjectIdentity {
  const _PublicProjectIdentity({
    required this.name,
    required this.iconUrl,
    required this.primaryColor,
    required this.secondaryColor,
    required this.updatedAt,
  });

  factory _PublicProjectIdentity.fromJson(Map<String, dynamic> values) {
    final projectId = values['project_id']?.toString().trim();
    final name = values['name']?.toString().trim();
    final iconUrl = values['icon_url']?.toString().trim();
    final primaryColor =
        values['primary_color']?.toString().trim().toUpperCase();
    final secondaryColor =
        values['secondary_color']?.toString().trim().toUpperCase();
    final updatedAt = values['updated_at']?.toString().trim();
    if (projectId != _projectId || name == null || name.isEmpty) {
      throw const FormatException('La identidad no corresponde al proyecto.');
    }
    final iconUri = Uri.tryParse(iconUrl ?? '');
    if (iconUri == null ||
        iconUri.scheme != 'https' ||
        iconUri.host.isEmpty ||
        !iconUri.path.toLowerCase().endsWith('.png')) {
      throw const FormatException('La identidad no contiene icon_url HTTPS.');
    }
    if (!_isHexColor(primaryColor) || !_isHexColor(secondaryColor)) {
      throw const FormatException('Los colores de identidad no son válidos.');
    }
    return _PublicProjectIdentity(
      name: name,
      iconUrl: iconUri.toString(),
      primaryColor: primaryColor!,
      secondaryColor: secondaryColor!,
      updatedAt: updatedAt == null || updatedAt.isEmpty ? null : updatedAt,
    );
  }

  static bool _isHexColor(String? value) =>
      value != null && RegExp(r'^#[0-9A-F]{6}$').hasMatch(value);

  final String name;
  final String iconUrl;
  final String primaryColor;
  final String secondaryColor;
  final String? updatedAt;
}
