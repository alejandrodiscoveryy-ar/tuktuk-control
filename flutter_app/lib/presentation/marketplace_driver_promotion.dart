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
    double? minFontSize, double letterSpacing = 0, double? boxHeight, bool italic = false,
    ui.Shader? shader, List<Shadow>? shadows}) {
  final painter = TextPainter(
    textDirection: ui.TextDirection.ltr,
    textAlign: center ? TextAlign.center : TextAlign.left,
    maxLines: lines, ellipsis: '…',
  );
  var size = fontSize;
  while (true) {
    painter.text = TextSpan(text: value, style: TextStyle(
      color: shader == null ? color : null,
      foreground: shader == null ? null : (Paint()..shader = shader),
      shadows: shadows, fontFamily: 'Roboto', fontSize: size, fontWeight: weight, height: 1.10,
      letterSpacing: letterSpacing, fontStyle: italic ? FontStyle.italic : FontStyle.normal));
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
    maxLines: 2, ellipsis: '…');
  var size = fontSize;
  final available = area.width - badgeSize - gap;
  while (true) {
    painter.text = TextSpan(text: name, style: TextStyle(
      color: Colors.white, fontFamily: 'Roboto', fontSize: size, fontWeight: FontWeight.w900,
      height: 1.10, letterSpacing: -1.8));
    painter.layout(maxWidth: available);
    if ((!painter.didExceedMaxLines && painter.height <= area.height) || size <= minFontSize) {
      break;
    }
    size = max(minFontSize, size - 2);
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

void _promoFitImage(Canvas canvas, ui.Image image, Rect rect, {bool cover = false}) {
  final size = Size(image.width.toDouble(), image.height.toDouble());
  final fitted = applyBoxFit(cover ? BoxFit.cover : BoxFit.contain, size, rect.size);
  final source = Alignment.center.inscribe(fitted.source, Offset.zero & size);
  final dest = Alignment.center.inscribe(fitted.destination, rect);
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

/// Glossy illuminated campaign panels. The bright core is surrounded by
/// a softer colored bloom, rather than a flat single-width app border.
void _promoLightFrame(Canvas canvas, RRect shape, Color hue, {double core = 4, double bloom = 12}) {
  final rect = shape.outerRect;
  canvas.drawRRect(shape, Paint()..style = PaintingStyle.stroke
    ..strokeWidth = core * 3.8..color = hue.withValues(alpha: .70)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, bloom));
  canvas.drawRRect(shape, Paint()..style = PaintingStyle.stroke
    ..strokeWidth = core * 1.8..color = hue.withValues(alpha: .91)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
  canvas.drawRRect(shape, Paint()..style = PaintingStyle.stroke..strokeWidth = core
    ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [hue, Colors.white, hue, Colors.white, hue],
      stops: const [0, .18, .44, .76, 1]).createShader(rect));
}

void _promoGlossyPill(Canvas canvas, RRect shape, Color hue) {
  final rect = shape.outerRect;
  const deep = Color(0xFF111C30);
  canvas.drawRRect(shape.shift(const Offset(0, 7)), Paint()
    ..color = const Color(0xCC000711)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
  canvas.drawRRect(shape, Paint()..shader = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [Color.lerp(hue, Colors.white, .25)!, hue,
      Color.lerp(hue, deep, .50)!, Color.lerp(hue, deep, .76)!,
      Color.lerp(hue, deep, .54)!],
    stops: const [0, .10, .32, .70, 1]).createShader(rect));
  canvas.save();
  canvas.clipRRect(shape);
  final shine = Rect.fromLTWH(rect.left + 24, rect.top + 2, rect.width - 48, rect.height * .38);
  canvas.drawOval(shine, Paint()..shader = RadialGradient(colors: [
    Colors.white.withValues(alpha: .34), hue.withValues(alpha: .03), Colors.transparent,
  ]).createShader(shine));
  canvas.restore();
  _promoLightFrame(canvas, shape, hue, core: 4.5, bloom: 13);
  final streak = Rect.fromLTWH(rect.left + rect.width * .09, rect.top + 3,
    rect.width * .29, 3);
  canvas.drawRRect(RRect.fromRectAndRadius(streak, const Radius.circular(2)),
    Paint()..shader = const LinearGradient(colors: [Colors.transparent, Colors.white,
      Colors.transparent]).createShader(streak));
}

/// The approved booking motif: a turquoise location pin, lime floor ring,
/// large italic white/green lettering and a sweeping lime arrow. It is
/// drawn as native vector art, so the 1080px export has crisp edges.
void _promoReferenceBooking(Canvas canvas, Rect area) {
  const cyan = Color(0xFF00E8FF);
  const green = Color(0xFF81FF00);
  const pale = Color(0xFFF6FFBD);
  const white = Colors.white;
  final unit = area.width / 600;
  canvas.save();
  canvas.translate(area.left, area.top);
  canvas.scale(unit, unit);
  const pinArea = Rect.fromLTWH(15, 18, 153, 188);
  const base = Rect.fromLTWH(8, 167, 166, 53);
  canvas.drawOval(base, Paint()..style = PaintingStyle.stroke..strokeWidth = 12
    ..color = green.withValues(alpha: .60)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
  canvas.drawOval(base, Paint()..style = PaintingStyle.stroke..strokeWidth = 8
    ..shader = const LinearGradient(colors: [Color(0xFFE6FF3B), green,
      Color(0xFF25EA8A)]).createShader(base));
  final pin = ui.Path()..moveTo(91, 4)
    ..cubicTo(46, 4, 13, 38, 13, 81)
    ..cubicTo(13, 128, 60, 172, 91, 203)
    ..cubicTo(122, 172, 169, 128, 169, 81)
    ..cubicTo(169, 38, 136, 4, 91, 4)..close();
  final inset = ui.Path()..moveTo(91, 23)
    ..cubicTo(56, 23, 33, 48, 33, 81)
    ..cubicTo(33, 116, 65, 151, 91, 177)
    ..cubicTo(117, 151, 149, 116, 149, 81)
    ..cubicTo(149, 48, 126, 23, 91, 23)..close();
  final outline = ui.Path.combine(ui.PathOperation.difference, pin, inset);
  canvas.drawPath(outline, Paint()..color = cyan.withValues(alpha: .48)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
  canvas.drawPath(outline, Paint()..shader = const LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFE3FFFF), cyan, Color(0xFF00A4D6)],
    stops: [0, .30, 1]).createShader(pinArea));
  const center = Offset(91, 80);
  canvas.drawCircle(center, 32, Paint()..style = PaintingStyle.stroke..strokeWidth = 13
    ..shader = const LinearGradient(colors: [Color(0xFF84F9FF), cyan,
      Color(0xFF007EAA)]).createShader(Rect.fromCircle(center: center, radius: 32)));
  const shadow = [Shadow(color: Color(0xAA000A18), offset: Offset(3, 5), blurRadius: 4)];
  _promoText(canvas, 'Solicita mi', 185, 8, 410, 64, white,
    weight: FontWeight.w900, lines: 1, italic: true, minFontSize: 49, shadows: shadow);
  _promoText(canvas, 'servicio', 184, 69, 410, 89, green,
    weight: FontWeight.w900, lines: 1, italic: true, minFontSize: 68, shadows: shadow,
    shader: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xFFCAFF34), Color(0xFF6DFF00), Color(0xFF21DC00)])
      .createShader(const Rect.fromLTWH(184, 69, 410, 98)));
  _promoText(canvas, 'desde este enlace', 187, 163, 405, 38, white,
    weight: FontWeight.w800, lines: 1, italic: true, minFontSize: 30, shadows: shadow);
  // Tapered swoosh, as in the approved reference, points towards the QR.
  final arrow = ui.Path()..moveTo(257, 221)
    ..cubicTo(348, 269, 440, 263, 529, 230)
    ..lineTo(515, 217)..lineTo(590, 222)..lineTo(544, 275)
    ..lineTo(541, 251)..cubicTo(429, 289, 339, 274, 257, 221)..close();
  canvas.drawPath(arrow, Paint()..color = green.withValues(alpha: .48)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
  canvas.drawPath(arrow, Paint()..shader = const LinearGradient(
    colors: [Color(0xFF11CD00), green, pale]).createShader(const Rect.fromLTWH(257, 217, 333, 65)));
  canvas.restore();
}

/// Renders the actual exported artwork, not a separate HTML QR or screenshot.
/// No photos or generated files are uploaded by this renderer.
Future<Uint8List> renderMarketplaceDriverPromoCard({
  required String name, required String code, required String modality,
  required bool story, Uint8List? photoBytes, Uint8List? logoBytes, String? alias,
  ProjectIdentity identity = ProjectIdentity.fallback,
  bool identityVerified = false,
  String vehicleCategory = 'light_car',
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
    const neon = Color(0xFF00E8FF);
    const lime = Color(0xFF80FF00);
    const midnight = Color(0xFF03172F);
    final artworkCategory = vehicleCategory == 'confort' ? 'comfort' : vehicleCategory;
    final modalityAccent = switch (artworkCategory) {
      'tricycle' => const Color(0xFFFF8800),
      'light_car' => const Color(0xFF00CFFF),
      'motorcycle' => const Color(0xFF43FF57),
      'bicitaxi' => const Color(0xFFD56AFF),
      'comfort' => const Color(0xFFFFD326),
      _ => accent,
    };
    // A campaign artwork, not an app screen: the dark stage, energetic
    // diagonal ribbons and a luminous portrait anchor the composition.
    canvas.drawRect(bounds, Paint()..shader = LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [midnight, Color.lerp(background, const Color(0xFF002B59), .72)!,
        const Color(0xFF00152E)],
      stops: const [0, .56, 1],
    ).createShader(bounds));
    final glow = Rect.fromCircle(
      center: Offset(story ? 835 : 790, story ? 785 : 325),
      radius: story ? 720 : 490);
    canvas.drawRect(glow, Paint()..shader = RadialGradient(
      colors: [neon.withValues(alpha: .28), primary.withValues(alpha: 0)],
    ).createShader(glow));

    // The route-inspired strokes are ornamental, not representations of a
    // driver's real journey. They remain behind all foreground artwork.
    final sweepY = story ? 795.0 : 415.0;
    final ribbon = ui.Path()
      ..moveTo(-95, sweepY + 160)
      ..cubicTo(280, sweepY + 58, 630, sweepY - 130, 1175, sweepY - 260)
      ..lineTo(1175, sweepY - 108)
      ..cubicTo(630, sweepY + 12, 285, sweepY + 196, -95, sweepY + 290)..close();
    canvas.drawPath(ribbon, Paint()..shader = const LinearGradient(
      begin: Alignment.bottomLeft, end: Alignment.topRight,
      colors: [Color(0xFF00365F), Color(0xFF0078BC), Color(0xFF013257), Color(0xFF04172D)],
      stops: [0, .25, .60, 1]).createShader(bounds));
    final secondRibbon = ui.Path()..moveTo(-80, sweepY + 275)
      ..cubicTo(250, sweepY + 175, 685, sweepY - 8, 1160, sweepY - 102)
      ..lineTo(1160, sweepY - 43)
      ..cubicTo(695, sweepY + 41, 305, sweepY + 240, -80, sweepY + 355)..close();
    canvas.drawPath(secondRibbon, Paint()..shader = const LinearGradient(
      colors: [Color(0xFF01B8F5), Color(0xFF004E89), Color(0xFF05243F)]).createShader(bounds));
    final route = ui.Path()
      ..moveTo(-60, sweepY + 270)
      ..cubicTo(290, sweepY + 168, 685, sweepY - 8, 1145, sweepY - 102);
    canvas.drawPath(route, Paint()
      ..style = PaintingStyle.stroke ..strokeWidth = 17
      ..color = neon.withValues(alpha: .72)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15));
    canvas.drawPath(route, Paint()..style = PaintingStyle.stroke..strokeWidth = 4
      ..shader = LinearGradient(colors: [neon, white, modalityAccent]).createShader(bounds));
    final routeLight = ui.Path()
      ..moveTo(-60, sweepY + 338)
      ..cubicTo(310, sweepY + 220, 720, sweepY + 25, 1145, sweepY - 43);
    canvas.drawPath(routeLight, Paint()
      ..style = PaintingStyle.stroke ..strokeWidth = 5
      ..shader = LinearGradient(colors: [neon.withValues(alpha: .8),
        const Color(0xFF006CBD), modalityAccent.withValues(alpha: .75)]).createShader(bounds));
    // Electric-blue halftone framing, kept clear of the portrait and text.
    for (var row = 0; row < 18; row++) {
      for (var col = 0; col < 7; col++) {
        final opacity = .46 * (1 - col / 8) * (1 - row / 20);
        canvas.drawCircle(Offset(16 + col * 16.0, 16 + row * 17.0), 2.1,
          Paint()..color = const Color(0xFF00BFFF).withValues(alpha: opacity));
        canvas.drawCircle(Offset(1064 - col * 16.0, height - 22 - row * 17.0), 2.1,
          Paint()..color = const Color(0xFF00BFFF).withValues(alpha: opacity));
      }
    }

    // Approved campaign composition: logo left, large agency wordmark,
    // circular portrait left, vehicle upper right, identity beneath it.
    // The taller format uses an expanded vertical rhythm, not stretched art.
    final headerY = story ? 65.0 : 28.0;
    final iconSize = story ? 126.0 : 111.0;
    if (logo != null) {
      _promoFitImage(canvas, logo, Rect.fromLTWH(72, headerY, iconSize, iconSize));
      canvas.drawLine(Offset(72 + iconSize + 25, headerY + 8),
        Offset(72 + iconSize + 25, headerY + iconSize - 8),
        Paint()..color = accent.withValues(alpha: .65)..strokeWidth = 3);
    }
    final brandX = logo == null ? 72.0 : 72.0 + iconSize + 52;
    _promoText(canvas, 'Agencia TukTuk', brandX, headerY,
      730 - brandX, story ? 51 : 54, white, lines: 1,
      weight: FontWeight.w900, minFontSize: 34, letterSpacing: -1.4,
      boxHeight: iconSize);
    // Approved Impulsa campaign lockup: cyan growth bars and a vivid gold tab.
    final mark = Rect.fromLTWH(752, headerY + 5, 280, iconSize - 6);
    final markShape = RRect.fromRectAndRadius(mark, const Radius.circular(22));
    canvas.drawRRect(markShape, Paint()..style = PaintingStyle.stroke..strokeWidth = 8
      ..color = neon.withValues(alpha: .7)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    canvas.drawRRect(markShape, Paint()..color = const Color(0xFF05253D));
    _promoLightFrame(canvas, markShape, neon, core: 3, bloom: 9);
    for (var i = 0; i < 3; i++) {
      final barHeight = 23.0 + i * 11;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(mark.left + 12 + i * 19,
        mark.bottom - 13 - barHeight, 13, barHeight), const Radius.circular(6)),
        Paint()..shader = const LinearGradient(colors: [Color(0xFF79FFFF), Color(0xFF00A9E9)]).createShader(mark));
    }
    _promoText(canvas, 'TukTuk', mark.left + 70, mark.top + 3, mark.width - 76,
      34, white, center: true, weight: FontWeight.w900, lines: 1, italic: true);
    final goldTab = Rect.fromLTWH(mark.left + 65, mark.bottom - 50, mark.width - 72, 48);
    final goldShape = RRect.fromRectAndRadius(goldTab, const Radius.circular(15));
    canvas.drawRRect(goldShape, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xFFFFEF65), Color(0xFFFFBE00), Color(0xFFFF8B00)]).createShader(goldTab));
    _promoLightFrame(canvas, goldShape, const Color(0xFFFFB000), core: 2.5, bloom: 8);
    _promoText(canvas, 'Impulsa', goldTab.left + 5, goldTab.top, goldTab.width - 10,
      36, midnight, center: true, weight: FontWeight.w900, lines: 1, italic: true, boxHeight: 48);
    final brandRule = Rect.fromLTWH(48, headerY + iconSize + 27, 984, 7);
    canvas.drawRRect(RRect.fromRectAndRadius(brandRule, const Radius.circular(4)),
      Paint()..shader = LinearGradient(colors: [
        lime, accent, white.withValues(alpha: .75), primary.withValues(alpha: .04),
      ], stops: const [0, .32, .51, 1]).createShader(brandRule));

    canvas.drawRRect(RRect.fromRectAndRadius(brandRule, const Radius.circular(4)),
      Paint()..color = accent.withValues(alpha: .65)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
    final vehicleArea = story
      ? const Rect.fromLTWH(425, 550, 600, 440)
      : const Rect.fromLTWH(704, 166, 350, 298);
    final vehicleGlow = vehicleArea.inflate(75);
    // The upper-right orange light ribbon is a filled, glossy arc, not a
    // straight outline through the name or portrait.
    final vehicleRibbon = ui.Path()
      ..moveTo(vehicleArea.left - 180, vehicleArea.bottom - 30)
      ..cubicTo(vehicleArea.left + 25, vehicleArea.top + 70,
        vehicleArea.right - 15, vehicleArea.top - 5, 1155, vehicleArea.top - 70)
      ..lineTo(1155, vehicleArea.top + 44)
      ..cubicTo(vehicleArea.right + 20, vehicleArea.top + 95,
        vehicleArea.left + 90, vehicleArea.bottom - 20, vehicleArea.left - 180, vehicleArea.bottom + 70)..close();
    canvas.drawPath(vehicleRibbon, Paint()..shader = LinearGradient(
      begin: Alignment.bottomLeft, end: Alignment.topRight,
      colors: [Colors.transparent, modalityAccent.withValues(alpha: .30),
        modalityAccent, Color.lerp(modalityAccent, const Color(0xFF692300), .55)!],
      stops: const [0, .30, .69, 1]).createShader(vehicleGlow));
    canvas.drawOval(vehicleGlow, Paint()..shader = RadialGradient(colors: [
      modalityAccent.withValues(alpha: .74), modalityAccent.withValues(alpha: 0),
    ]).createShader(vehicleGlow));
    // The modality-colored sweep follows the approved campaign composition.
    final vehicleSweep = ui.Path()
      ..moveTo(vehicleArea.left - 110, vehicleArea.bottom - 30)
      ..cubicTo(vehicleArea.left + 80, vehicleArea.top + 25,
        vehicleArea.right - 90, vehicleArea.top + 20,
        vehicleArea.right + 100, vehicleArea.top - 55);
    canvas.drawPath(vehicleSweep, Paint()..style = PaintingStyle.stroke
      ..strokeWidth = 52..strokeCap = StrokeCap.round
      ..color = modalityAccent.withValues(alpha: .70)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 19));
    canvas.drawPath(vehicleSweep, Paint()..style = PaintingStyle.stroke
      ..strokeWidth = 5..strokeCap = StrokeCap.round
      ..shader = LinearGradient(colors: [modalityAccent.withValues(alpha: 0),
        modalityAccent, white.withValues(alpha: .8), modalityAccent])
        .createShader(vehicleGlow));
    final ground = Rect.fromLTWH(vehicleArea.left + 8,
      vehicleArea.bottom - 20, vehicleArea.width - 16, 34);
    canvas.drawOval(ground, Paint()..color = const Color(0xFF000810)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    canvas.drawOval(ground.inflate(7), Paint()..style = PaintingStyle.stroke
      ..strokeWidth = 14..color = modalityAccent
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    canvas.drawOval(ground.inflate(4), Paint()..style = PaintingStyle.stroke
      ..strokeWidth = 5..shader = LinearGradient(colors: [modalityAccent, white,
        modalityAccent, white]).createShader(ground));
    canvas.drawOval(ground.deflate(4), Paint()..style = PaintingStyle.stroke
      ..strokeWidth = 2..color = modalityAccent.withValues(alpha: .75));
    final artwork = _promoModalityArtwork[artworkCategory];
    if (artwork != null) {
      final asset = await rootBundle.load(artwork);
      final vehicle = await _promoDecode(asset.buffer.asUint8List(
        asset.offsetInBytes, asset.lengthInBytes));
      try {
        _promoFitImage(canvas, vehicle, vehicleArea);
      } finally {
        vehicle.dispose();
      }
    } else {
      _promoVehicleWatermark(canvas, vehicleCategory, vehicleArea, accent);
    }

    final photoRect = story
        ? const Rect.fromLTWH(55, 265, 380, 380)
        : const Rect.fromLTWH(60, 174, 290, 290);
    final photoRadius = photoRect.width / 2;
    final portraitGlow = Rect.fromCircle(center: photoRect.center, radius: photoRadius + 47);
    canvas.drawCircle(photoRect.center, photoRadius + 47,
      Paint()..shader = RadialGradient(colors: [
        neon.withValues(alpha: .84), primary.withValues(alpha: 0),
      ]).createShader(portraitGlow));
    canvas.drawCircle(photoRect.center, photoRadius + 14,
      Paint()..color = const Color(0xFF07121D));
    canvas.drawCircle(photoRect.center, photoRadius + 10,
      Paint()..style = PaintingStyle.stroke..strokeWidth = 14
        ..color = neon..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    canvas.drawCircle(photoRect.center, photoRadius + 9,
      Paint()..shader = const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [white, neon, Color(0xFF008BFF)],
      ).createShader(portraitGlow));
    canvas.drawCircle(photoRect.center, photoRadius + 3,
      Paint()..color = const Color(0xFF101C29));
    canvas.save();
    canvas.clipPath(ui.Path()..addOval(photoRect));
    canvas.drawRect(photoRect, Paint()..shader = LinearGradient(
      colors: [Color.lerp(background, accent, .20)!, const Color(0xFF172B39)],
      begin: Alignment.topLeft, end: Alignment.bottomRight,
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

    final nameArea = story ? const Rect.fromLTWH(463, 304, 559, 120)
      : const Rect.fromLTWH(364, 236, 340, 108);
    final nameBottom = _promoVerifiedName(canvas, name, nameArea,
      fontSize: story ? 97 : 76, minFontSize: 30, center: false,
      identityVerified: identityVerified);
    final roleY = nameBottom + 10;
    _promoText(canvas, identityVerified ? 'Conductor verificado de la Agencia TukTuk'
      : 'Conductor de la Agencia TukTuk', nameArea.left, roleY,
      nameArea.width, story ? 36 : 29, white, lines: 2,
      weight: FontWeight.w700, minFontSize: 22,
      shadows: const [Shadow(color: Color(0xBB000916), offset: Offset(1, 2), blurRadius: 3)]);
    final identityRule = Rect.fromLTWH(nameArea.left, story ? 520 : 449, story ? nameArea.width : 337, 5);
    canvas.drawRRect(RRect.fromRectAndRadius(identityRule, const Radius.circular(3)),
      Paint()..shader = LinearGradient(colors: [lime, accent,
        accent.withValues(alpha: 0)]).createShader(identityRule));

    final servicePill = story
      ? const Rect.fromLTWH(42, 1047, 996, 94)
      : const Rect.fromLTWH(72, 478, 936, 72);
    final pill = RRect.fromRectAndRadius(servicePill, Radius.circular(servicePill.height / 2));
    _promoGlossyPill(canvas, pill, modalityAccent);
    final miniVehicle = Rect.fromLTWH(servicePill.left + 16,
      servicePill.center.dy - servicePill.height * .31,
      servicePill.height * 1.45, servicePill.height * .62);
    final modalityIcon = switch (vehicleCategory) {
      'motorcycle' => Icons.two_wheeler,
      'bicycle' || 'bicitaxi' => Icons.pedal_bike,
      'tricycle' => Icons.electric_rickshaw,
      'van' => Icons.airport_shuttle,
      'truck' => Icons.local_shipping,
      'comfort' || 'confort' => Icons.diamond_outlined,
      _ => Icons.directions_car,
    };
    final vehicleGlyph = TextPainter(
      text: TextSpan(text: String.fromCharCode(modalityIcon.codePoint),
        style: TextStyle(fontFamily: modalityIcon.fontFamily,
          package: modalityIcon.fontPackage, color: white,
          fontSize: servicePill.height * .72)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    vehicleGlyph.paint(canvas, Offset(
      miniVehicle.center.dx - vehicleGlyph.width / 2,
      miniVehicle.center.dy - vehicleGlyph.height / 2));
    vehicleGlyph.dispose();
    final dividerX = miniVehicle.right + 14;
    canvas.drawLine(Offset(dividerX, servicePill.top + 17),
      Offset(dividerX, servicePill.bottom - 17),
      Paint()..color = modalityAccent..strokeWidth = 2);
    _promoText(canvas, modality, dividerX + 17,
      servicePill.top, servicePill.right - dividerX - 30,
      story ? 44 : 35, white, center: true, lines: 2, minFontSize: 23,
      boxHeight: servicePill.height, weight: FontWeight.w900,
      shadows: const [Shadow(color: Color(0xCC201000), offset: Offset(1, 2), blurRadius: 3)]);

    // Full-width luminous frame and the approved booking motif, with no
    // cut raster edge or extra inner rectangle around the copy.
    final panel = story
      ? const Rect.fromLTWH(40, 1160, 1000, 365)
      : const Rect.fromLTWH(40, 565, 1000, 320);
    final ctaFrame = story
      ? const Rect.fromLTWH(30, 1150, 1020, 520)
      : const Rect.fromLTWH(30, 560, 1020, 430);
    final ctaShape = RRect.fromRectAndRadius(ctaFrame, const Radius.circular(48));
    canvas.drawRRect(ctaShape.shift(const Offset(0, 8)), Paint()
      ..color = const Color(0xD9000712)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    canvas.drawRRect(ctaShape, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF052B48), Color(0xFF031B30), Color(0xFF003F63)],
      stops: [0, .52, 1]).createShader(ctaFrame));
    _promoLightFrame(canvas, ctaShape, neon, core: 5, bloom: 16);
    final bookingArea = Rect.fromLTWH(panel.left + 44, panel.top + (story ? 43 : 24),
      586, 276);
    _promoReferenceBooking(canvas, bookingArea);
    final divider = Rect.fromLTWH(panel.left + 636, panel.top + 31, 3, panel.height - 64);
    canvas.drawRect(divider, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Colors.transparent, Color(0xFF00BFE9), Colors.transparent]).createShader(divider));

    // Overlay the real code in the center of the original white well.
    // Integer modules and four full white modules of quiet zone preserve
    // the scanner contract. The surrounding graphic is not resized with QR.
    final qr = marketplaceDriverPromoQr(code, alias: alias);
    final module = story ? 6.0 : 5.0;
    final qrSize = (qr.moduleCount + 8) * module;
    final qrX = story ? 690.0 : 704.0;
    final qrY = story ? 1192.0 : 594.0;
    final well = Rect.fromLTWH(qrX - 14, qrY - 14, qrSize + 28, qrSize + 28);
    final wellShape = RRect.fromRectAndRadius(well, const Radius.circular(23));
    canvas.drawRRect(wellShape, Paint()..color = white);
    _promoLightFrame(canvas, wellShape, neon, core: 5, bloom: 13);
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
    // The human-readable short address is an integral part of BOTH exported PNGs.
    // Its QR and share copy are built from the same canonical URI, never from a mock.
    final link = marketplaceDriverPromoDisplayLink(code, alias: alias);
    final linkArea = story
      ? const Rect.fromLTWH(58, 1530, 964, 112)
      : const Rect.fromLTWH(58, 889, 964, 82);
    final linkShape = RRect.fromRectAndRadius(linkArea, Radius.circular(linkArea.height / 2));
    _promoGlossyPill(canvas, linkShape, modalityAccent);
    final linkIcon = TextPainter(textDirection: ui.TextDirection.ltr,
      text: TextSpan(text: String.fromCharCode(Icons.link.codePoint), style: TextStyle(
        fontFamily: Icons.link.fontFamily, package: Icons.link.fontPackage, color: white,
        fontSize: story ? 62 : 52)))..layout();
    linkIcon.paint(canvas, Offset(linkArea.left + 26, linkArea.center.dy - linkIcon.height / 2));
    linkIcon.dispose();
    canvas.drawLine(Offset(linkArea.left + 105, linkArea.top + 15),
      Offset(linkArea.left + 105, linkArea.bottom - 15), Paint()..color = white.withValues(alpha: .8)..strokeWidth = 3);
    // Long aliases must remain complete, not be truncated. The old internal URL
    // is only a non-commercial fallback for already-existing internal callers.
    _promoText(canvas, link, linkArea.left + 119, linkArea.top,
      linkArea.width - 215, story ? 59 : 53, white, center: true, lines: 1,
      minFontSize: 17, weight: FontWeight.w900, boxHeight: linkArea.height,
      shadows: const [Shadow(color: Color(0xCC251000), offset: Offset(1, 3), blurRadius: 3)]);
    final touch = TextPainter(textDirection: ui.TextDirection.ltr,
      text: TextSpan(text: String.fromCharCode(Icons.touch_app_outlined.codePoint), style: TextStyle(
        fontFamily: Icons.touch_app_outlined.fontFamily, package: Icons.touch_app_outlined.fontPackage,
        color: white, fontSize: story ? 66 : 54)))..layout();
    final touchOrigin = Offset(linkArea.right - touch.width - 22, linkArea.center.dy - touch.height / 2);
    touch.paint(canvas, touchOrigin);
    touch.dispose();
    final spark = touchOrigin + const Offset(7, 7);
    final sparkPaint = Paint()..color = const Color(0xFFFFE33C)..strokeWidth = 4..strokeCap = StrokeCap.round;
    canvas.drawLine(spark + const Offset(-13, -4), spark + const Offset(-21, -9), sparkPaint);
    canvas.drawLine(spark + const Offset(0, -9), spark + const Offset(0, -20), sparkPaint);
    canvas.drawLine(spark + const Offset(11, -4), spark + const Offset(19, -12), sparkPaint);
    canvas.drawRRect(ctaShape, Paint()..style = PaintingStyle.stroke..strokeWidth = 5
      ..shader = const LinearGradient(colors: [neon, white, neon, Color(0xFF008BFF)], stops: [0, .22, .55, 1]).createShader(ctaFrame));
    final footerY = story ? 1705.0 : 1007.0;
    _promoText(canvas, 'Tu conductor de confianza, a un toque.', 105,
      footerY, 870, story ? 40 : 29, white,
      center: true, weight: FontWeight.w800, lines: 1, minFontSize: 20, italic: true,
      shadows: const [Shadow(color: Color(0xBB001226), offset: Offset(1, 3), blurRadius: 4)]);
    for (final x in [48.0, 980.0]) {
      final dash = Rect.fromLTWH(x, footerY + (story ? 21 : 14), 52, 5);
      canvas.drawRRect(RRect.fromRectAndRadius(dash, const Radius.circular(3)),
        Paint()..shader = LinearGradient(colors: [modalityAccent, white, modalityAccent]).createShader(dash));
    }
    final bottomBand = ui.Path()..moveTo(-40, height - 20.0)
      ..cubicTo(260, height - 100.0, 700, height + 20.0, 1140, height - 65.0)
      ..lineTo(1140, height + 40.0)..lineTo(-40, height + 40.0)..close();
    canvas.drawPath(bottomBand, Paint()..shader = const LinearGradient(
      colors: [Color(0xFF00365C), Color(0xFF00A7E9), Color(0xFF06477A), Color(0xFF001A34)]).createShader(bounds));
    final lowerSweep = ui.Path()..moveTo(-40, height - 28.0)
      ..cubicTo(280, height - 48.0, 710, height + 42.0, 1140, height - 38.0);
    canvas.drawPath(lowerSweep, Paint()..style = PaintingStyle.stroke
      ..strokeWidth = 25..color = neon.withValues(alpha: .83)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));
    canvas.drawPath(lowerSweep, Paint()..style = PaintingStyle.stroke
      ..strokeWidth = 6..shader = LinearGradient(colors: [neon, white, modalityAccent]).createShader(bounds));
    final bottomGold = ui.Path()..moveTo(470, height + 11.0)
      ..cubicTo(720, height - 24.0, 900, height - 13.0, 1140, height - 80.0);
    canvas.drawPath(bottomGold, Paint()..style = PaintingStyle.stroke..strokeWidth = 12
      ..color = modalityAccent.withValues(alpha: .70)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
    canvas.drawPath(bottomGold, Paint()..style = PaintingStyle.stroke..strokeWidth = 3
      ..shader = LinearGradient(colors: [modalityAccent, white, modalityAccent]).createShader(bounds));
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 4, width - 8.0, height - 8.0), const Radius.circular(32)),
      Paint()..style = PaintingStyle.stroke..strokeWidth = 3
      ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [accent, accent.withValues(alpha: .18), accent]).createShader(bounds));
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
const _marketplacePromoArtworkVersion = 17;
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
  bool _busy = true, _enabled = false;
  bool _sharing = false, _identityVerified = false;
  String? _error, _code, _photoAssetId, _alias;
  Uint8List? _squareBytes, _storyBytes;
  int _revision = 0;
  bool get _sameUser => _actor != null && _client.auth.currentUser?.id == _actor;
  Uint8List? _artworkFor(bool story) => story ? _storyBytes : _squareBytes;
  String _fileNameFor(bool story) => story ? 'Mi-TukTuk-historia.png' : 'Mi-TukTuk.png';
  String? get _copy => _code == null ? null : marketplaceDriverPromoCopy(_name.text.trim(), _code!, identityVerified: _identityVerified, alias: _alias);

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
          _enabled = false; _busy = false; _code = null; _identityVerified = false;
          _photoAssetId = null;
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
        setState(() {
          _name.text = name; _code = code; _alias = alias;
          _squareBytes = cached.square; _storyBytes = cached.story;
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
      setState(() { _name.text = name; _code = code; _alias = alias; _squareBytes = square; _storyBytes = story; });
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
    setState(() { _busy = true; _error = null; _code = null; _squareBytes = null; _storyBytes = null; });
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
    if (kIsWeb && driver_promo_download.downloadPromoPng(bytes, fileName)) return;
    try {
      await SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes,
        mimeType: 'image/png', name: fileName)], fileNameOverrides: [fileName]));
    } catch (_) {
      if (mounted) toast(context, 'No se pudo descargar la tarjeta.');
    }
  }

  Future<void> _copyText(String text) async {
    if (!_sameUser || !_enabled || _squareBytes == null || _storyBytes == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) toast(context, 'Copiado');
    } catch (_) {
      if (mounted) toast(context, 'Selecciona el texto para copiarlo manualmente.');
    }
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
            if (previewReady) ...[
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.link),
                    title: const Text('Mi enlace personal'),
                    subtitle: SelectableText(marketplaceDriverPromoUri(_code!, alias: _alias).toString().replaceFirst('https://www.', '')),
                    trailing: IconButton(
                      tooltip: 'Copiar enlace',
                      onPressed: () => _copyText(marketplaceDriverPromoUri(_code!, alias: _alias).toString()),
                      icon: const Icon(Icons.copy_outlined),
                    ),
                    onTap: () => _copyText(marketplaceDriverPromoUri(_code!, alias: _alias).toString()),
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
                          TextButton.icon(onPressed: () => _copyText(copy),
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
  late Future<(String, Uint8List, Uint8List, String)> _cards;
  @override
  void initState() {
    super.initState();
    _cards = _load();
  }

  Future<(String, Uint8List, Uint8List, String)> _load() async {
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
    return (name, square, story, alias);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF101619),
    body: SafeArea(child: FutureBuilder<(String, Uint8List, Uint8List, String)>(
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
        final (name, square, story, alias) = snapshot.data!;
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
