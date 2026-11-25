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

/// Shared verified badge. Drawn beside the subtitle, not over a long name.
void _promoVerifiedSeal(Canvas canvas, Offset topLeft, double size, {
  bool glow = false,
}) {
  canvas.save();
  canvas.translate(topLeft.dx, topLeft.dy);
  canvas.scale(size / 32);
  final seal = ui.Path();
  for (var i = 0; i < 32; i++) {
    final angle = i * pi / 16 - pi / 2;
    final radius = i.isEven ? 15.0 : 13.4;
    final px = 16 + cos(angle) * radius;
    final py = 16 + sin(angle) * radius;
    if (i == 0) {
      seal.moveTo(px, py);
    } else {
      seal.lineTo(px, py);
    }
  }
  seal.close();
  if (glow) {
    canvas.drawPath(seal, Paint()..color = const Color(0xFF00C8FF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6));
  }
  canvas.drawPath(seal, Paint()..color = const Color(0xFF1D9BF0));
  final check = ui.Path()..moveTo(9, 16)..lineTo(14, 21)..lineTo(23, 11);
  canvas.drawPath(check, Paint()..color = Colors.white
    ..style = PaintingStyle.stroke..strokeWidth = 3.2
    ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  canvas.restore();
}

/// Scale name to fit its area; no ellipsis or badge stealing name width.
double _promoVerifiedName(Canvas canvas, String name, Rect area, {
  required double fontSize, required double minFontSize, required bool center,
}) {
  final painter = TextPainter(textDirection: ui.TextDirection.ltr,
    textAlign: center ? TextAlign.center : TextAlign.left);
  var size = fontSize;
  while (true) {
    painter.text = TextSpan(text: name.trim().replaceAll(RegExp(r'\s+'), ' '),
      style: TextStyle(color: Colors.white, fontFamily: 'ImpulsaMontserrat',
        fontSize: size, fontWeight: FontWeight.w800,
        height: 1.06, letterSpacing: -1.3));
    painter.layout(maxWidth: area.width);
    if (painter.height <= area.height || size <= 12) break;
    size = max(12.0, size - (size > minFontSize ? 2 : 1));
  }
  final x = center ? area.left + (area.width - painter.width) / 2 : area.left;
  painter.paint(canvas, Offset(x, area.top));
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

/// Renders the real exported PNG, shared by Impulsa and the Admin viewer.
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
      fontSize: story ? 94 : 77, minFontSize: 23, center: false);
    final verificationTop = nameBottom + 6;
    final verificationSealSize = story ? 45.0 : 36.0;
    if (identityVerified) {
      _promoVerifiedSeal(canvas, Offset(nameArea.left, verificationTop + 3),
        verificationSealSize, glow: true);
    }
    final verificationIndent = identityVerified ? verificationSealSize + 8 : 0.0;
    _promoText(canvas, identityVerified ? 'Conductor verificado de la Agencia TukTuk'
      : 'Conductor de la Agencia TukTuk', nameArea.left + verificationIndent,
      verificationTop, nameArea.width - verificationIndent,
      story ? 33 : 25, white, lines: 2, minFontSize: 18,
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
const _marketplacePromoArtworkVersion = 20;
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
    const accent = Color(0xFFA9C7FF);
    const muted = Color(0xFFC1CDE4);
    const ink = Color(0xFFF2F5FC);
    final theme = Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: accent,
        onSurface: ink,
        onSurfaceVariant: muted,
      ),
      dividerColor: const Color(0xFF52668A),
    );
    final d = earnings;

    Widget metric(String label, String value) => Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF243653),
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ]),
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF344C73), Color(0xFF263650), Color(0xFF343B60)],
        ),
        border: Border.all(color: accent.withValues(alpha: .45)),
      ),
      child: Theme(
        data: theme,
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: ink),
          child: Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.insights_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Expanded(child: Text('Resultados de Impulsa',
              style: TextStyle(color: accent, fontSize: 17, fontWeight: FontWeight.w800))),
            IconButton(tooltip: 'Actualizar resultados',
              onPressed: loading ? null : refresh,
              icon: const Icon(Icons.refresh, color: accent)),
          ]),
          if (loading) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          const Text('Total ganado por promoción', style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(_cup(d.credited),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
              color: theme.colorScheme.primary)),
          const Text('Acumulado histórico; tu saldo para retirar aparece en Billetera Impulsa.',
            style: TextStyle(color: muted, fontSize: 11)),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: metric('Solicitudes generadas', '${d.generated}')),
            const SizedBox(width: 8),
            Expanded(child: metric('Viajes de la flota acreditados', '${d.creditedTrips}')),
          ]),
          if (d.pending > 0) ...[
            const SizedBox(height: 10),
            Text('Ganancias por acreditar: ${_cup(d.pending)}',
              style: const TextStyle(color: muted, fontSize: 12)),
          ],
          ExpansionTile(
            key: const ValueKey('impulsa-more-results'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text('Ver más resultados', style: TextStyle(fontSize: 13)),
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: metric('Viajes propios liquidados', '${d.ownTrips}')),
                const SizedBox(width: 8),
                Expanded(child: metric('Ahorro en comisión', _cup(d.ownSavings))),
              ]),
              if (d.fundingRequired > 0)
                Padding(padding: const EdgeInsets.only(top: 8),
                  child: Text('Pendientes de financiación: ${_cup(d.fundingRequired)}',
                    style: const TextStyle(color: muted, fontSize: 12))),
              if (d.reversalPending > 0)
                Padding(padding: const EdgeInsets.only(top: 8),
                  child: Text('Ajustes pendientes: ${_cup(d.reversalPending)}',
                    style: const TextStyle(color: muted, fontSize: 12))),
              if (d.recent.isNotEmpty) ExpansionTile(
                title: const Text('Historial comercial'),
                tilePadding: EdgeInsets.zero, childrenPadding: EdgeInsets.zero,
                children: d.recent.map((row) {
                  final id = row['job_id']?.toString() ?? '';
                  final value = num.tryParse(row['amount']?.toString() ?? '') ?? 0;
                  final rate = num.tryParse(row['commercial_rate']?.toString() ?? '');
                  final date = DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal();
                  return ListTile(
                    contentPadding: EdgeInsets.zero, dense: true,
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(_label(row['state'])),
                    subtitle: Text([
                      if (id.isNotEmpty) 'Viaje ${id.substring(0, min(8,id.length))}',
                      if (rate != null) '${(rate*100).toStringAsFixed(2)}%',
                      if (date != null) '${date.day}/${date.month}/${date.year}',
                    ].join(' · ')),
                    trailing: Text(_cup(value),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  );
                }).toList(),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Los viajes de otros conductores generan comisiones comerciales '
                  'cuando se liquidan. Tus propios viajes pueden tener una comisión reducida.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      )),
        ),
      ),
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
  final _cache = MarketplacePromoArtworkCache(Hive.box(_metaBox));
  late final String? _actor;
  StreamSubscription<AuthState>? _auth;
  bool _busy = true, _enabled = false;
  bool _sharing = false, _identityVerified = false;
  bool _applicationLoading = true, _applicationSubmitting = false;
  bool _applicationDocumentsReady = false, _applicationVerified = false;
  bool _acceptImpulsaRules = false, _acceptPublicProfile = false, _acceptPhoto = false;
  String _applicationStatus = 'not_requested';
  String? _applicationError;
  int _applicationRevision = 0;
  String? _error, _code, _photoAssetId, _alias;
  Uint8List? _squareBytes, _storyBytes, _printBytes;
  int _revision = 0;
  int _earningsRevision = 0;
  MarketplaceImpulsaEarnings? _earnings;
  bool _earningsBusy = false, _earningsUnavailable = false;
  Map<String, dynamic>? _withdrawalAccount;
  bool _withdrawalLoading = false, _withdrawalRequestBusy = false;
  String? _withdrawalError, _withdrawalRequestKey;
  num? _withdrawalRequestAmount;
  int _withdrawalRevision = 0;
  bool get _sameUser => _actor != null && _client.auth.currentUser?.id == _actor;
  Uint8List? _artworkFor(bool story) => story ? _storyBytes : _squareBytes;
  String _fileNameFor(bool story) => story ? 'Impulsa-historia.png' : 'Impulsa-cuadrada.png';
  // Compartir es libre: ningún canal o campaña se pide al conductor.
  String? get _taggedLink => _code == null
      ? null : marketplaceDriverPromoUri(_code!, alias: _alias).toString();
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
        params: {'target_action': action, 'target_channel': 'unknown',
          'target_campaign': null})
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
          _withdrawalRevision++; _withdrawalAccount = null;
          _withdrawalError = null; _withdrawalRequestKey = null;
          _withdrawalRequestAmount = null; _withdrawalLoading = false; _withdrawalRequestBusy = false;
          _squareBytes = null; _storyBytes = null; _printBytes = null;
          _applicationRevision++;
          _applicationStatus = 'not_requested';
          _applicationLoading = false;
          _applicationVerified = false;
          _applicationDocumentsReady = false;
          _applicationError = null;
          _error = 'Inicia sesión nuevamente para abrir Impulsa.';
        });
      }
    });
    unawaited(_load());
    unawaited(_loadApplication());
    unawaited(_loadEarnings());
    unawaited(_loadWithdrawalAccount());
  }

  @override
  void dispose() {
    _revision++; _earningsRevision++; _applicationRevision++; _withdrawalRevision++;
    _auth?.cancel();
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadApplication() async {
    if (!_sameUser || !mounted) return;
    final revision = ++_applicationRevision;
    setState(() { _applicationLoading = true; _applicationError = null; });
    try {
      final response = await _client.rpc('get_my_marketplace_impulsa_application_v1')
        .timeout(const Duration(seconds: 12));
      if (!mounted || !_sameUser || revision != _applicationRevision) return;
      if (response is! Map) throw const FormatException('IMPULSA_APPLICATION_INVALID');
      setState(() {
        _applicationStatus = response['status']?.toString() ?? 'not_requested';
        _applicationDocumentsReady = response['documents_ready'] == true;
        _applicationVerified = response['verified'] == true;
      });
    } catch (_) {
      if (mounted && _sameUser && revision == _applicationRevision) {
        setState(() {
          _applicationError = 'No se pudo consultar la solicitud. Comprueba tu conexión o inténtalo después.';
        });
      }
    } finally {
      if (mounted && _sameUser && revision == _applicationRevision) {
        setState(() => _applicationLoading = false);
      }
    }
  }

  Future<void> _submitImpulsaRequest() async {
    if (_applicationSubmitting || !_sameUser || !_applicationDocumentsReady ||
        !_acceptImpulsaRules || !_acceptPublicProfile || !_acceptPhoto) {
      return;
    }
    setState(() { _applicationSubmitting = true; _applicationError = null; });
    try {
      final result = await _client.rpc('request_my_marketplace_impulsa_verification_v1',
        params: {
          'target_accept_terms': true,
          'target_authorize_public_profile': true,
          'target_authorize_photo': true,
        }).timeout(const Duration(seconds: 15));
      if (!mounted || !_sameUser) return;
      if (result is! Map || result['status'] != 'pending') {
        throw const FormatException('IMPULSA_APPLICATION_NOT_PENDING');
      }
      setState(() {
        _applicationStatus = 'pending';
        _acceptImpulsaRules = false;
        _acceptPublicProfile = false;
        _acceptPhoto = false;
      });
      await _loadApplication();
    } catch (_) {
      if (mounted && _sameUser) {
        setState(() => _applicationError =
          'No se pudo enviar la solicitud. Verifica tus documentos y vuelve a intentarlo.');
      }
    } finally {
      if (mounted && _sameUser) setState(() => _applicationSubmitting = false);
    }
  }

  Future<void> _withdrawImpulsaRequest() async {
    if (!_sameUser || _applicationStatus != 'pending' || _applicationSubmitting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Retirar solicitud?'),
        content: const Text('La Agencia no podrá aprobarla. Podrás solicitar nuevamente la verificación cuando quieras.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Retirar solicitud')),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_sameUser) return;
    setState(() { _applicationSubmitting = true; _applicationError = null; });
    try {
      await _client.rpc('withdraw_my_marketplace_impulsa_application_v1')
        .timeout(const Duration(seconds: 12));
      if (!mounted || !_sameUser) return;
      await _loadApplication();
    } catch (_) {
      if (mounted && _sameUser) {
        setState(() => _applicationError = 'No se pudo retirar la solicitud. Vuelve a intentarlo.');
      }
    } finally {
      if (mounted && _sameUser) setState(() => _applicationSubmitting = false);
    }
  }

  Future<void> _openMyDocuments() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Documentos del conductor')),
        body: MarketplaceOnboardingScreen(store: widget.store, driverOnly: true),
      ),
    ));
    if (mounted && _sameUser) await _loadApplication();
  }

  Widget _impulsaVerification() {
    final verified = _identityVerified || _applicationVerified;
    final pending = _applicationStatus == 'pending';
    final approved = _applicationStatus == 'approved';
    final active = _enabled && verified;
    final color = verified ? const Color(0xFF1D9BF0)
      : pending ? const Color(0xFFE5A84E) : appMutedColor(context);
    final statusText = active ? 'Conductor verificado · Impulsa activo'
      : verified ? 'Identidad verificada · solicita tu activación Impulsa'
      : pending ? 'Verificación en revisión administrativa'
      : approved ? 'Solicitud aprobada · esperando activación'
      : _applicationStatus == 'rejected' ? 'Solicitud rechazada · puedes corregir y reenviar'
      : 'Solicita tu verificación';
    return Card(child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(verified ? Icons.verified_rounded : Icons.verified_outlined,
            color: color, size: 28),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Impulsa', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              Text(_applicationLoading && !active ? 'Consultando verificación…' : statusText,
                style: const TextStyle(fontSize: 12)),
            ])),
          IconButton(tooltip: 'Actualizar estado', onPressed: _applicationLoading || _applicationSubmitting
            ? null : () { unawaited(_loadApplication()); unawaited(_load(force: true)); },
            icon: const Icon(Icons.refresh)),
        ]),
        if (_applicationLoading && !active) const LinearProgressIndicator(),
        if (!active && !_applicationLoading && _applicationError != null)
          Padding(padding: const EdgeInsets.only(top: 8),
            child: Text(_applicationError!, style: const TextStyle(color: kDanger))),
        if (!active && !_applicationLoading && _applicationError == null &&
            !pending && !approved) ...[
          const SizedBox(height: 12),
          Text(verified
            ? 'Tu identidad está verificada. Para reactivar Impulsa debes autorizar de nuevo tu perfil y esperar la aprobación administrativa.'
            : 'Solicita tu incorporación a Impulsa. La insignia azul aparece únicamente cuando Administración comprueba y aprueba tu identidad.',
            style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          const ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Condiciones de verificación e Impulsa',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            children: [
              Text('La Agencia TukTuk comprobará personalmente tu identidad con los documentos registrados. La solicitud no es una verificación automática.',
                style: TextStyle(fontSize: 12)),
              SizedBox(height: 7),
              Text('Tras la aprobación, se podrá mostrar tu nombre público, foto autorizada, modalidad, servicios, enlace y QR para captar clientes.',
                style: TextStyle(fontSize: 12)),
              SizedBox(height: 7),
              Text('Los beneficios y comisiones comerciales se calcularán según las reglas vigentes de Impulsa para viajes reales. Puedes desactivar tu perfil promocional.',
                style: TextStyle(fontSize: 12)),
              SizedBox(height: 7),
              Text('Tu aceptación se registra con fecha y versión impulsa-self-service-v1. Puedes retirar una solicitud pendiente antes de que la Agencia la apruebe.',
                style: TextStyle(fontSize: 12)),
              SizedBox(height: 8),
            ],
          ),
          if (!_applicationDocumentsReady) ...[
            const Text('Para solicitarlo, registra las dos caras de tu carnet o licencia en tu expediente.',
              style: TextStyle(fontSize: 12)),
            TextButton.icon(onPressed: _openMyDocuments,
              icon: const Icon(Icons.badge_outlined),
              label: const Text('Completar documentos')),
          ] else ...[
            CheckboxListTile(
              key: const ValueKey('impulsa-accept-terms'),
              dense: true, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Acepto las condiciones de Impulsa y la revisión administrativa de mis documentos.'),
              value: _acceptImpulsaRules,
              onChanged: (v) => setState(() => _acceptImpulsaRules = v == true)),
            CheckboxListTile(
              key: const ValueKey('impulsa-consent-public'),
              dense: true, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Autorizo publicar mi nombre, modalidad, enlace y QR personal para que los clientes puedan solicitar mi servicio.'),
              value: _acceptPublicProfile,
              onChanged: (v) => setState(() => _acceptPublicProfile = v == true)),
            CheckboxListTile(
              key: const ValueKey('impulsa-consent-photo'),
              dense: true, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Autorizo publicar mi foto de perfil actual en mis tarjetas de Impulsa.'),
              value: _acceptPhoto,
              onChanged: (v) => setState(() => _acceptPhoto = v == true)),
            const Text('La solicitud se registra con fecha y versión de consentimiento. No garantiza aprobación; puedes desactivar tu perfil público posteriormente.',
              style: TextStyle(fontSize: 11)),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey('impulsa-request-verification'),
              onPressed: _applicationSubmitting || !_acceptImpulsaRules || !_acceptPublicProfile || !_acceptPhoto
                ? null : _submitImpulsaRequest,
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(_applicationSubmitting ? 'Enviando solicitud…' : 'Solicitar verificación')),
          ],
        ],
        if (pending && !_applicationLoading) ...[
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('Tu solicitud fue recibida. Administración revisará los documentos y tu autorización antes de activar las herramientas de Impulsa.',
              style: TextStyle(fontSize: 12))),
          Align(alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('impulsa-withdraw-request'),
              onPressed: _applicationSubmitting ? null : _withdrawImpulsaRequest,
              child: const Text('Retirar solicitud'))),
        ],
        if (approved && !active) const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text('La solicitud está aprobada; actualiza el estado. Si no aparecen tus tarjetas, contacta a la Agencia TukTuk.',
            style: TextStyle(fontSize: 12))),
      ])));
  }


  num? _safeMoney(Object? raw) {
    final value = raw is num ? raw : num.tryParse(raw?.toString() ?? '');
    return value != null && value.isFinite && value >= 0 ? value : null;
  }

  String _moneyCup(num value) => '${value.toStringAsFixed(2)} CUP';

  Future<void> _loadWithdrawalAccount() async {
    if (!mounted || !_sameUser) return;
    final revision = ++_withdrawalRevision;
    setState(() { _withdrawalLoading = true; _withdrawalError = null; });
    try {
      final response = await _client.rpc('get_my_marketplace_wallet_transition_v1')
        .timeout(const Duration(seconds: 12));
      if (!mounted || !_sameUser || revision != _withdrawalRevision) return;
      if (response is! Map || _safeMoney(response['impulsa_available']) == null ||
          _safeMoney(response['withdrawal_minimum_cup']) == null ||
          response['can_withdraw'] is! bool) {
        throw const FormatException('INVALID_IMPULSA_WITHDRAWALS');
      }
      setState(() => _withdrawalAccount = Map<String,dynamic>.from(response));
    } catch (_) {
      if (mounted && _sameUser && revision == _withdrawalRevision) {
        setState(() {
          _withdrawalAccount = null;
          _withdrawalError = 'No se pudo consultar el saldo retirable. Revisa tu conexión.';
        });
      }
    } finally {
      if (mounted && _sameUser && revision == _withdrawalRevision) {
        setState(() => _withdrawalLoading = false);
      }
    }
  }

  Future<void> _requestImpulsaWithdrawal() async {
    if (!mounted || !_sameUser || !_enabled || _withdrawalRequestBusy ||
        _withdrawalLoading) {
      return;
    }
    final data = _withdrawalAccount;
    final amount = _safeMoney(data?['impulsa_available']);
    final minimum = _safeMoney(data?['withdrawal_minimum_cup']);
    if (data == null || data['can_withdraw'] != true ||
        data['withdrawals_enabled'] != true || amount == null ||
        minimum == null || amount < minimum || amount <= 0) {
      return;
    }
    final roundedAmount = num.parse(amount.toStringAsFixed(2));
    if (roundedAmount < minimum || roundedAmount > 100000000) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Solicitar retiro de Impulsa'),
        content: Text('Solicitarás el retiro de ${_moneyCup(roundedAmount)} de tus ganancias comerciales disponibles. '
          'Las recargas y los bonos para trabajar no se pueden retirar. '
          'La Agencia TukTuk revisará la solicitud antes del pago.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Solicitar retiro')),
        ],
      ),
    );
    if (accepted != true || !mounted || !_sameUser) return;
    // Reuse the idempotency key while the previous response is uncertain.
    if (_withdrawalRequestKey == null || _withdrawalRequestAmount != roundedAmount) {
      _withdrawalRequestKey = _marketplaceUuid();
      _withdrawalRequestAmount = roundedAmount;
    }
    setState(() { _withdrawalRequestBusy = true; _withdrawalError = null; });
    try {
      final response = await _client.rpc('request_my_marketplace_impulsa_withdrawal_v1',
        params: {
          'target_amount': roundedAmount,
          'target_key': _withdrawalRequestKey,
        }).timeout(const Duration(seconds: 18));
      if (!mounted || !_sameUser) return;
      if (response is! Map || response['status']?.toString() != 'requested') {
        throw const FormatException('IMPULSA_WITHDRAWAL_INVALID_RESPONSE');
      }
      _withdrawalRequestKey = null;
      _withdrawalRequestAmount = null;
      toast(context, 'Solicitud de retiro registrada. Consulta su estado en Impulsa.');
      await _loadWithdrawalAccount();
    } catch (_) {
      if (mounted && _sameUser) {
        setState(() => _withdrawalError =
          'No se pudo confirmar la solicitud. Consulta el historial antes de reintentar; no se generará una solicitud duplicada.');
      }
    } finally {
      if (mounted && _sameUser) setState(() => _withdrawalRequestBusy = false);
    }
  }

  Widget _impulsaWithdrawalPanel() {
    final values = _withdrawalAccount;
    final available = _safeMoney(values?['impulsa_available']);
    final minimum = _safeMoney(values?['withdrawal_minimum_cup']);
    final held = _safeMoney(values?['withdrawal_reserved']);
    final canWithdraw = _sameUser && _enabled && !_withdrawalLoading &&
      !_withdrawalRequestBusy && values?['can_withdraw'] == true &&
      values?['withdrawals_enabled'] == true &&
      available != null && minimum != null && available >= minimum;
    final history = values?['withdrawals'] is List
      ? (values!['withdrawals'] as List).whereType<Map>().take(8).toList()
      : <Map>[];

    const gold = Color(0xFFF2D18B);
    const mint = Color(0xFF63D9C5);
    const ink = Color(0xFFF0F7FA);
    final walletTheme = Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: mint,
        onPrimary: const Color(0xFF12343D),
        onSurface: ink,
        onSurfaceVariant: const Color(0xFFB9D2D8),
      ),
    );
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF23545A), Color(0xFF163744), Color(0xFF254A53)],
        ),
        border: Border.all(color: gold.withValues(alpha: .48)),
      ),
      child: Theme(
        data: walletTheme,
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: ink),
          child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.account_balance_wallet_outlined, color: gold),
          const SizedBox(width: 10),
          const Expanded(child: Text('Billetera Impulsa',
            style: TextStyle(color: gold, fontSize: 17, fontWeight: FontWeight.w800))),
          IconButton(
            tooltip: 'Actualizar saldo Impulsa',
            onPressed: _withdrawalLoading || _withdrawalRequestBusy
              ? null : _loadWithdrawalAccount,
            icon: const Icon(Icons.refresh, color: mint),
          ),
        ]),
        const SizedBox(height: 10),
        if (_withdrawalLoading) const LinearProgressIndicator(),
        if (values != null && available != null && minimum != null) ...[
          const Text('Disponible para retirar', style: TextStyle(fontSize: 12)),
          Text(_moneyCup(available),
            style: const TextStyle(color: gold, fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          Text('Mínimo para solicitar retiro: ${_moneyCup(minimum)}',
            style: const TextStyle(fontSize: 12)),
          if (minimum > 0) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: (available / minimum).clamp(0.0, 1.0).toDouble(),
              color: mint,
              backgroundColor: const Color(0xFF41616A),
              borderRadius: BorderRadius.circular(8),
            ),
          ],
          if (held != null && held > 0) ...[
            const SizedBox(height: 7),
            Text('Reservado en solicitudes: ${_moneyCup(held)}',
              style: const TextStyle(fontSize: 12)),
          ],
          const SizedBox(height: 9),
          if (values['ready'] != true || values['active'] != true ||
              values['withdrawals_enabled'] != true)
            const Text('Los retiros todavía no están habilitados.',
              style: TextStyle(fontSize: 12))
          else if (available < minimum)
            Text('Te faltan ${_moneyCup(minimum - available)} para llegar al mínimo.',
              style: const TextStyle(fontSize: 12))
          else if (!canWithdraw)
            const Text('No puedes solicitar el retiro ahora. Puede existir una deuda o un ajuste pendiente.',
              style: TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const ValueKey('impulsa-request-withdrawal'),
            style: FilledButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: const Color(0xFF18343D),
              disabledBackgroundColor: const Color(0xFF39535B),
              disabledForegroundColor: const Color(0xFFB0C1C6),
            ),
            onPressed: canWithdraw ? _requestImpulsaWithdrawal : null,
            icon: const Icon(Icons.payments_outlined),
            label: Text(_withdrawalRequestBusy ? 'Registrando solicitud…' : 'Solicitar retiro'),
          ),
          const SizedBox(height: 7),
          const Text('Solo ganancias comerciales. Nunca recargas ni bonos para trabajar.',
            style: TextStyle(fontSize: 11)),
          if (history.isNotEmpty) ...[
            const Divider(height: 20),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Historial de retiros'),
              children: history.map((entry) {
                final status = switch (entry['status']?.toString()) {
                  'requested' => 'Solicitada',
                  'paid' => 'Pagada',
                  'rejected' => 'Rechazada',
                  'cancelled' => 'Cancelada',
                  _ => 'En revisión',
                };
                final amount = _safeMoney(entry['amount']) ?? 0;
                return ListTile(
                  dense: true, title: Text(status),
                  trailing: Text(_moneyCup(amount)),
                );
              }).toList(),
            ),
          ],
        ] else if (!_withdrawalLoading && _withdrawalError == null)
          const Text('No se pudo consultar el saldo Impulsa.',
            style: TextStyle(fontSize: 12)),
        if (_withdrawalError != null) ...[
          const SizedBox(height: 6),
          Text(_withdrawalError!, style: const TextStyle(color: kDanger, fontSize: 12)),
        ],
      ]),
          ),
        ),
      ),
    );
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
      // Verified identity is required before any Impulsa tools are unlocked.
      final enabled = result['enabled'] == true && result['identity_verified'] == true;
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
          _ => 'No se pudo consultar tu perfil de Impulsa. Reintenta.',
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
        title: 'Impulsa', text: copy,
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
    final file = pdf ? 'Impulsa-presentacion-85x55.pdf'
      : 'Impulsa-presentacion-300dpi.png';
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
                        semanticLabel: 'Tarjeta Impulsa $label'),
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
          // En perfiles activos, la insignia aparece junto al nombre del conductor.
          if (!_enabled) ...[
            _impulsaVerification(),
            const SizedBox(height: 10),
          ],
          if (_sameUser && _enabled)
            _impulsaWithdrawalPanel(),
          if (_sameUser && _enabled && _earnings != null)
            _MarketplaceImpulsaEarningsCard(earnings: _earnings!, refresh: () => unawaited(_loadEarnings()), loading: _earningsBusy)
          else if (_sameUser && _enabled && _earningsBusy)
            const Padding(padding: EdgeInsets.only(bottom: 12), child: LinearProgressIndicator())
          else if (_sameUser && _enabled && _earningsUnavailable)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
              const Expanded(child: Text('Resultados comerciales aún no disponibles.', style: TextStyle(fontSize: 12))),
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

/// Public, consented artwork only. The same renderer is used by Impulsa.
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
