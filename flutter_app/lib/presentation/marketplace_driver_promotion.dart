part of '../main.dart';

/// Same URL for the copy, PNG QR and customer entry. Never use a driver UUID.
Uri marketplaceDriverPromoUri(String code) {
  if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(code)) {
    throw ArgumentError('Invalid promotion code');
  }
  return Uri.https('www.vrixora.com', '/cliente/tuk/', {'conductor': code});
}

String marketplaceDriverPromoCopy(String name, String code) =>
    '¡Viaja conmigo! Soy $name, conductor de TukTuk.\n'
    'Solicita tu transporte desde mi enlace personal. Si no estoy disponible, '
    'otro conductor de nuestra flota podrá atenderte.\n\n'
    '${marketplaceDriverPromoUri(code)}\n\n'
    'Tu conductor de confianza. Toda una flota a tu disposición.';

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

Future<ui.Image> _promoDecode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

void _promoText(Canvas canvas, String value, double x, double y, double width,
    double fontSize, Color color, {bool center = false,
    FontWeight weight = FontWeight.w700, int lines = 2}) {
  final painter = TextPainter(
    text: TextSpan(text: value, style: TextStyle(color: color,
      fontSize: fontSize, fontWeight: weight, height: 1.14)),
    textDirection: TextDirection.ltr,
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
}) async {
  final width = 1080;
  final height = story ? 1920 : 1080;
  ui.Image? portrait, logo;
  try {
    if (photoBytes != null) portrait = await _promoDecode(photoBytes);
    if (logoBytes != null) logo = await _promoDecode(logoBytes);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final bounds = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    canvas.drawRect(bounds, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF111C28), Color(0xFF0A101A), Color(0xFF192B3C)],
    ).createShader(bounds));
    const orange = Color(0xFFFB923C);
    const white = Color(0xFFFFFFFF);
    const muted = Color(0xFFCBD5E1);
    canvas.drawCircle(Offset(970, story ? 290 : 120), 310,
      Paint()..color = const Color(0x18FB923C));
    canvas.drawCircle(Offset(75, height - 60.0), 320,
      Paint()..color = const Color(0x1722D3EE));
    final headerY = story ? 125.0 : 44.0;
    if (logo != null) {
      _promoFitImage(canvas, logo, Rect.fromLTWH(68, headerY, 265, 116));
    } else {
      _promoText(canvas, 'TukTuk', 68, headerY + 14, 340, 65, orange, lines: 1);
    }
    _promoText(canvas, 'MI TUKTUK', 690, headerY + 42, 310, 30, muted,
      center: true, lines: 1);

    final photoRect = story
        ? const Rect.fromLTWH(350, 345, 380, 380)
        : const Rect.fromLTWH(78, 216, 278, 278);
    canvas.drawCircle(photoRect.center, photoRect.width / 2 + 9,
      Paint()..color = orange);
    canvas.save();
    canvas.clipPath(Path()..addOval(photoRect));
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
      _promoText(canvas, modality, 70, 945, 940, 37, orange, center: true);
      _promoText(canvas, '¡Viaja conmigo!', 70, 1050, 940, 54, white, center: true, lines: 1);
    } else {
      _promoText(canvas, '¡Viaja conmigo!', 405, 200, 615, 46, orange, lines: 1);
      _promoText(canvas, name, 405, 265, 615, 58, white);
      _promoText(canvas, modality, 405, 418, 615, 35, muted);
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
      _promoText(canvas, 'Escanea y viaja conmigo', 60, 1550, 960, 49, orange, center: true, lines: 1);
      _promoText(canvas, 'Si no estoy disponible, TukTuk busca otro conductor para ti.',
        95, 1625, 890, 35, muted, center: true, lines: 3);
      _promoText(canvas, 'Tu conductor de confianza. Toda una flota a tu disposición.',
        85, 1770, 910, 31, white, center: true, lines: 2);
    } else {
      _promoText(canvas, 'Escanea y viaja conmigo', 460, 590, 545, 49, orange);
      _promoText(canvas, 'Si no estoy disponible, TukTuk busca otro conductor para ti.',
        460, 728, 545, 34, muted, lines: 4);
      _promoText(canvas, 'Tu conductor de confianza. Toda una flota a tu disposición.',
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
      Uint8List? photo;
      final photoUrl = Uri.tryParse(raw['photo_url']?.toString() ?? '');
      if (photoUrl != null && photoUrl.scheme == 'https' && photoUrl.host.isNotEmpty) {
        final data = await NetworkAssetBundle(photoUrl).load(photoUrl.toString()).timeout(const Duration(seconds: 15));
        photo = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } else if (result['photo_authorized'] == true) {
        throw StateError('PROMO_PHOTO_UNAVAILABLE');
      }
      if (!mounted || !_sameUser || revision != _revision) return;
      final logoData = await rootBundle.load('assets/branding/tuktuk_logo_transparent.png');
      final logo = logoData.buffer.asUint8List(logoData.offsetInBytes, logoData.lengthInBytes);
      final square = await renderMarketplaceDriverPromoCard(name: name, code: code, modality: modality, story: false, photoBytes: photo, logoBytes: logo);
      final story = await renderMarketplaceDriverPromoCard(name: name, code: code, modality: modality, story: true, photoBytes: photo, logoBytes: logo);
      if (!mounted || !_sameUser || revision != _revision) return;
      setState(() { _name.text = name; _code = code; _squareBytes = square; _storyBytes = story; });
    } catch (_) {
      if (mounted && revision == _revision) setState(() {
        _error = 'Mi TukTuk todavía no está disponible o no se pudo cargar tu tarjeta. Reintenta.';
      });
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
      if (mounted && revision == _revision) setState(() {
        _busy = false; _error = 'No se pudo guardar el perfil. Comprueba tu conexión o disponibilidad.';
      });
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
          const Text('Tu conductor de confianza. Toda una flota a tu disposición.', style: TextStyle(color: kMuted)),
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
            if (ready && copy != null) ...[
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
