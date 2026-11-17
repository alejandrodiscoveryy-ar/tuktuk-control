part of '../main.dart';

// Local, reusable illustrations extracted from the approved campaign artwork.
// Only vehicle pixels: no reference driver's portrait, name, badge or QR.
const _promoModalityArtwork = <String, String>{
  'tricycle': 'assets/branding/impulsa/tricycle.webp',
  'light_car': 'assets/branding/impulsa/light_car.webp',
  'motorcycle': 'assets/branding/impulsa/motorcycle.webp',
  'comfort': 'assets/branding/impulsa/comfort.webp',
  'bicitaxi': 'assets/branding/impulsa/bicitaxi.webp',
};

/// Same URL for the copy, PNG QR and customer entry. Never use a driver UUID.
String? marketplaceDriverPromoAlias(Object? value) =>
    value is String && RegExp(r'^[a-z0-9][a-z0-9-]{1,31}$').hasMatch(value) && !value.endsWith('-') ? value : null;

Uri marketplaceDriverPromoUri(String code, {String? alias}) {
  if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(code)) {
    throw ArgumentError('Invalid promotion code');
  }
  final shortAlias = marketplaceDriverPromoAlias(alias);
  return shortAlias == null
      ? Uri.https('www.vrixora.com', '/cliente/tuk/', {'conductor': code})
      : Uri.https('www.vrixora.com', '/tuk/$shortAlias');
}

/// The printed address and QR always describe exactly the same destination.
String marketplaceDriverPromoDisplayLink(String code, {String? alias}) =>
    marketplaceDriverPromoUri(code, alias: alias).toString().replaceFirst('https://www.', '');

String marketplaceDriverPromoCopy(String name, String code, {bool identityVerified = false, String? alias}) =>
    '¡Tu próximo viaje comienza conmigo!\n\n'
    'Soy $name, ${identityVerified ? 'conductor verificado' : 'conductor'} de la Agencia TukTuk.\n\n'
    'Solicita mi servicio desde este enlace:\n\n'
    '${marketplaceDriverPromoUri(code, alias: alias)}\n\n'
    'Agencia TukTuk. Tu conductor de confianza, a un toque.';

String _promoCategoryLabel(String code) => switch (code) {
  'motorcycle' => 'Moto', 'bicitaxi' => 'Bicitaxi', 'tricycle' => 'Triciclo',
  'light_car' => 'Auto', 'comfort' || 'confort' => 'Confort', 'van' => 'Furgoneta', 'truck' => 'Camión',
  'bicycle' => 'Bicicleta', _ => 'Transporte',
};
String _promoServiceLabel(String code) => switch (code) {
  'passenger' => 'Pasajeros', 'courier' => 'Mensajería', 'cargo' => 'Carga',
  _ => '',
};

/// Fixed-size integer QR modules, black on white, four-module quiet zone.
QrImage marketplaceDriverPromoQr(String code, {String? alias}) {
  final qr = QrCode(6, QrErrorCorrectLevel.M)
    ..addData(marketplaceDriverPromoUri(code, alias: alias).toString());
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
    FontWeight weight = FontWeight.w700, int lines = 2,
    double? minFontSize, double? boxHeight, List<Shadow>? shadows}) {
  final painter = TextPainter(
    textDirection: ui.TextDirection.ltr,
    textAlign: center ? TextAlign.center : TextAlign.left,
    maxLines: lines, ellipsis: '…',
  );
  var size = fontSize;
  while (true) {
    painter.text = TextSpan(text: value, style: TextStyle(
      color: color, shadows: shadows, fontFamily: 'ImpulsaMontserrat',
      fontSize: size, fontWeight: weight, height: 1.10));
    painter.layout(minWidth: width, maxWidth: width);
    if (!painter.didExceedMaxLines || minFontSize == null || size <= minFontSize) {
      break;
    }
    size = max(minFontSize, size - 2);
  }
  final top = boxHeight == null ? y : y + max(0.0, (boxHeight - painter.height) / 2);
  painter.paint(canvas, Offset(x, top));
  painter.dispose();
}

/// The badge is part of the exported PNG, not merely the app preview.
double _promoVerifiedName(Canvas canvas, String name, Rect area, {
  required double fontSize, required double minFontSize, required bool center,
  required bool identityVerified,
}) {
  final badgeSize = identityVerified ? (area.width < 400 ? 60.0 : 76.0) : 0.0;
  final gap = identityVerified ? 12.0 : 0.0;
  final painter = TextPainter(textDirection: ui.TextDirection.ltr,
    textAlign: center ? TextAlign.center : TextAlign.left,
    );
  var size = fontSize;
  final available = area.width - badgeSize - gap;
  while (true) {
    painter.text = TextSpan(text: name, style: TextStyle(
      color: Colors.white, fontFamily: 'ImpulsaMontserrat', fontSize: size, fontWeight: FontWeight.w800,
      height: 1.06, letterSpacing: -1.3));
    painter.layout(maxWidth: available);
    if (painter.height <= area.height || size <= 12) break;
    // Fit even unusually long legal names without truncating them.
    size = max(12.0, size - (size > minFontSize ? 2 : 1));
  }
  final total = painter.width + gap + badgeSize;
  final x = center ? area.left + (area.width - total) / 2 : area.left;
  painter.paint(canvas, Offset(x, area.top));
  if (identityVerified) {
    // Use the actual last line, not the paragraph's widest line: the blue
    // seal must touch the name visually even when a full name wraps.
    final line = painter.computeLineMetrics().last;
    final sealSize = min(badgeSize, size * .91);
    final origin = Offset(x + line.left + line.width + gap,
      area.top + line.baseline - line.ascent / 2 - sealSize / 2 + 2);
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(sealSize / 32);
    final badge = ui.Path();
    for (var i = 0; i < 32; i++) {
      final angle = i * pi / 16 - pi / 2;
      final radius = i.isEven ? 15.0 : 13.4;
      final px = 16 + cos(angle) * radius;
      final py = 16 + sin(angle) * radius;
      if (i == 0) {
        badge.moveTo(px, py);
      } else {
        badge.lineTo(px, py);
      }
    }
    badge.close();
    canvas.drawPath(badge, Paint()..color = const Color(0xFF00C8FF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6));
    canvas.drawPath(badge, Paint()..color = const Color(0xFF1D9BF0));
    final check = ui.Path()..moveTo(9, 16)..lineTo(14, 21)..lineTo(23, 11);
    canvas.drawPath(check, Paint()..color = Colors.white
      ..style = PaintingStyle.stroke..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    canvas.restore();
  }
  final bottom = area.top + painter.height;
  painter.dispose();
  return bottom;
}

void _promoFitImage(Canvas canvas, ui.Image image, Rect rect, {bool cover = false, Alignment alignment = Alignment.center}) {
  final size = Size(image.width.toDouble(), image.height.toDouble());
  final fitted = applyBoxFit(cover ? BoxFit.cover : BoxFit.contain, size, rect.size);
  final source = Alignment.center.inscribe(fitted.source, Offset.zero & size);
  final dest = alignment.inscribe(fitted.destination, rect);
  canvas.drawImageRect(image, source, dest, Paint()..filterQuality = FilterQuality.high);
}

/// Vehicle-class illustration, drawn locally as a subdued luminous watermark.
/// No stock-photo download, no claim about the exact vehicle model.
void _promoVehicleWatermark(Canvas canvas, String category, Rect area, Color accent) {
  canvas.save();
  canvas.translate(area.left, area.top);
  canvas.scale(area.width / 600, area.height / 220);
  final stroke = Paint()..color = accent.withValues(alpha: .75)
    ..style = PaintingStyle.stroke..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
  final detail = Paint()..color = accent.withValues(alpha: .48)
    ..style = PaintingStyle.stroke..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
  final fill = Paint()..shader = const LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [Color(0xFF168DB4), Color(0xFF12465F), Color(0xFF061624)],
    stops: [0, .36, 1],
  ).createShader(const Rect.fromLTWH(0, 0, 600, 220));
  final glow = Paint()..shader = RadialGradient(colors: [
    accent.withValues(alpha: .30), accent.withValues(alpha: 0),
  ]).createShader(const Rect.fromLTWH(0, 0, 600, 220));
  canvas.drawRect(const Rect.fromLTWH(0, 0, 600, 220), glow);
  void wheel(double x, double y, double radius) {
    final center = Offset(x, y);
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF030C15));
    canvas.drawCircle(center, radius * .78, Paint()..shader = const RadialGradient(colors: [
      Color(0xFF9AC4D1), Color(0xFF173849), Color(0xFF07131D),
    ]).createShader(Rect.fromCircle(center: center, radius: radius * .78)));
    for (var i = 0; i < 10; i++) {
      final a = i * pi / 5;
      canvas.drawLine(center + Offset(cos(a), sin(a)) * radius * .18,
        center + Offset(cos(a), sin(a)) * radius * .65, detail);
    }
    canvas.drawCircle(center, radius, stroke);
    canvas.drawCircle(center, radius * .53, detail);
    canvas.drawCircle(center, radius * .13, Paint()..color = accent.withValues(alpha: .32));
  }
  void body(ui.Path path) {
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
    canvas.save();
    canvas.clipPath(path);
    final b = path.getBounds();
    canvas.drawRect(b, Paint()..shader = LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Colors.white.withValues(alpha: .42), Colors.transparent, accent.withValues(alpha: .22)],
      stops: const [0, .42, 1],
    ).createShader(b));
    canvas.restore();
  }
  void line(double x1, double y1, double x2, double y2) {
    canvas.drawLine(Offset(x1, y1), Offset(x2, y2), detail);
  }
  final isCycle = category == 'motorcycle' || category == 'bicycle' ||
      category == 'bicitaxi' || category == 'tricycle';
  if (isCycle) {
    final pedal = category == 'bicycle' || category == 'bicitaxi';
    final three = category == 'bicitaxi' || category == 'tricycle';
    wheel(135, 157, 47);
    wheel(460, 157, 47);
    if (three) {
      wheel(368, 172, 32);
      body(ui.Path()..moveTo(223, 58)..lineTo(387, 58)
        ..quadraticBezierTo(421, 58, 437, 92)..lineTo(450, 126)
        ..lineTo(245, 126)..lineTo(223, 58)..close());
      line(250, 60, 250, 123);
      line(382, 60, 382, 123);
      line(223, 58, 205, 37);
      line(205, 37, 408, 37);
    }
    final frame = ui.Path()..moveTo(135, 157)..lineTo(260, 75)
      ..lineTo(303, 157)..lineTo(135, 157)..moveTo(303, 157)
      ..lineTo(405, 72)..lineTo(260, 75)..moveTo(405, 72)
      ..lineTo(460, 157)..moveTo(405, 72)..lineTo(389, 44)
      ..lineTo(428, 40);
    canvas.drawPath(frame, stroke);
    canvas.drawRRect(RRect.fromRectAndRadius(
      const Rect.fromLTWH(225, 64, 76, 12), const Radius.circular(6)), fill);
    if (pedal) {
      canvas.drawCircle(const Offset(303, 157), 15, detail);
      line(303, 157, 323, 179);
    } else {
      body(ui.Path()..moveTo(276, 87)..quadraticBezierTo(350, 64, 388, 91)
        ..lineTo(362, 132)..lineTo(290, 131)..close());
      canvas.drawRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(289, 130, 63, 31), const Radius.circular(9)), fill);
      line(196, 153, 326, 170);
    }
  } else {
    final van = category == 'van';
    final truck = category == 'truck';
    if (truck) {
      body(ui.Path()..moveTo(37, 153)..lineTo(37, 49)..lineTo(365, 49)
        ..lineTo(365, 83)..lineTo(473, 83)..lineTo(539, 137)
        ..lineTo(563, 153)..lineTo(563, 178)..lineTo(37, 178)..close());
      line(366, 87, 366, 172);
      line(393, 94, 466, 94);
      line(466, 94, 511, 131);
      line(511, 131, 393, 131);
      line(393, 131, 393, 94);
    } else {
      body(ui.Path()..moveTo(33, 150)
        ..quadraticBezierTo(54, 125, 125, 116)
        ..lineTo(van ? 181 : 239, van ? 54 : 69)
        ..quadraticBezierTo(280, van ? 42 : 36, 405, van ? 46 : 65)
        ..lineTo(van ? 474 : 482, van ? 109 : 112)
        ..quadraticBezierTo(545, 118, 561, 148)
        ..lineTo(565, 171)..lineTo(36, 171)..close());
      final glass = ui.Path()..moveTo(van ? 192 : 248, 77)
        ..quadraticBezierTo(309, van ? 55 : 49, 399, 76)
        ..lineTo(455, 111)..lineTo(180, 111)..close();
      canvas.drawPath(glass, fill);
      canvas.drawPath(glass, detail);
      line(319, 64, 330, 111);
      line(330, 115, 330, 163);
      line(180, 116, 201, 163);
      line(440, 117, 464, 160);
      line(48, 147, 114, 136);
      line(484, 137, 543, 147);
      canvas.drawLine(const Offset(48, 147), const Offset(114, 136),
        Paint()..color = accent.withValues(alpha: .70)..strokeWidth = 4..strokeCap = StrokeCap.round);
    }
    wheel(146, 172, 40);
    wheel(463, 172, 40);
  }
  canvas.drawOval(const Rect.fromLTWH(35, 195, 530, 20), Paint()
    ..color = accent.withValues(alpha: .26)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
  canvas.drawLine(const Offset(25, 213), const Offset(575, 213), detail);
  canvas.restore();
}

/// Reference-derived, full-resolution campaign masters. Static typography,
/// official campaign lockup, luminous frames, CTA, iconography and footer are
/// preserved as authored artwork. All driver data and the QR are painted anew.
const _promoMasterCategories = {'tricycle', 'light_car', 'motorcycle', 'comfort', 'bicitaxi'};

String marketplacePromoMasterAsset(String category, {required bool story}) {
  final normalized = category == 'confort' ? 'comfort' : category;
  final selected = _promoMasterCategories.contains(normalized) ? normalized : 'light_car';
  return 'assets/branding/impulsa/master_${selected}_${story ? 'story' : 'square'}.webp';
}

Future<ui.Image> _promoLoadMaster(String category, bool story) async {
  final asset = await rootBundle.load(marketplacePromoMasterAsset(category, story: story));
  return _promoDecode(asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes));
}

/// Renders the real exported PNG, shared by Mi TukTuk and the Admin viewer.
/// No original reference portrait, sample name, alias or illustrative QR is
/// included in the master assets. No generated files are uploaded.
Future<Uint8List> renderMarketplaceDriverPromoCard({
  required String name, required String code, required String modality,
  required bool story, Uint8List? photoBytes, Uint8List? logoBytes, String? alias,
  ProjectIdentity identity = ProjectIdentity.fallback,
  bool identityVerified = false,
  String vehicleCategory = 'light_car',
}) async {
  const width = 1080;
  final height = story ? 1920 : 1080;
  ui.Image? portrait, logo, master;
  try {
    if (photoBytes != null) portrait = await _promoDecode(photoBytes);
    if (logoBytes != null) logo = await _promoDecode(logoBytes);
    final artworkCategory = vehicleCategory == 'confort' ? 'comfort' : vehicleCategory;
    master = await _promoLoadMaster(artworkCategory, story);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final bounds = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    const white = Colors.white;
    const muted = Color(0xFFB7DDE8);
    final accent = _promoBrandColor(identity.primaryColorHex, const Color(0xFF06B6D4));
    final modalityAccent = switch (artworkCategory) {
      'tricycle' => const Color(0xFFFF8800),
      'light_car' => const Color(0xFF00CFFF),
      'motorcycle' => const Color(0xFF43FF57),
      'bicitaxi' => const Color(0xFFD56AFF),
      'comfort' => const Color(0xFFFFD326),
      _ => accent,
    };
    canvas.drawImageRect(master,
      Rect.fromLTWH(0, 0, master.width.toDouble(), master.height.toDouble()),
      bounds, Paint()..filterQuality = FilterQuality.high);

    // The centrally configured official icon is the ONLY dynamic brand asset.
    // The approved wordmark, speed streaks and Impulsa lockup are in the master.
    if (logo != null) {
      final logoArea = story ? const Rect.fromLTWH(94, 79, 132, 119)
        : const Rect.fromLTWH(93, 28, 132, 112);
      _promoFitImage(canvas, logo, logoArea);
    }

    // Triciclo retains the exact high-resolution illustrated vehicle and
    // illuminated platform from the approved reference. Other categories
    // use the corresponding existing transparent artwork over their own
    // color-matched reference-derived stage, never an incorrect vehicle.
    if (artworkCategory != 'tricycle') {
      final vehicleArea = story
        ? const Rect.fromLTWH(394, 552, 615, 435)
        : const Rect.fromLTWH(693, 164, 362, 286);
      final stage = story
        ? const Rect.fromLTWH(274, 949, 722, 65)
        : const Rect.fromLTWH(531, 422, 532, 49);
      canvas.drawOval(stage.inflate(8), Paint()
        ..color = modalityAccent.withValues(alpha: .29)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
      canvas.drawOval(stage, Paint()..shader = const RadialGradient(
        colors: [Color(0xFF031321), Color(0xFF073850), Color(0xFF051B30)],
      ).createShader(stage));
      canvas.drawOval(stage, Paint()..style = PaintingStyle.stroke..strokeWidth = 8
        ..color = modalityAccent.withValues(alpha: .72)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawOval(stage.deflate(2), Paint()..style = PaintingStyle.stroke
        ..strokeWidth = 4..shader = LinearGradient(
          colors: [modalityAccent, white, modalityAccent, white]).createShader(stage));
      final artwork = _promoModalityArtwork[artworkCategory];
      if (artwork != null) {
        final asset = await rootBundle.load(artwork);
        final vehicle = await _promoDecode(asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes));
        try {
          // Ground the wheels and add a short, fading reflection on the
          // illuminated platform rather than floating the vehicle at center.
          final reflection = Rect.fromLTWH(vehicleArea.left, vehicleArea.bottom,
            vehicleArea.width, story ? 32 : 24);
          canvas.saveLayer(reflection, Paint());
          canvas.clipRect(reflection);
          canvas.translate(0, vehicleArea.bottom * 2);
          canvas.scale(1, -1);
          _promoFitImage(canvas, vehicle, vehicleArea, alignment: Alignment.bottomCenter);
          canvas.scale(1, -1);
          canvas.translate(0, -vehicleArea.bottom * 2);
          canvas.drawRect(reflection, Paint()..blendMode = BlendMode.dstIn
            ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0x507FFFFF), Colors.transparent]).createShader(reflection));
          canvas.restore();
          _promoFitImage(canvas, vehicle, vehicleArea, alignment: Alignment.bottomCenter);
        } finally {
          vehicle.dispose();
        }
      } else {
        _promoVehicleWatermark(canvas, vehicleCategory, vehicleArea, accent);
      }
    }

    // The master has a clean, empty portrait well; only a currently
    // authorized driver photo can fill it. The original rim stays visible.
    final photoRect = story
      ? Rect.fromCircle(center: const Offset(258, 477), radius: 210)
      : Rect.fromCircle(center: const Offset(201, 315), radius: 146);
    canvas.save();
    canvas.clipPath(ui.Path()..addOval(photoRect));
    canvas.drawRect(photoRect, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF153A50), Color(0xFF061B2C)],
    ).createShader(photoRect));
    if (portrait != null) {
      _promoFitImage(canvas, portrait, photoRect, cover: true);
    } else {
      canvas.drawCircle(Offset(photoRect.center.dx, photoRect.top + photoRect.height * .36),
        photoRect.width * .17, Paint()..color = muted);
      canvas.drawOval(Rect.fromCenter(center: Offset(photoRect.center.dx, photoRect.bottom - photoRect.height * .1),
        width: photoRect.width * .76, height: photoRect.height * .55), Paint()..color = muted);
    }
    canvas.restore();

    final nameArea = story ? const Rect.fromLTWH(490, 302, 511, 121)
      : const Rect.fromLTWH(363, 236, 333, 94);
    final nameBottom = _promoVerifiedName(canvas, name, nameArea,
      fontSize: story ? 94 : 77, minFontSize: 23, center: false,
      identityVerified: identityVerified);
    _promoText(canvas, identityVerified ? 'Conductor verificado de la Agencia TukTuk'
      : 'Conductor de la Agencia TukTuk', nameArea.left, nameBottom + 6,
      nameArea.width, story ? 33 : 25, white, lines: 2, minFontSize: 18,
      weight: FontWeight.w700,
      shadows: const [Shadow(color: Color(0xBB000916), offset: Offset(1, 2), blurRadius: 3)]);

    // Service icon is part of the original Triciclo master. The other
    // modality masters reserve a clean icon well for the correct glyph.
    if (artworkCategory != 'tricycle') {
      final serviceIconArea = story ? const Rect.fromLTWH(82, 1055, 150, 80)
        : const Rect.fromLTWH(128, 484, 112, 60);
      final modalityIcon = switch (vehicleCategory) {
        'motorcycle' => Icons.two_wheeler,
        'bicycle' || 'bicitaxi' => Icons.pedal_bike,
        'van' => Icons.airport_shuttle,
        'truck' => Icons.local_shipping,
        'comfort' || 'confort' => Icons.diamond_outlined,
        _ => Icons.directions_car,
      };
      final vehicleGlyph = TextPainter(
        text: TextSpan(text: String.fromCharCode(modalityIcon.codePoint),
          style: TextStyle(fontFamily: modalityIcon.fontFamily,
            package: modalityIcon.fontPackage, color: white,
            fontSize: serviceIconArea.height * .85)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      vehicleGlyph.paint(canvas, Offset(serviceIconArea.center.dx - vehicleGlyph.width / 2,
        serviceIconArea.center.dy - vehicleGlyph.height / 2));
      vehicleGlyph.dispose();
    }
    final serviceArea = story ? const Rect.fromLTWH(274, 1051, 742, 85)
      : const Rect.fromLTWH(295, 480, 665, 69);
    _promoText(canvas, modality, serviceArea.left, serviceArea.top, serviceArea.width,
      story ? 36 : 32, white, center: true, lines: 2, minFontSize: 19,
      boxHeight: serviceArea.height, weight: FontWeight.w800,
      shadows: const [Shadow(color: Color(0xCC201000), offset: Offset(1, 2), blurRadius: 3)]);

    // The source QR was removed from EVERY master. Repaint the actual code
    // at integer-pixel coordinates with four full white modules on each side.
    final qr = marketplaceDriverPromoQr(code, alias: alias);
    final module = story ? 6.0 : 5.0;
    final qrSize = (qr.moduleCount + 8) * module;
    final qrX = story ? 694.0 : 701.0;
    final qrY = story ? 1197.0 : 601.0;
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

    // The fixed original chain icon, hand, glossy strip and CTA frame are
    // kept intact. The printed alias and real QR use the identical URI.
    final link = marketplaceDriverPromoDisplayLink(code, alias: alias);
    final linkArea = story ? const Rect.fromLTWH(232, 1516, 680, 94)
      : const Rect.fromLTWH(269, 861, 608, 78);
    _promoText(canvas, link, linkArea.left, linkArea.top, linkArea.width,
      story ? 51 : 45, white, center: true, lines: 1, minFontSize: 14,
      weight: FontWeight.w800, boxHeight: linkArea.height,
      shadows: const [Shadow(color: Color(0xCC251000), offset: Offset(1, 3), blurRadius: 3)]);

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
    master?.dispose();
  }
}

/// A single local entry per account, versioned by artwork and public metadata.
/// Signed photo query parameters expire and must never invalidate or be stored.
const _marketplacePromoArtworkVersion = 19;
String marketplacePromoCacheFingerprint({
  required String actor, required String code, required String name,
  required String modality, required bool photoAuthorized,
  required Uri? photoUrl, required ProjectIdentity identity,
  Object? profileUpdatedAt,
  String? photoAssetId, String? alias,
  bool identityVerified = false,
  String vehicleCategory = 'light_car',
}) => sha256.convert(utf8.encode(jsonEncode([
  _marketplacePromoArtworkVersion, actor, code, alias, name, modality, photoAuthorized, identityVerified, vehicleCategory,
  photoUrl == null ? null : '${photoUrl.scheme}://${photoUrl.host}${photoUrl.path}',
  profileUpdatedAt?.toString(), photoAssetId, identity.projectId, identity.iconUrl,
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

/// Read-only commercial figures. Never infer an earned balance from the
/// promotional card or calculate a credit on the client.
class MarketplaceImpulsaEarnings {
  const MarketplaceImpulsaEarnings({
    required this.generated, required this.ownTrips, required this.ownSavings,
    required this.creditedTrips, required this.credited, required this.pending,
    required this.fundingRequired, required this.reversalPending, required this.recent,
  });
  final int generated, ownTrips, creditedTrips;
  final num ownSavings, credited, pending, fundingRequired, reversalPending;
  final List<Map<String, dynamic>> recent;
  factory MarketplaceImpulsaEarnings.fromMap(Map<String, dynamic> data) {
    num number(String key) {
      final value = data[key];
      final parsed = value is num ? value : num.tryParse(value?.toString() ?? '');
      if (parsed == null || !parsed.isFinite || parsed < 0) {
        throw const FormatException('INVALID_IMPULSA_SUMMARY');
      }
      return parsed;
    }
    final rows = data['recent'];
    if (rows is! List) throw const FormatException('INVALID_IMPULSA_HISTORY');
    return MarketplaceImpulsaEarnings(
      generated: number('generated_jobs').toInt(), ownTrips: number('own_paid_jobs').toInt(),
      ownSavings: number('own_savings_cup'), creditedTrips: number('fleet_credited_jobs').toInt(),
      credited: number('credited_cup'), pending: number('pending_cup'),
      fundingRequired: number('funding_required_cup'), reversalPending: number('reversal_pending_cup'),
      recent: rows.whereType<Map>().take(20).map((row) => Map<String,dynamic>.from(row)).toList(growable: false),
    );
  }
}

class _MarketplaceImpulsaEarningsCard extends StatelessWidget {
  const _MarketplaceImpulsaEarningsCard({required this.earnings, required this.refresh, required this.loading});
  final MarketplaceImpulsaEarnings earnings;
  final VoidCallback refresh;
  final bool loading;
  String _cup(num value) => '${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)} CUP';
  String _label(Object? state) => switch(state) {
    'pending' => 'Por acreditar', 'funding_required' => 'Pendiente de financiación',
    'credited' => 'Acreditada', 'cancelled' => 'Cancelada',
    'reversal_pending' => 'Ajuste pendiente', 'reversed' => 'Revertida',
    _ => 'Estado no disponible',
  };
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = appMutedColor(context);
    final d = earnings;
    Widget metric(String label, String value) => Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: theme.dividerColor), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ]),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.trending_up, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Expanded(child: Text('Mis ganancias Impulsa', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            IconButton(tooltip: 'Actualizar ganancias', onPressed: loading ? null : refresh, icon: const Icon(Icons.refresh)),
          ]),
          if (loading) const LinearProgressIndicator(),
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ganancias comerciales acreditadas', style: TextStyle(color: muted, fontSize: 12)),
              const SizedBox(height: 5),
              Text(_cup(d.credited), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
              Text('Histórico de créditos netos, no saldo disponible.', style: TextStyle(color: muted, fontSize: 11)),
            ])),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: metric('Solicitudes generadas', '${d.generated}')),
            const SizedBox(width: 8),
            Expanded(child: metric('Viajes propios liquidados', '${d.ownTrips}')),
          ]),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: metric('Ahorro en comisión', _cup(d.ownSavings))),
            const SizedBox(width: 8),
            Expanded(child: metric('Viajes de la flota acreditados', '${d.creditedTrips}')),
          ]),
          const SizedBox(height: 8),
          Text('Por acreditar: ${_cup(d.pending)}', style: TextStyle(color: muted, fontSize: 12)),
          if (d.fundingRequired > 0) Text('Pendientes de financiación: ${_cup(d.fundingRequired)}', style: TextStyle(color: muted, fontSize: 12)),
          if (d.reversalPending > 0) Text('Ajustes pendientes: ${_cup(d.reversalPending)}', style: TextStyle(color: muted, fontSize: 12)),
          if (d.recent.isNotEmpty) ExpansionTile(
            tilePadding: EdgeInsets.zero, childrenPadding: EdgeInsets.zero,
            title: const Text('Historial comercial'),
            children: d.recent.map((row) {
              final id = row['job_id']?.toString() ?? '';
              final value = num.tryParse(row['amount']?.toString() ?? '') ?? 0;
              final rate = num.tryParse(row['commercial_rate']?.toString() ?? '');
              final date = DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal();
              return ListTile(contentPadding: EdgeInsets.zero, dense: true,
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(_label(row['state'])),
                subtitle: Text([
                  if (id.isNotEmpty) 'Viaje ${id.substring(0, min(8,id.length))}',
                  if (rate != null) '${(rate*100).toStringAsFixed(2)}%',
                  if (date != null) '${date.day}/${date.month}/${date.year}',
                ].join(' · ')),
                trailing: Text(_cup(value), style: const TextStyle(fontWeight: FontWeight.w700)),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          Text('La comisión comercial se acredita tras liquidar viajes reales realizados por otro conductor. En tus viajes propios el beneficio es la comisión reducida.', style: TextStyle(fontSize: 12, color: muted)),
        ],
      )),
    );
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
  final _campaign = TextEditingController();
  final _cache = MarketplacePromoArtworkCache(Hive.box(_metaBox));
  late final String? _actor;
  StreamSubscription<AuthState>? _auth;
  bool _busy = true, _enabled = false;
  bool _sharing = false, _identityVerified = false;
  String _shareChannel = 'unknown';
  String? _error, _code, _photoAssetId, _alias;
  Uint8List? _squareBytes, _storyBytes, _printBytes;
  int _revision = 0;
  int _earningsRevision = 0;
  MarketplaceImpulsaEarnings? _earnings;
  bool _earningsBusy = false, _earningsUnavailable = false;
  bool get _sameUser => _actor != null && _client.auth.currentUser?.id == _actor;
  Uint8List? _artworkFor(bool story) => story ? _storyBytes : _squareBytes;
  String _fileNameFor(bool story) => story ? 'Mi-TukTuk-historia.png' : 'Mi-TukTuk.png';
  String? get _activeCampaign {
    final value = _campaign.text.trim().toLowerCase();
    return RegExp(r'^[a-z0-9_-]{1,32}$').hasMatch(value) ? value : null;
  }
  String? get _taggedLink {
    if (_code == null) return null;
    final base = marketplaceDriverPromoUri(_code!, alias: _alias);
    if (_shareChannel == 'unknown' && _activeCampaign == null) return base.toString();
    return base.replace(queryParameters: {
      ...base.queryParameters,
      if (_shareChannel != 'unknown') 'utm_source': _shareChannel,
      if (_activeCampaign != null) 'utm_campaign': _activeCampaign!,
    }).toString();
  }
  String? get _copy {
    if (_code == null) return null;
    final normal = marketplaceDriverPromoUri(_code!, alias: _alias).toString();
    return marketplaceDriverPromoCopy(_name.text.trim(), _code!,
      identityVerified: _identityVerified, alias: _alias).replaceFirst(normal, _taggedLink ?? normal);
  }
  Future<void> _recordCommunication(String action) async {
    if (!_sameUser || !_enabled) return;
    try {
      await _client.rpc('record_my_marketplace_impulsa_share_action_v1',
        params: {'target_action': action, 'target_channel': _shareChannel,
          'target_campaign': _activeCampaign})
        .timeout(const Duration(seconds: 4));
    } catch (_) {
      // The share UI must keep working during network outages.
    }
  }

  @override
  void initState() {
    super.initState();
    _actor = _client.auth.currentUser?.id;
    _name.text = widget.store.profileDisplayName;
    _auth = _client.auth.onAuthStateChange.listen((_) {
      if (!_sameUser && mounted) {
        _revision++; _earningsRevision++;
        if (_actor != null) unawaited(_cache.clear(_actor));
        setState(() {
          _enabled = false; _busy = false; _code = null; _identityVerified = false;
          _photoAssetId = null; _earnings = null; _earningsBusy = false; _earningsUnavailable = false;
          _squareBytes = null; _storyBytes = null; _printBytes = null;
          _error = 'Inicia sesión nuevamente para abrir Mi TukTuk.';
        });
      }
    });
    unawaited(_load());
    unawaited(_loadEarnings());
  }

  @override
  void dispose() {
    _revision++; _earningsRevision++;
    _auth?.cancel();
    _name.dispose();
    _campaign.dispose();
    super.dispose();
  }

  Future<void> _loadEarnings() async {
    if (!_sameUser || !mounted) return;
    final revision = ++_earningsRevision;
    setState(() { _earningsBusy = true; _earningsUnavailable = false; });
    try {
      final raw = await _client.rpc('get_my_marketplace_impulsa_summary_v1').timeout(const Duration(seconds: 12));
      if (!mounted || !_sameUser || revision != _earningsRevision) return;
      if (raw is! Map) throw const FormatException('INVALID_IMPULSA_SUMMARY');
      final data = MarketplaceImpulsaEarnings.fromMap(Map<String,dynamic>.from(raw));
      setState(() { _earnings = data; });
    } catch (_) {
      if (mounted && _sameUser && revision == _earningsRevision) {
        setState(() { _earningsUnavailable = true; });
      }
    } finally {
      if (mounted && _sameUser && revision == _earningsRevision) setState(() { _earningsBusy = false; });
    }
  }

  Future<void> _load({bool force = false}) async {
    final revision = ++_revision;
    final actor = _actor;
    if (actor == null || !_sameUser) {
      setState(() { _busy = false; _error = 'Inicia sesión para crear tu tarjeta.'; });
      return;
    }
    setState(() { _busy = true; _error = null; _squareBytes = null; _storyBytes = null; _printBytes = null; _code = null; });
    var stage = 'perfil';
    try {
      final result = await _client.rpc('prepare_my_marketplace_promo_card_v1');
      if (!mounted || !_sameUser || revision != _revision) return;
      if (result is! Map) throw StateError('PROMO_PROFILE_INVALID');
      final enabled = result['enabled'] == true;
      final identityVerified = enabled && result['identity_verified'] == true;
      setState(() {
        _enabled = enabled;
        _identityVerified = identityVerified;
        _photoAssetId = result['photo_asset_id'] is String ? result['photo_asset_id'] as String : null;
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
      final alias = identityVerified ? marketplaceDriverPromoAlias(await _client.rpc('my_marketplace_promo_alias_v1').timeout(const Duration(seconds: 8))) : null;
      if (!mounted || !_sameUser || revision != _revision) return;
      if (identityVerified && alias == null) throw StateError('PROMO_ALIAS_UNAVAILABLE');
      // The administrator has already activated this profile and personal QR.
      // The authenticated driver only retrieves the approved metadata.
      final raw = result;
      if (raw['public_name'] is! String || raw['category_code'] is! String ||
          raw['service_codes'] is! List) {
        throw StateError('PROMO_PROFILE_UNAVAILABLE');
      }
      final services = (raw['service_codes'] as List).whereType<String>()
        .map(_promoServiceLabel).where((label) => label.isNotEmpty).toSet().join(' · ');
      if (services.isEmpty) throw StateError('PROMO_SERVICE_UNAVAILABLE');
      final name = raw['public_name'] as String;
      final vehicleCategory = raw['category_code'] as String;
      final modality = '${_promoCategoryLabel(vehicleCategory)} · $services';
      final photoPath = raw['photo_path'] is String ? raw['photo_path'] as String : null;
      final photoAuthorized = raw['photo_authorized'] == true;
      // The own-photo storage path is stable; never store the signed token.
      final photoKey = photoAuthorized && photoPath != null
        ? Uri(scheme: 'https', host: Uri.parse(_supabaseUrl).host,
            pathSegments: ['marketplace-media', ...photoPath.split('/')])
        : null;
      if (photoAuthorized && photoKey == null) {
        stage = 'fotografía';
        throw StateError('PROMO_PHOTO_UNAVAILABLE');
      }
      stage = 'tarjeta';
      await widget.store.refreshProjectIdentity().timeout(
        const Duration(seconds: 8), onTimeout: () {});
      if (!mounted || !_sameUser || revision != _revision) return;
      final identity = widget.store.projectIdentity;
      final fingerprint = marketplacePromoCacheFingerprint(
        actor: actor, code: code, alias: alias, name: name, modality: modality,
        photoAuthorized: photoAuthorized, photoUrl: photoKey,
        identity: identity, photoAssetId: _photoAssetId,
        identityVerified: identityVerified, vehicleCategory: vehicleCategory,
      );
      final cached = force ? null : _cache.read(actor, fingerprint);
      if (cached != null) {
        final logoForPrint = await loadMarketplacePromoBrandLogo(identity);
        // The horizontal card includes the authorized real portrait even
        // when the old square/story cards are already present in the cache.
        Uint8List? photoForPrint;
        if (photoAuthorized && photoPath != null) {
          final signed = await _client.storage.from('marketplace-media')
            .createSignedUrl(photoPath, 120);
          photoForPrint = await downloadMarketplacePromoPortrait(Uri.parse(signed));
        }
        if (!mounted || !_sameUser || revision != _revision) return;
        final printCard = await renderMarketplaceDriverPrintCard(
          name: name, code: code, alias: alias, modality: modality,
          logoBytes: logoForPrint, photoBytes: photoForPrint,
          identityVerified: identityVerified);
        if (!mounted || !_sameUser || revision != _revision) return;
        setState(() {
          _name.text = name; _code = code; _alias = alias;
          _squareBytes = cached.square; _storyBytes = cached.story;
          _printBytes = printCard;
        });
        return;
      }
      stage = 'fotografía';
      Uint8List? photo;
      if (photoAuthorized && photoPath != null) {
        final signed = await _client.storage.from('marketplace-media').createSignedUrl(photoPath, 120);
        photo = await downloadMarketplacePromoPortrait(Uri.parse(signed));
      }
      if (!mounted || !_sameUser || revision != _revision) return;
      stage = 'tarjeta';
      final logo = await loadMarketplacePromoBrandLogo(identity);
      if (!mounted || !_sameUser || revision != _revision) return;
      final square = await renderMarketplaceDriverPromoCard(name: name, code: code, alias: alias, modality: modality, story: false, photoBytes: photo, logoBytes: logo, identity: identity, identityVerified: identityVerified, vehicleCategory: vehicleCategory);
      final story = await renderMarketplaceDriverPromoCard(name: name, code: code, alias: alias, modality: modality, story: true, photoBytes: photo, logoBytes: logo, identity: identity, identityVerified: identityVerified, vehicleCategory: vehicleCategory);
      final printCard = await renderMarketplaceDriverPrintCard(
        name: name, code: code, alias: alias, modality: modality,
        photoBytes: photo, logoBytes: logo,
        identityVerified: identityVerified);
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
      setState(() { _name.text = name; _code = code; _alias = alias; _squareBytes = square; _storyBytes = story; _printBytes = printCard; });
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

  Future<void> _editAlias() async {
    if (!_sameUser || !_enabled || _busy || _sharing || _alias == null) return;
    var value = _alias!;
    final selected = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Personaliza tu enlace'),
      content: TextFormField(initialValue: value, onChanged: (text) => value = text,
        maxLength: 32, decoration: const InputDecoration(prefixText: 'vrixora.com/tuk/', helperText: 'Letras sin acentos, números y guiones.')),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, value.trim().toLowerCase()), child: const Text('Guardar'))],
    ));
    if (!mounted || !_sameUser || selected == null || selected == _alias) return;
    if (marketplaceDriverPromoAlias(selected) == null) { toast(context, 'Escribe un nombre válido de 2 a 32 caracteres.'); return; }
    setState(() => _busy = true);
    try {
      await _client.rpc('my_marketplace_promo_alias_v1', params: {'target_alias': selected});
      if (mounted && _sameUser) await _load(force: true);
    } catch (_) {
      if (mounted && _sameUser) { setState(() => _busy = false); toast(context, 'No se pudo guardar. El nombre puede estar ocupado.'); }
    }
  }

  Future<void> _revoke() async {
    final actor = _actor;
    if (_busy || !_sameUser || actor == null) return;
    final revision = ++_revision;
    setState(() { _busy = true; _error = null; _code = null; _squareBytes = null; _storyBytes = null; _printBytes = null; });
    try {
      await _client.rpc('revoke_my_marketplace_promo_card_v1');
      if (!mounted || !_sameUser || revision != _revision) return;
      await _cache.clear(actor);
      await _load();
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(() {
          _busy = false; _error = 'No se pudo desactivar el enlace. Comprueba tu conexión.';
        });
      }
    }
  }

  Future<void> _shareCard({required bool story}) async {
    final bytes = _artworkFor(story), copy = _copy;
    final fileName = _fileNameFor(story);
    if (!_sameUser || !_enabled || bytes == null || copy == null || _sharing) return;
    setState(() => _sharing = true);
    unawaited(_recordCommunication('share_attempt'));
    try {
      final box = context.findRenderObject() as RenderBox?;
      final result = await SharePlus.instance.share(ShareParams(
        title: 'Mi TukTuk', text: copy,
        files: [XFile.fromData(bytes, mimeType: 'image/png', name: fileName)],
        fileNameOverrides: [fileName],
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

  Future<void> _downloadCard({required bool story}) async {
    final bytes = _artworkFor(story);
    final fileName = _fileNameFor(story);
    if (!_sameUser || !_enabled || bytes == null) return;
    if (kIsWeb && driver_promo_download.downloadPromoPng(bytes, fileName)) {
      unawaited(_recordCommunication('card_downloaded'));
      return;
    }
    try {
      unawaited(_recordCommunication('card_downloaded'));
      await SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes,
        mimeType: 'image/png', name: fileName)], fileNameOverrides: [fileName]));
    } catch (_) {
      if (mounted) toast(context, 'No se pudo descargar la tarjeta.');
    }
  }

  Future<void> _copyText(String text, {String action = 'link_copied'}) async {
    if (!_sameUser || !_enabled || _squareBytes == null || _storyBytes == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: text));
      unawaited(_recordCommunication(action));
      if (mounted) toast(context, 'Copiado');
    } catch (_) {
      if (mounted) toast(context, 'Selecciona el texto para copiarlo manualmente.');
    }
  }


  Future<void> _downloadPrintCard({required bool pdf}) async {
    final card = _printBytes;
    if (!_sameUser || !_enabled || _busy || card == null) return;
    final file = pdf ? 'Mi-TukTuk-presentacion-85x55.pdf'
      : 'Mi-TukTuk-presentacion-300dpi.png';
    try {
      final bytes = pdf ? marketplaceDriverPrintPdf(card) : card;
      final mime = pdf ? 'application/pdf' : 'image/png';
      if (kIsWeb && driver_promo_download.downloadPromoFile(bytes, file, mime)) {
        unawaited(_recordCommunication('card_downloaded'));
        return;
      }
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, mimeType: mime, name: file)],
        fileNameOverrides: [file]));
      unawaited(_recordCommunication('card_downloaded'));
    } catch (_) {
      if (mounted) toast(context, 'No se pudo descargar la tarjeta de presentación.');
    }
  }

  Widget _printableCard(BuildContext context) {
    final card = _printBytes;
    if (card == null) return const SizedBox.shrink();
    final canDownload = _sameUser && _enabled && !_busy;
    return Card(child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Tarjeta de presentación', style: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Diseño premium · 85 × 55 mm · imprimir al 100 %',
          style: TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
        AspectRatio(aspectRatio: 85 / 55,
          child: Image.memory(card, fit: BoxFit.contain,
            semanticLabel: 'Tarjeta de presentación lista para imprimir')),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
            key: const ValueKey('mi-tuktuk-print-pdf'),
            onPressed: canDownload ? () => _downloadPrintCard(pdf: true) : null,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Descargar PDF para imprimir'),
          ),
          OutlinedButton.icon(
            key: const ValueKey('mi-tuktuk-print-png'),
            onPressed: canDownload ? () => _downloadPrintCard(pdf: false) : null,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Descargar PNG'),
          ),
        ]),
      ]),
    ));
  }

  Widget _formatCard(BuildContext context, {required bool story, required bool ready}) {
    final art = _artworkFor(story);
    final label = story ? 'Historia' : 'Cuadrada';
    final muted = appMutedColor(context);
    return Container(
      key: ValueKey(story ? 'mi-tuktuk-story-card' : 'mi-tuktuk-square-card'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          Text(story ? '9:16 · Estados e historias' : '1:1 · Publicaciones',
            style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF0B1523),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: art == null
                  ? const Icon(Icons.image_outlined, color: Colors.white54, size: 36)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(art, fit: BoxFit.contain, gaplessPlayback: true,
                        semanticLabel: 'Tarjeta Mi TukTuk $label'),
                    ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: ValueKey(story ? 'mi-tuktuk-share-story' : 'mi-tuktuk-share-square'),
            onPressed: ready && !_sharing ? () => _shareCard(story: story) : null,
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Compartir', textAlign: TextAlign.center),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              minimumSize: const Size(0, 44),
            ),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            key: ValueKey(story ? 'mi-tuktuk-download-story' : 'mi-tuktuk-download-square'),
            onPressed: ready && !_sharing ? () => _downloadCard(story: story) : null,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Descargar', textAlign: TextAlign.center),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              minimumSize: const Size(0, 44),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = _copy;
    final previewReady = _sameUser && _enabled && !_busy &&
        _squareBytes != null && _storyBytes != null && copy != null;
    final ready = previewReady;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: kDanger)),
            TextButton(onPressed: _busy ? null : _load, child: const Text('Reintentar')),
          ],
          if (!_enabled && !_busy && _error == null)
            const Text('Tu ficha estará disponible cuando la Agencia TukTuk verifique tu identidad y active Mi TukTuk desde Administración.'),
          if (_sameUser && _earnings != null)
            _MarketplaceImpulsaEarningsCard(earnings: _earnings!, refresh: () => unawaited(_loadEarnings()), loading: _earningsBusy)
          else if (_sameUser && _enabled && _earningsBusy)
            const Padding(padding: EdgeInsets.only(bottom: 12), child: LinearProgressIndicator())
          else if (_sameUser && _enabled && _earningsUnavailable)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
              const Expanded(child: Text('Ganancias comerciales aún no disponibles.', style: TextStyle(fontSize: 12))),
              TextButton(onPressed: () => unawaited(_loadEarnings()), child: const Text('Consultar')),
            ])),
          if (_enabled) ...[
            Row(children: [
              const Expanded(child: Text('Mis tarjetas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              IconButton(tooltip: 'Actualizar tarjeta',
                onPressed: _busy ? null : () => _load(force: true),
                icon: const Icon(Icons.refresh)),
              PopupMenuButton<String>(
                tooltip: 'Opciones de perfil',
                enabled: !_busy && _sameUser,
                onSelected: (value) async {
                  if (value != 'revoke') return;
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('¿Desactivar perfil público?'),
                      content: const Text('Tu enlace personal dejará de estar disponible para solicitar tu servicio.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
                        TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Desactivar')),
                      ],
                    ),
                  );
                  if (confirmed == true && mounted) await _revoke();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'revoke', child: Text('Desactivar mi perfil público')),
                ],
              ),
            ]),
            const SizedBox(height: 8),
            if (previewReady) ...[
              const Text('Canal de difusión', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _shareChannel,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true, border: OutlineInputBorder(),
                  helperText: 'Sirve para identificar tu campaña; no confirma dónde se envió.',
                ),
                items: const [
                  DropdownMenuItem(value:'unknown', child: Text('Sin indicar')),
                  DropdownMenuItem(value:'whatsapp_private', child: Text('WhatsApp privado')),
                  DropdownMenuItem(value:'whatsapp_groups', child: Text('Grupos de WhatsApp')),
                  DropdownMenuItem(value:'whatsapp_status', child: Text('Estados de WhatsApp')),
                  DropdownMenuItem(value:'facebook', child: Text('Facebook')),
                  DropdownMenuItem(value:'instagram', child: Text('Instagram')),
                  DropdownMenuItem(value:'qr', child: Text('Material impreso / QR')),
                  DropdownMenuItem(value:'other', child: Text('Otro canal')),
                ],
                onChanged: (value) { if(value!=null) setState(() => _shareChannel=value); },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _campaign,
                maxLength: 32,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_-]'))],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  isDense: true, border: OutlineInputBorder(),
                  labelText: 'Campaña o grupo (opcional)',
                  hintText: 'ej: grupo-centro',
                  helperText: 'Etiqueta para comparar acciones; evita datos personales.',
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (_squareBytes != null && _storyBytes != null)
              LayoutBuilder(builder: (context, constraints) {
                final square = _formatCard(context, story: false, ready: ready);
                final story = _formatCard(context, story: true, ready: ready);
                if (constraints.maxWidth < 300) {
                  return Column(children: [
                    square, const SizedBox(height: 12), story,
                  ]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: square),
                    const SizedBox(width: 12),
                    Expanded(child: story),
                  ],
                );
              }),
            if (previewReady && _printBytes != null) ...[
              const SizedBox(height: 12),
              _printableCard(context),
            ],
            if (previewReady) ...[
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.link),
                    title: const Text('Mi enlace personal'),
                    subtitle: SelectableText((_taggedLink ?? '').replaceFirst('https://www.', '')),
                    trailing: IconButton(
                      tooltip: 'Copiar enlace',
                      onPressed: () => _copyText(_taggedLink ?? ''),
                      icon: const Icon(Icons.copy_outlined),
                    ),
                    onTap: () => _copyText(_taggedLink ?? ''),
                  ),
                  if (_alias != null) ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Personalizar mi enlace'),
                    subtitle: const Text('Al cambiarlo, descarga tus tarjetas nuevas.'),
                    onTap: _busy || _sharing ? null : _editAlias,
                  ),
                  const Divider(height: 1),
                  ExpansionTile(
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: const Text('Mensaje para compartir'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          SelectableText(copy),
                          TextButton.icon(onPressed: () => _copyText(copy, action: 'message_copied'),
                            icon: const Icon(Icons.copy), label: const Text('Copiar mensaje')),
                        ]),
                      ),
                    ],
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              Text('Compartir incluye la tarjeta, el mensaje y tu enlace.',
                style: TextStyle(color: appMutedColor(context), fontSize: 12)),
            ],
          ],
        ]),
      )),
    ]);
  }
}

 
/// Retry one transient read failure, never a revoked or missing profile.
/// The callback returns the existing gateway JSON envelope.
Future<Map<String, dynamic>?> loadMarketplaceSharedPromoProfile(
  Future<dynamic> Function() request, {Future<void> Function(Duration)? pause}) async {
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      final envelope = await request().timeout(const Duration(seconds: 22));
      if (envelope is! Map) throw StateError('PROMO_RESPONSE_INVALID');
      if (envelope['error'] != null) throw StateError(envelope['error'].toString());
      final raw = envelope['data'];
      if (raw == null) return null;
      if (raw is! Map) throw StateError('PROMO_RESPONSE_INVALID');
      return Map<String, dynamic>.from(raw);
    } catch (error) {
      final detail = error is FunctionException ? error.details : error;
      final message = detail.toString().toLowerCase();
      final retryable = error is TimeoutException ||
        (error is FunctionException && error.status >= 500) ||
        message.contains('statement timeout') ||
        message.contains('connection timeout') ||
        message.contains('failed to fetch') ||
        message.contains('networkerror');
      if (!retryable || attempt == 1) rethrow;
      await (pause ?? Future<void>.delayed)(const Duration(milliseconds: 800));
    }
  }
  throw StateError('PROMO_RESPONSE_INVALID');
}

/// Public, consented artwork only. The same renderer is used by Mi TukTuk.
class MarketplaceSharedPromoCards extends StatefulWidget {
  const MarketplaceSharedPromoCards({required this.code, super.key});
  final String code;
  @override
  State<MarketplaceSharedPromoCards> createState() => _MarketplaceSharedPromoCardsState();
}

class _MarketplaceSharedPromoCardsState extends State<MarketplaceSharedPromoCards> {
  late Future<(String, Uint8List, Uint8List, Uint8List, String)> _cards;
  @override
  void initState() {
    super.initState();
    _cards = _load();
  }

  Future<(String, Uint8List, Uint8List, Uint8List, String)> _load() async {
    final client = Supabase.instance.client;
    final raw = await loadMarketplaceSharedPromoProfile(() async {
      final response = await client.functions.invoke('marketplace-customer-gateway',
        body: {'operation': 'promo_profile', 'params': {'target_code': widget.code}});
      return response.data;
    });
    if (raw == null || raw['verified'] != true ||
        raw['public_name'] is! String || raw['category_code'] is! String ||
        raw['service_codes'] is! List) {
      throw StateError('PROMO_UNAVAILABLE');
    }
    final name = raw['public_name'] as String;
    final category = raw['category_code'] as String;
    final services = (raw['service_codes'] as List).whereType<String>()
      .map(_promoServiceLabel).where((label) => label.isNotEmpty).toSet().join(' · ');
    if (services.isEmpty) {
      throw StateError('PROMO_SERVICE_UNAVAILABLE');
    }
    final identity = ProjectIdentity.fromRpc(await client.rpc('get_public_project_identity',
      params: {'target_project_id': _projectId}));
    if (identity == null || identity.projectId != _projectId) throw StateError('BRAND_UNAVAILABLE');
    final photoUrl = raw['photo_url'];
    final photo = photoUrl is String ? await downloadMarketplacePromoPortrait(Uri.parse(photoUrl)) : null;
    final logo = await loadMarketplacePromoBrandLogo(identity);
    final modality = '${_promoCategoryLabel(category)} · $services';
    final alias = marketplaceDriverPromoAlias(raw['promo_alias']);
    if (alias == null) throw StateError('PROMO_ALIAS_UNAVAILABLE');
    final square = await renderMarketplaceDriverPromoCard(name: name, code: widget.code, alias: alias,
      modality: modality, story: false, photoBytes: photo, logoBytes: logo,
      identity: identity, identityVerified: true, vehicleCategory: category);
    final story = await renderMarketplaceDriverPromoCard(name: name, code: widget.code, alias: alias,
      modality: modality, story: true, photoBytes: photo, logoBytes: logo,
      identity: identity, identityVerified: true, vehicleCategory: category);
    final printable = await renderMarketplaceDriverPrintCard(
      name: name, code: widget.code, alias: alias, modality: modality,
      photoBytes: photo, logoBytes: logo, identityVerified: true);
    return (name, square, story, printable, alias);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF101619),
    body: SafeArea(child: FutureBuilder<(String, Uint8List, Uint8List, Uint8List, String)>(
      future: _cards,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(snapshot.error is StateError &&
            (snapshot.error as StateError).message == 'PROMO_UNAVAILABLE'
            ? 'Perfil promocional no disponible.'
            : 'No se pudieron cargar las tarjetas en este momento. Intenta nuevamente.',
            textAlign: TextAlign.center),
          TextButton(onPressed: () => setState(() => _cards = _load()), child: const Text('Reintentar')),
        ]));
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final (name, square, story, printable, alias) = snapshot.data!;
        final link = marketplaceDriverPromoUri(widget.code, alias: alias).toString();
        final message = '¡Tu próximo viaje comienza conmigo!\n\nSoy $name, conductor verificado de la Agencia TukTuk.\n\nSolicita mi servicio desde este enlace:\n$link\n\nAgencia TukTuk. Tu conductor de confianza, a un toque.';
        Widget card(Uint8List bytes, bool vertical) {
          final file = vertical ? 'tuktuk-historia.png' : 'tuktuk-cuadrada.png';
          return Column(children: [
            Text(vertical ? 'Historia' : 'Cuadrada'),
            const SizedBox(height: 8),
            GestureDetector(onTap: () => showDialog<void>(context: context, builder: (dialogContext) => Dialog(child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)))),
              child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 420), child: Image.memory(bytes, fit: BoxFit.contain))),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: () {
              if (!driver_promo_download.downloadPromoPng(bytes, file)) {
                toast(context, 'No se pudo descargar la tarjeta.');
              }
            }, icon: const Icon(Icons.download), label: const Text('Descargar')),
            TextButton.icon(onPressed: () async {
              try {
                final result = await SharePlus.instance.share(ShareParams(text: message,
                  files: [XFile.fromData(bytes, mimeType: 'image/png', name: file)],
                  fileNameOverrides: [file], downloadFallbackEnabled: false));
                if (context.mounted && result.status == ShareResultStatus.unavailable) {
                  toast(context, 'Descarga la tarjeta y copia el mensaje.');
                }
              } catch (_) {
                if (context.mounted) toast(context, 'Descarga la tarjeta y copia el mensaje.');
              }
            }, icon: const Icon(Icons.share), label: const Text('Compartir')),
          ]);
        }
        return SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(children: [
          LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return Column(children: [card(square, false), const SizedBox(height: 24), card(story, true)]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: card(square, false)), const SizedBox(width: 16), Expanded(child: card(story, true))]);
          }),
          const SizedBox(height: 18),
          const Text('Tarjeta de presentación · 85 × 55 mm',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const Text('Horizontal, con foto autorizada y QR personal listo para imprimir',
            style: TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 540),
            child: AspectRatio(aspectRatio: 85 / 55,
              child: Image.memory(printable, fit: BoxFit.contain))),
          Wrap(alignment: WrapAlignment.center, spacing: 10, children: [
            FilledButton.icon(onPressed: () {
              try {
                final pdf = marketplaceDriverPrintPdf(printable);
                if (!driver_promo_download.downloadPromoFile(pdf,
                    'tuktuk-presentacion-85x55.pdf', 'application/pdf')) {
                  toast(context, 'No se pudo descargar el PDF.');
                }
              } catch (_) { toast(context, 'No se pudo generar el PDF.'); }
            }, icon: const Icon(Icons.picture_as_pdf), label: const Text('PDF para imprimir')),
            OutlinedButton.icon(onPressed: () {
              if (!driver_promo_download.downloadPromoFile(printable,
                  'tuktuk-presentacion.png', 'image/png')) {
                toast(context, 'No se pudo descargar el PNG.');
              }
            }, icon: const Icon(Icons.download), label: const Text('PNG')),
          ]),
          const SizedBox(height: 18),
          TextButton.icon(onPressed: () => Clipboard.setData(ClipboardData(text: link)),
            icon: const Icon(Icons.link), label: const Text('Copiar enlace')),
          TextButton.icon(onPressed: () => Clipboard.setData(ClipboardData(text: message)),
            icon: const Icon(Icons.copy), label: const Text('Copiar mensaje')),
          SelectableText(link),
        ]));
      },
    )),
  );
}
