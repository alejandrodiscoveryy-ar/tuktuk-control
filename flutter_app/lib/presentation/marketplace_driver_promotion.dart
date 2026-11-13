part of '../main.dart';

/// Same URL for the copy, PNG QR and customer entry. Never use a driver UUID.
Uri marketplaceDriverPromoUri(String code) {
  if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(code)) {
    throw ArgumentError('Invalid promotion code');
  }
  return Uri.https('www.vrixora.com', '/cliente/tuk/', {'conductor': code});
}

String marketplaceDriverPromoCopy(String name, String code) =>
    '¡Viaja conmigo!\n\n'
    'Soy $name, conductor de la Agencia TukTuk. Solicita tu transporte de forma fácil desde mi enlace personal.\n\n'
    '${marketplaceDriverPromoUri(code)}\n\n'
    'Agencia TukTuk. Tu conductor de confianza, a un toque.';

String _promoCategoryLabel(String code) => switch (code) {
  'motorcycle' => 'Moto', 'bicitaxi' => 'Bicitaxi', 'tricycle' => 'Triciclo',
  'light_car' => 'Auto', 'van' => 'Furgoneta', 'truck' => 'Camión',
  'bicycle' => 'Bicicleta', _ => 'Transporte',
};
String _promoServiceLabel(String code) => switch (code) {
  'passenger' => 'Pasajeros', 'courier' => 'Mensajería', 'cargo' => 'Carga',
  _ => '',
};

/// Fixed-size integer QR modules, black on white, four-module quiet zone.
QrImage marketplaceDriverPromoQr(String code) {
  final qr = QrCode(6, QrErrorCorrectLevel.M)
    ..addData(marketplaceDriverPromoUri(code).toString());
  return QrImage(qr);
}

/// HTTP uses the browser transport on web and the native transport elsewhere.
Future<Uint8List> downloadMarketplacePromoPortrait(Uri url, {http.Client? client}) async {
  if (url.scheme != 'https' || url.host.isEmpty || url.userInfo.isNotEmpty) {
    throw StateError('PROMO_PHOTO_URL_INVALID');
  }
  final owned = client == null;
  final transport = client ?? http.Client();
  try {
    final response = await transport.get(url).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty ||
        response.bodyBytes.length > 10 * 1024 * 1024) {
      throw StateError('PROMO_PHOTO_DOWNLOAD_FAILED');
    }
    return response.bodyBytes;
  } finally {
    if (owned) transport.close();
  }
}

Future<ui.Image> _promoDecode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

/// Use only the approved master icon from the central identity. The full
/// TukTuk Control wordmark belongs to the management application, not this
/// customer-facing Agency TukTuk promotion.
Future<Uint8List?> loadMarketplacePromoBrandLogo(ProjectIdentity identity, {http.Client? client}) async {
  final uri = Uri.tryParse(identity.iconUrl ?? '');
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  try {
    final bytes = await downloadMarketplacePromoPortrait(uri, client: client);
    final decoded = await _promoDecode(bytes);
    decoded.dispose();
    return bytes;
  } catch (_) {
    // Text-only brand fallback, never the full Control wordmark or old icon.
    return null;
  }
}

Color _promoBrandColor(String hex, Color fallback) {
  if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return fallback;
  return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}

void _promoText(Canvas canvas, String value, double x, double y, double width,
    double fontSize, Color color, {bool center = false,
    FontWeight weight = FontWeight.w700, int lines = 2}) {
  final painter = TextPainter(
    text: TextSpan(text: value, style: TextStyle(color: color,
      fontSize: fontSize, fontWeight: weight, height: 1.14)),
    textDirection: ui.TextDirection.ltr,
    textAlign: center ? TextAlign.center : TextAlign.left,
    maxLines: lines, ellipsis: '…',
  )..layout(minWidth: width, maxWidth: width);
  painter.paint(canvas, Offset(x,y));
  painter.dispose();
}

void _promoFitImage(Canvas canvas, ui.Image image, Rect rect, {bool cover = false}) {
  final size = Size(image.width.toDouble(), image.height.toDouble());
  final fitted = applyBoxFit(cover ? BoxFit.cover : BoxFit.contain, size, rect.size);
  final source = Alignment.center.inscribe(fitted.source, Offset.zero & size);
  final dest = Alignment.center.inscribe(fitted.destination, rect);
  canvas.drawImageRect(image, source, dest, Paint()..filterQuality = FilterQuality.high);
}

/// Renders the actual exported artwork, not a separate HTML QR or screenshot.
/// No photos or generated files are uploaded by this renderer.
Future<Uint8List> renderMarketplaceDriverPromoCard({
  required String name, required String code, required String modality,
  required bool story, Uint8List? photoBytes, Uint8List? logoBytes,
  ProjectIdentity identity = ProjectIdentity.fallback,
}) async {
  const width = 1080;
  final height = story ? 1920 : 1080;
  ui.Image? portrait, logo;
  try {
    if (photoBytes != null) portrait = await _promoDecode(photoBytes);
    if (logoBytes != null) logo = await _promoDecode(logoBytes);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final bounds = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    final primary = _promoBrandColor(identity.primaryColorHex, const Color(0xFF06B6D4));
    final secondary = _promoBrandColor(identity.secondaryColorHex, const Color(0xFF0F172A));
    const white = Color(0xFFFFFFFF);
    const muted = Color(0xFFCBD5E1);
    // Preserve a dark readable card even if Admin selects a light brand color.
    final background = secondary.computeLuminance() > .18
        ? Color.lerp(secondary, const Color(0xFF0B0F14), .85)!
        : secondary;
    final accent = primary.computeLuminance() < .22
        ? Color.lerp(primary, white, .48)!
        : primary;
    canvas.drawRect(bounds, Paint()..shader = LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [background, const Color(0xFF0B0F14),
        Color.lerp(background, primary, .12)!],
    ).createShader(bounds));
    // Premium agency card: restrained border, tonal watermark and one clear
    // hierarchy. All typography and ornament stay outside the QR quiet zone.
    final outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(24, 24, 1032, height - 48.0), const Radius.circular(48));
    canvas.drawRRect(outer, Paint()
      ..style = PaintingStyle.stroke ..strokeWidth = 2
      ..color = primary.withValues(alpha: .28));
    canvas.save();
    canvas.clipRRect(outer);
    final glow = Rect.fromCircle(center: Offset(1030, story ? 230 : 110), radius: 560);
    canvas.drawRect(glow, Paint()..shader = RadialGradient(
      colors: [primary.withValues(alpha: .22), primary.withValues(alpha: 0)],
    ).createShader(glow));
    final watermark = ui.Path()
      ..moveTo(850, height - 430.0)
      ..lineTo(1080, height - 650.0)
      ..lineTo(1080, height - 570.0)
      ..lineTo(850, height - 350.0)
      ..close();
    canvas.drawPath(watermark, Paint()..color = primary.withValues(alpha: .09));
    canvas.restore();
    final headerY = story ? 105.0 : 48.0;
    if (logo != null) {
      _promoFitImage(canvas, logo, Rect.fromLTWH(72, headerY, 136, 136));
    }
    final brandX = logo == null ? 72.0 : 225.0;
    _promoText(canvas, 'Agencia TukTuk', brandX, headerY + 20, 800 - brandX, 51, white, lines: 1);
    _promoText(canvas, 'MI TUKTUK', brandX, headerY + 85, 800 - brandX, 28, accent, lines: 1);
    canvas.drawLine(Offset(72, headerY + 161), Offset(1008, headerY + 161),
      Paint()..color = primary.withValues(alpha: .24)..strokeWidth = 2);

    final photoRect = story
        ? const Rect.fromLTWH(350, 312, 380, 380)
        : const Rect.fromLTWH(82, 251, 252, 252);
    canvas.drawCircle(photoRect.center, photoRect.width / 2 + 16,
      Paint()..color = primary.withValues(alpha: .13));
    canvas.drawCircle(photoRect.center, photoRect.width / 2 + 6,
      Paint()..shader = LinearGradient(
        colors: [accent, primary.withValues(alpha: .35)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ).createShader(photoRect));
    canvas.save();
    canvas.clipPath(ui.Path()..addOval(photoRect));
    canvas.drawRect(photoRect, Paint()..color = const Color(0xFF27384A));
    if (portrait != null) {
      _promoFitImage(canvas, portrait, photoRect, cover: true);
    } else {
      canvas.drawCircle(Offset(photoRect.center.dx, photoRect.top + photoRect.height * .36),
        photoRect.width * .17, Paint()..color = muted);
      canvas.drawOval(Rect.fromCenter(center: Offset(photoRect.center.dx, photoRect.bottom - photoRect.height * .1),
        width: photoRect.width * .76, height: photoRect.height * .55), Paint()..color = muted);
    }
    canvas.restore();

    if (story) {
      _promoText(canvas, '¡Viaja conmigo!', 64, 733, 952, 42, accent, center: true, lines: 1);
      _promoText(canvas, name, 64, 797, 952, 72, white, center: true);
      _promoText(canvas, 'Conductor de la Agencia TukTuk', 70, 974, 940, 37, white, center: true, lines: 1);
      _promoText(canvas, modality, 70, 1033, 940, 35, accent, center: true, lines: 2);
    } else {
      _promoText(canvas, '¡Viaja conmigo!', 380, 244, 628, 37, accent, lines: 1);
      _promoText(canvas, name, 380, 302, 628, 53, white);
      _promoText(canvas, 'Conductor de la Agencia TukTuk', 380, 437, 628, 29, white, lines: 1);
      _promoText(canvas, modality, 380, 482, 628, 33, accent, lines: 2);
    }
    final panel = story
      ? const Rect.fromLTWH(68, 1110, 944, 590)
      : const Rect.fromLTWH(58, 558, 964, 380);
    final panelShape = RRect.fromRectAndRadius(panel, const Radius.circular(34));
    canvas.drawRRect(panelShape, Paint()..color = Colors.white.withValues(alpha: .045));
    canvas.drawRRect(panelShape, Paint()..style = PaintingStyle.stroke
      ..strokeWidth = 2 ..color = primary.withValues(alpha: .26));
    // QR is drawn into the PNG with exact pixel-aligned black/white squares.
    final qr = marketplaceDriverPromoQr(code);
    const module = 7.0;
    final qrSize = (qr.moduleCount + 8) * module;
    final qrX = story ? ((1080 - qrSize) / 2).floorToDouble() : 78.0;
    final qrY = story ? 1160.0 : 578.0;
    canvas.drawRect(Rect.fromLTWH(qrX, qrY, qrSize, qrSize), Paint()..color = white);
    final dark = Paint()..color = const Color(0xFF000000)..isAntiAlias = false;
    for (var row = 0; row < qr.moduleCount; row++) {
      for (var column = 0; column < qr.moduleCount; column++) {
        if (qr.isDark(row, column)) {
          canvas.drawRect(Rect.fromLTWH(qrX + (column + 4) * module,
            qrY + (row + 4) * module, module, module), dark);
        }
      }
    }
    if (story) {
      _promoText(canvas, 'Escanea y viaja conmigo', 85, 1532, 910, 48, accent, center: true, lines: 1);
      _promoText(canvas, 'Solicita tu transporte desde mi enlace personal.',
        110, 1600, 860, 34, muted, center: true, lines: 2);
      _promoText(canvas, 'Tu conductor de confianza, a un toque.',
        85, 1770, 910, 34, white, center: true, lines: 2);
    } else {
      _promoText(canvas, 'Escanea y viaja conmigo', 459, 628, 520, 47, accent);
      _promoText(canvas, 'Solicita tu transporte desde mi enlace personal.',
        459, 760, 520, 34, muted, lines: 3);
      _promoText(canvas, 'Tu conductor de confianza, a un toque.',
        64, 981, 952, 29, white, center: true, lines: 2);
    }
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(width, height);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) throw StateError('PROMO_IMAGE_EXPORT_FAILED');
        return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  } finally {
    portrait?.dispose();
    logo?.dispose();
  }
}

/// A single local entry per account, versioned by artwork and public metadata.
/// Signed photo query parameters expire and must never invalidate or be stored.
const _marketplacePromoArtworkVersion = 2;
String marketplacePromoCacheFingerprint({
  required String actor, required String code, required String name,
  required String modality, required bool photoAuthorized,
  required Uri? photoUrl, required ProjectIdentity identity,
  Object? profileUpdatedAt,
}) => sha256.convert(utf8.encode(jsonEncode([
  _marketplacePromoArtworkVersion, actor, code, name, modality, photoAuthorized,
  photoUrl == null ? null : '${photoUrl.scheme}://${photoUrl.host}${photoUrl.path}',
  profileUpdatedAt?.toString(), identity.projectId, identity.iconUrl,
  identity.primaryColorHex, identity.secondaryColorHex,
  identity.updatedAt?.toIso8601String(),
]))).toString();

class MarketplacePromoArtworkCache {
  const MarketplacePromoArtworkCache(this.box);
  final Box box;
  static String _key(String actor) => 'marketplacePromoArtwork:$actor';

  ({Uint8List square, Uint8List story})? read(String actor, String fingerprint) {
    try {
      final entry = box.get(_key(actor));
      if (entry is! Map || entry['fingerprint'] != fingerprint) return null;
      final square = entry['square'], story = entry['story'];
      if (square is! Uint8List || story is! Uint8List ||
          square.isEmpty || story.isEmpty) {
        return null;
      }
      return (square: square, story: story);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String actor, String fingerprint, Uint8List square, Uint8List story) async {
    try {
      // One atomic entry, not an ever-growing collection of rendered cards.
      await box.put(_key(actor), {
        'fingerprint': fingerprint, 'square': square, 'story': story,
      });
    } catch (_) {
      // Storage quota or private browsing must not prevent using this session's card.
    }
  }

  Future<void> clear(String actor) async {
    try { await box.delete(_key(actor)); } catch (_) {}
  }
}

class MarketplaceDriverPromotionScreen extends StatefulWidget {
  const MarketplaceDriverPromotionScreen({required this.store, super.key});
  final RecordStore store;
  @override
  State<MarketplaceDriverPromotionScreen> createState() => _MarketplaceDriverPromotionScreenState();
}

class _MarketplaceDriverPromotionScreenState extends State<MarketplaceDriverPromotionScreen> {
  final _client = Supabase.instance.client;
  final _name = TextEditingController();
  final _cache = MarketplacePromoArtworkCache(Hive.box(_metaBox));
  late final String? _actor;
  StreamSubscription<AuthState>? _auth;
  bool _busy = true, _consent = false, _sharePhoto = false, _enabled = false;
  bool _story = false, _sharing = false;
  String? _error, _code;
  Uint8List? _squareBytes, _storyBytes;
  int _revision = 0;
  bool get _sameUser => _actor != null && _client.auth.currentUser?.id == _actor;
  Uint8List? get _artwork => _story ? _storyBytes : _squareBytes;
  String get _fileName => _story ? 'Mi-TukTuk-historia.png' : 'Mi-TukTuk.png';
  String? get _copy => _code == null ? null : marketplaceDriverPromoCopy(_name.text.trim(), _code!);

  @override
  void initState() {
    super.initState();
    _actor = _client.auth.currentUser?.id;
    _name.text = widget.store.profileDisplayName;
    _auth = _client.auth.onAuthStateChange.listen((_) {
      if (!_sameUser && mounted) {
        _revision++;
        if (_actor != null) unawaited(_cache.clear(_actor));
        setState(() {
          _enabled = false; _busy = false; _code = null;
          _squareBytes = null; _storyBytes = null;
          _error = 'Inicia sesión nuevamente para abrir Mi TukTuk.';
        });
      }
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    _revision++;
    _auth?.cancel();
    _name.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    final revision = ++_revision;
    final actor = _actor;
    if (actor == null || !_sameUser) {
      setState(() { _busy = false; _error = 'Inicia sesión para crear tu tarjeta.'; });
      return;
    }
    setState(() { _busy = true; _error = null; _squareBytes = null; _storyBytes = null; _code = null; });
    var stage = 'perfil';
    try {
      final result = await _client.rpc('get_my_marketplace_promo_profile');
      if (!mounted || !_sameUser || revision != _revision) return;
      if (result is! Map) throw StateError('PROMO_PROFILE_INVALID');
      final enabled = result['enabled'] == true;
      setState(() {
        _enabled = enabled;
        _consent = enabled;
        _sharePhoto = enabled && result['photo_authorized'] == true;
        if (result['public_name'] is String) _name.text = result['public_name'] as String;
      });
      if (!enabled) {
        await _cache.clear(actor);
        return;
      }
      final code = result['code'];
      if (code is! String) throw StateError('PROMO_CODE_INVALID');
      marketplaceDriverPromoUri(code);
      stage = 'enlace';
      final response = await _client.functions.invoke('marketplace-customer-gateway',
        body: {'operation':'promo_profile','params':{'target_code':code}});
      if (!mounted || !_sameUser || revision != _revision) return;
      final envelope = response.data;
      final raw = envelope is Map ? envelope['data'] : null;
      if (raw is! Map || raw['public_name'] is! String ||
          raw['category_code'] is! String || raw['service_codes'] is! List) {
        throw StateError('PROMO_PROFILE_UNAVAILABLE');
      }
      final services = (raw['service_codes'] as List).whereType<String>()
        .map(_promoServiceLabel).where((label) => label.isNotEmpty).toSet().join(' · ');
      if (services.isEmpty) throw StateError('PROMO_SERVICE_UNAVAILABLE');
      final name = raw['public_name'] as String;
      final modality = '${_promoCategoryLabel(raw['category_code'] as String)} · $services';
      final photoUrl = Uri.tryParse(raw['photo_url']?.toString() ?? '');
      final photoAuthorized = result['photo_authorized'] == true;
      final validPhotoUrl = photoAuthorized && photoUrl != null && photoUrl.scheme == 'https' && photoUrl.host.isNotEmpty
          ? photoUrl : null;
      if (photoAuthorized && validPhotoUrl == null) {
        // Do not reuse an old authorized portrait when the server no longer
        // confirms that the photo is available for public promotion.
        stage = 'fotografía';
        throw StateError('PROMO_PHOTO_UNAVAILABLE');
      }
      stage = 'tarjeta';
      await widget.store.refreshProjectIdentity().timeout(
        const Duration(seconds: 8), onTimeout: () {});
      if (!mounted || !_sameUser || revision != _revision) return;
      final identity = widget.store.projectIdentity;
      final fingerprint = marketplacePromoCacheFingerprint(
        actor: actor, code: code, name: name, modality: modality,
        photoAuthorized: photoAuthorized, photoUrl: validPhotoUrl,
        identity: identity, profileUpdatedAt: result['updated_at'],
      );
      final cached = force ? null : _cache.read(actor, fingerprint);
      if (cached != null) {
        setState(() {
          _name.text = name; _code = code;
          _squareBytes = cached.square; _storyBytes = cached.story;
        });
        return;
      }
      stage = 'fotografía';
      final photo = validPhotoUrl == null ? null :
          await downloadMarketplacePromoPortrait(validPhotoUrl);
      if (!mounted || !_sameUser || revision != _revision) return;
      stage = 'tarjeta';
      final logo = await loadMarketplacePromoBrandLogo(identity);
      if (!mounted || !_sameUser || revision != _revision) return;
      final square = await renderMarketplaceDriverPromoCard(name: name, code: code, modality: modality, story: false, photoBytes: photo, logoBytes: logo, identity: identity);
      final story = await renderMarketplaceDriverPromoCard(name: name, code: code, modality: modality, story: true, photoBytes: photo, logoBytes: logo, identity: identity);
      if (!mounted || !_sameUser || revision != _revision) return;
      // If the configured official icon failed to load, do not persist a
      // degraded rendering; a later visit can retry the correct identity.
      if (logo != null || identity.iconUrl == null) {
        await _cache.save(actor, fingerprint, square, story);
        if (!_sameUser) {
          await _cache.clear(actor);
          return;
        }
      }
      if (!mounted || !_sameUser || revision != _revision) return;
      setState(() { _name.text = name; _code = code; _squareBytes = square; _storyBytes = story; });
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(() {
        _error = switch (stage) {
          'fotografía' => 'No se pudo cargar tu fotografía autorizada. Reintenta sin desactivar tu perfil.',
          'tarjeta' => 'No se pudo generar la imagen de tu tarjeta. Reintenta.',
          'enlace' => 'No se pudo consultar tu enlace personal. Reintenta.',
          _ => 'No se pudo consultar tu perfil de Mi TukTuk. Reintenta.',
        };
        });
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _busy = false);
    }
  }

  Future<void> _save({required bool consent}) async {
    if (_busy || !_sameUser) return;
    final name = _name.text.trim();
    if (consent && (!_consent || name.isEmpty || name.length > 80)) {
      setState(() => _error = 'Confirma tu autorización e indica un nombre de hasta 80 caracteres.');
      return;
    }
    final revision = ++_revision;
    setState(() { _busy = true; _error = null; _code = null; _squareBytes = null; _storyBytes = null; });
    try {
      await _client.rpc('set_my_marketplace_promo_profile', params: {
        'target_public_name': consent ? name : null,
        'target_consent': consent, 'target_share_photo': consent && _sharePhoto,
      });
      if (!mounted || !_sameUser || revision != _revision) return;
      if (!consent) await _cache.clear(_actor!);
      await _load();
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(() {
        _busy = false; _error = 'No se pudo guardar el perfil. Comprueba tu conexión o disponibilidad.';
        });
      }
    }
  }

  Future<void> _shareCard() async {
    final bytes = _artwork, copy = _copy;
    if (!_sameUser || !_enabled || bytes == null || copy == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      final box = context.findRenderObject() as RenderBox?;
      final result = await SharePlus.instance.share(ShareParams(
        title: 'Mi TukTuk', text: copy,
        files: [XFile.fromData(bytes, mimeType: 'image/png', name: _fileName)],
        fileNameOverrides: [_fileName],
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        downloadFallbackEnabled: false,
      ));
      if (!mounted) return;
      if (result.status == ShareResultStatus.unavailable) {
        toast(context, 'Descarga la tarjeta y copia el mensaje para compartirlos juntos.');
      }
    } catch (_) {
      if (mounted) toast(context, 'Descarga la tarjeta y copia el mensaje para compartirlos juntos.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _downloadCard() async {
    final bytes = _artwork;
    if (!_sameUser || !_enabled || bytes == null) return;
    if (kIsWeb && driver_promo_download.downloadPromoPng(bytes, _fileName)) return;
    try {
      await SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes,
        mimeType: 'image/png', name: _fileName)], fileNameOverrides: [_fileName]));
    } catch (_) {
      if (mounted) toast(context, 'No se pudo descargar la tarjeta.');
    }
  }

  Future<void> _copyText(String text) async {
    if (!_sameUser || !_enabled || _artwork == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) toast(context, 'Copiado');
    } catch (_) {
      if (mounted) toast(context, 'Selecciona el texto para copiarlo manualmente.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final art = _artwork, copy = _copy;
    final ready = _sameUser && _enabled && !_busy && art != null && copy != null;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Mi TukTuk', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Tu conductor de confianza, a un toque.', style: TextStyle(color: kMuted)),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: kDanger)),
            TextButton(onPressed: _busy ? null : _load, child: const Text('Reintentar')),
          ],
          if (!_enabled) ...[
            TextField(controller: _name, maxLength: 80, enabled: !_busy && _sameUser,
              decoration: const InputDecoration(labelText: 'Nombre público')),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: _sharePhoto,
              onChanged: _busy || !_sameUser ? null : (value) => setState(() => _sharePhoto = value == true),
              title: const Text('Autorizar mi fotografía registrada')),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: _consent,
              onChanged: _busy || !_sameUser ? null : (value) => setState(() => _consent = value == true),
              title: const Text('Autorizo publicar mi nombre y los datos seleccionados de mi perfil'),
              subtitle: const Text('Cualquier persona con mi enlace podrá verlos. Puedo revocar el perfil; las imágenes ya compartidas pueden permanecer en redes.')),
            FilledButton(onPressed: _busy || !_sameUser || !_consent ? null : () => _save(consent: true),
              child: const Text('Activar mi perfil')),
          ],
          if (_enabled) ...[
            const SizedBox(height: 12),
            SegmentedButton<bool>(segments: const [
              ButtonSegment(value: false, label: Text('Cuadrada')),
              ButtonSegment(value: true, label: Text('Historia')),
            ], selected: {_story}, onSelectionChanged: (value) => setState(() => _story = value.first)),
            const SizedBox(height: 12),
            if (art != null) Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 380),
              child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.memory(art, fit: BoxFit.contain, gaplessPlayback: true)))),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: ready && !_sharing ? _shareCard : null,
              icon: const Icon(Icons.share_outlined), label: const Text('Compartir tarjeta y mensaje')),
            OutlinedButton.icon(onPressed: ready ? _downloadCard : null,
              icon: const Icon(Icons.download_outlined), label: const Text('Descargar imagen')),
            if (ready) ...[
              TextButton.icon(onPressed: () => _load(force: true),
                icon: const Icon(Icons.refresh), label: const Text('Actualizar tarjeta')),
              const SizedBox(height: 12),
              const Text('Tu enlace personal', style: TextStyle(fontWeight: FontWeight.w800)),
              SelectableText(marketplaceDriverPromoUri(_code!).toString()),
              TextButton.icon(onPressed: () => _copyText(marketplaceDriverPromoUri(_code!).toString()),
                icon: const Icon(Icons.link), label: const Text('Copiar enlace')),
              const SizedBox(height: 8),
              const Text('Mensaje para compartir', style: TextStyle(fontWeight: FontWeight.w800)),
              SelectableText(copy),
              TextButton.icon(onPressed: () => _copyText(copy), icon: const Icon(Icons.copy),
                label: const Text('Copiar mensaje')),
              const Text('Si tu red social no admite compartir imagen y texto juntos, descarga la tarjeta y pega el mensaje completo en tu publicación.', style: TextStyle(color: kMuted, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _busy || !_sameUser ? null : () => _save(consent: false),
              child: const Text('Desactivar mi perfil')),
          ],
        ]),
      )),
    ]);
  }
}
