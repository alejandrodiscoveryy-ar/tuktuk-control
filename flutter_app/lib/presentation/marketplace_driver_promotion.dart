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

/// Use the centralized public project identity, never a legacy bundled logo.
Future<Uint8List?> loadMarketplacePromoBrandLogo(ProjectIdentity identity, {http.Client? client}) async {
  final urls = {identity.logoUrl, identity.iconUrl}.whereType<String>();
  for (final value in urls) {
    final uri = Uri.tryParse(value);
    if (uri == null) continue;
    try {
      final bytes = await downloadMarketplacePromoPortrait(uri, client: client);
      final decoded = await _promoDecode(bytes);
      decoded.dispose();
      return bytes;
    } catch (_) {
      // The current official icon is the next fallback; otherwise use text.
    }
  }
  return null;
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
    canvas.drawCircle(Offset(970, story ? 290 : 120), 310,
      Paint()..color = primary.withValues(alpha: .10));
    canvas.drawCircle(Offset(75, height - 60.0), 320,
      Paint()..color = primary.withValues(alpha: .08));
    final headerY = story ? 92.0 : 20.0;
    // The current brand asset can be a wordmark or an icon. Preserve its full
    // aspect ratio and do not crop it using the old tuk-tuk illustration bounds.
    if (logo != null) {
      _promoFitImage(canvas, logo, Rect.fromLTWH(48, headerY, 320, 164));
    }
    final brandX = logo == null ? 68.0 : 390.0;
    final brandWidth = logo == null ? 944.0 : 610.0;
    _promoText(canvas, 'Agencia TukTuk', brandX, headerY + 24, brandWidth, 54, white, lines: 1);
    _promoText(canvas, 'MI TUKTUK', brandX, headerY + 94, brandWidth, 30, accent, lines: 1);

    final photoRect = story
        ? const Rect.fromLTWH(350, 345, 380, 380)
        : const Rect.fromLTWH(78, 216, 278, 278);
    canvas.drawCircle(photoRect.center, photoRect.width / 2 + 9,
      Paint()..color = accent);
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
      _promoText(canvas, name, 64, 775, 952, 68, white, center: true);
      _promoText(canvas, 'Conductor de la Agencia TukTuk', 70, 934, 940, 34, accent, center: true, lines: 1);
      _promoText(canvas, modality, 70, 987, 940, 35, muted, center: true, lines: 1);
      _promoText(canvas, '¡Viaja conmigo!', 70, 1050, 940, 54, white, center: true, lines: 1);
    } else {
      _promoText(canvas, '¡Viaja conmigo!', 405, 200, 615, 46, accent, lines: 1);
      _promoText(canvas, name, 405, 265, 615, 52, white);
      _promoText(canvas, 'Conductor de la Agencia TukTuk', 405, 397, 615, 31, accent, lines: 1);
      _promoText(canvas, modality, 405, 447, 615, 35, muted);
    }
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
      _promoText(canvas, 'Escanea y viaja conmigo', 60, 1550, 960, 49, accent, center: true, lines: 1);
      _promoText(canvas, 'Solicita tu transporte desde mi enlace personal.',
        95, 1625, 890, 35, muted, center: true, lines: 3);
      _promoText(canvas, 'Tu conductor de confianza, a un toque.',
        85, 1770, 910, 31, white, center: true, lines: 2);
    } else {
      _promoText(canvas, 'Escanea y viaja conmigo', 460, 590, 545, 49, accent);
      _promoText(canvas, 'Solicita tu transporte desde mi enlace personal.',
        460, 728, 545, 34, muted, lines: 4);
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

class MarketplaceDriverPromotionScreen extends StatefulWidget {
  const MarketplaceDriverPromotionScreen({required this.store, super.key});
  final RecordStore store;
  @override
  State<MarketplaceDriverPromotionScreen> createState() => _MarketplaceDriverPromotionScreenState();
}

class _MarketplaceDriverPromotionScreenState extends State<MarketplaceDriverPromotionScreen> {
  final _client = Supabase.instance.client;
  final _name = TextEditingController();
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

  Future<void> _load() async {
    final revision = ++_revision;
    if (!_sameUser) {
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
      if (!enabled) return;
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
      stage = 'fotografía';
      Uint8List? photo;
      final photoUrl = Uri.tryParse(raw['photo_url']?.toString() ?? '');
      if (photoUrl != null && photoUrl.scheme == 'https' && photoUrl.host.isNotEmpty) {
        photo = await downloadMarketplacePromoPortrait(photoUrl);
      } else if (result['photo_authorized'] == true) {
        throw StateError('PROMO_PHOTO_UNAVAILABLE');
      }
      if (!mounted || !_sameUser || revision != _revision) return;
      stage = 'tarjeta';
      await widget.store.refreshProjectIdentity().timeout(
        const Duration(seconds: 8), onTimeout: () {});
      if (!mounted || !_sameUser || revision != _revision) return;
      final identity = widget.store.projectIdentity;
      final logo = await loadMarketplacePromoBrandLogo(identity);
      if (!mounted || !_sameUser || revision != _revision) return;
      final square = await renderMarketplaceDriverPromoCard(name: name, code: code, modality: modality, story: false, photoBytes: photo, logoBytes: logo, identity: identity);
      final story = await renderMarketplaceDriverPromoCard(name: name, code: code, modality: modality, story: true, photoBytes: photo, logoBytes: logo, identity: identity);
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
