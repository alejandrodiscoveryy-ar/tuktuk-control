import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as image;

const _projectId = 'dfb41cea-a812-46f2-b511-7a60bd3d78af';
const _defaultSupabaseUrl = 'https://vvxvnywzgtqhlaqpxyqh.supabase.co';
const _defaultPublishableKey = 'sb_publishable_MOmcX334dezcrlRAaQlvbg_Scd-RJTV';
const _maximumDownloadBytes = 16 * 1024 * 1024;

enum _BrandingTarget { web, android, all }

Future<void> main(List<String> arguments) async {
  final root = File.fromUri(Platform.script).parent.parent;
  late final _BrandingTarget target;
  try {
    target = _parseTarget(arguments);
  } catch (error) {
    stderr.writeln('$error\nUso: dart run tool/sync_project_branding.dart '
        '[--web|--android|--all]');
    exitCode = 64;
    return;
  }

  try {
    final identity = await _loadIdentity();
    final master = await _downloadMasterIcon(identity.iconUrl);
    final outputs = <File, Uint8List>{};
    if (target != _BrandingTarget.android) {
      _addWebResources(root, identity, master, outputs);
    }
    if (target != _BrandingTarget.web) {
      _addAndroidResources(root, identity, master, outputs);
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
  if (arguments.length == 1 && arguments.single == '--android') {
    return _BrandingTarget.android;
  }
  throw const FormatException('Parámetro de destino no válido.');
}

String _targetLabel(_BrandingTarget target) => switch (target) {
      _BrandingTarget.web => 'Web/PWA',
      _BrandingTarget.android => 'Android',
      _BrandingTarget.all => 'Web/PWA y Android',
    };

void _addWebResources(
  Directory root,
  _PublicProjectIdentity identity,
  image.Image master,
  Map<File, Uint8List> outputs,
) {
  outputs
    ..[_file(root, 'web/favicon.png')] =
        _renderTransparent(master, size: 32, contentScale: .90)
    ..[_file(root, 'web/icons/Icon-192.png')] =
        _renderTransparent(master, size: 192, contentScale: .88)
    ..[_file(root, 'web/icons/Icon-512.png')] =
        _renderTransparent(master, size: 512, contentScale: .88)
    ..[_file(root, 'web/icons/Icon-maskable-192.png')] =
        _renderTransparent(master, size: 192, contentScale: .72)
    ..[_file(root, 'web/icons/Icon-maskable-512.png')] =
        _renderTransparent(master, size: 512, contentScale: .72);
  final manifest = _file(root, 'web/manifest.json');
  outputs[manifest] = _updatedManifest(manifest, identity);
}

void _addAndroidResources(
  Directory root,
  _PublicProjectIdentity identity,
  image.Image master,
  Map<File, Uint8List> outputs,
) {
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

  for (final entry in launcherSizes.entries) {
    final bytes = _renderOnBackground(
      master,
      size: entry.value,
      contentScale: .74,
      backgroundHex: identity.secondaryColor,
    );
    outputs[_file(
      root,
      'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
    )] = bytes;
    outputs[_file(
      root,
      'android/app/src/main/res/mipmap-${entry.key}/ic_launcher_round.png',
    )] = bytes;
  }

  for (final entry in adaptiveSizes.entries) {
    outputs[_file(
      root,
      'android/app/src/main/res/mipmap-${entry.key}/ic_launcher_foreground.png',
    )] = _renderTransparent(
      master,
      size: entry.value,
      contentScale: 66 / 108,
    );
    outputs[_file(
      root,
      'android/app/src/main/res/mipmap-${entry.key}/ic_launcher_monochrome.png',
    )] = _renderMonochrome(
      master,
      size: entry.value,
      contentScale: 66 / 108,
    );
  }

  for (final entry in notificationSizes.entries) {
    outputs[_file(
      root,
      'android/app/src/main/res/drawable-${entry.key}/ic_stat_tuktuk.png',
    )] = _renderMonochrome(
      master,
      size: entry.value,
      contentScale: .76,
    );
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
  }
}

int? _expectedPngSize(File file) {
  final path = file.path.replaceAll('\\', '/').toLowerCase();
  final name = file.uri.pathSegments.last.toLowerCase();
  if (name == 'favicon.png') return 32;
  if (name == 'icon-192.png' || name == 'icon-maskable-192.png') return 192;
  if (name == 'icon-512.png' || name == 'icon-maskable-512.png') return 512;
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
      _file(root, 'web/icons/Icon-maskable-192.png'),
      _file(root, 'web/icons/Icon-maskable-512.png'),
    ]);
    requiredFiles.add(_file(root, 'web/manifest.json'));
  }
  if (target != _BrandingTarget.web) {
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
    if (iconUri == null || iconUri.scheme != 'https' || iconUri.host.isEmpty) {
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
