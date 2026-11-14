part of '../main.dart';

// Cropped car artwork from the approved campaign, local and reusable.
const _promoApprovedCarArtwork =
    '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'
    'iEIgKZ2gQhUKhuqEKCxVO1KEK1MX/9k=';

/// Same URL for the copy, PNG QR and customer entry. Never use a driver UUID.
Uri marketplaceDriverPromoUri(String code) {
  if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(code)) {
    throw ArgumentError('Invalid promotion code');
  }
  return Uri.https('www.vrixora.com', '/cliente/tuk/', {'conductor': code});
}

String marketplaceDriverPromoCopy(String name, String code, {bool identityVerified = false}) =>
    '¡Tu próximo viaje comienza conmigo!\n\n'
    'Soy $name, ${identityVerified ? 'conductor verificado' : 'conductor'} de la Agencia TukTuk.\n\n'
    'Solicita mi servicio desde este enlace:\n\n'
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
    FontWeight weight = FontWeight.w700, int lines = 2,
    double? minFontSize, double letterSpacing = 0, double? boxHeight, bool italic = false}) {
  final painter = TextPainter(
    textDirection: ui.TextDirection.ltr,
    textAlign: center ? TextAlign.center : TextAlign.left,
    maxLines: lines, ellipsis: '…',
  );
  var size = fontSize;
  while (true) {
    painter.text = TextSpan(text: value, style: TextStyle(color: color,
      fontSize: size, fontWeight: weight, height: 1.10,
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
  final badgeSize = identityVerified ? 76.0 : 0.0;
  final gap = identityVerified ? 16.0 : 0.0;
  final painter = TextPainter(textDirection: ui.TextDirection.ltr,
    textAlign: center ? TextAlign.center : TextAlign.left,
    maxLines: 2, ellipsis: '…');
  var size = fontSize;
  final available = area.width - badgeSize - gap;
  while (true) {
    painter.text = TextSpan(text: name, style: TextStyle(
      color: Colors.white, fontSize: size, fontWeight: FontWeight.w900,
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
    final origin = Offset(x + painter.width + gap, area.top + (size * 1.1 - badgeSize) / 2);
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(badgeSize / 32);
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
  final stroke = Paint()..color = accent.withValues(alpha: .40)
    ..style = PaintingStyle.stroke..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
  final detail = Paint()..color = accent.withValues(alpha: .24)
    ..style = PaintingStyle.stroke..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
  final fill = Paint()..shader = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [accent.withValues(alpha: .20), const Color(0xFF081D2B).withValues(alpha: .40)],
  ).createShader(const Rect.fromLTWH(0, 0, 600, 220));
  final glow = Paint()..shader = RadialGradient(colors: [
    accent.withValues(alpha: .13), accent.withValues(alpha: 0),
  ]).createShader(const Rect.fromLTWH(0, 0, 600, 220));
  canvas.drawRect(const Rect.fromLTWH(0, 0, 600, 220), glow);
  void wheel(double x, double y, double radius) {
    final center = Offset(x, y);
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF091827));
    canvas.drawCircle(center, radius, stroke);
    canvas.drawCircle(center, radius * .53, detail);
    canvas.drawCircle(center, radius * .13, Paint()..color = accent.withValues(alpha: .32));
  }
  void body(ui.Path path) {
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
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
  canvas.drawLine(const Offset(25, 213), const Offset(575, 213), detail);
  canvas.restore();
}

/// Renders the actual exported artwork, not a separate HTML QR or screenshot.
/// No photos or generated files are uploaded by this renderer.
Future<Uint8List> renderMarketplaceDriverPromoCard({
  required String name, required String code, required String modality,
  required bool story, Uint8List? photoBytes, Uint8List? logoBytes,
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
    final lime = Color.lerp(primary, const Color(0xFF84FF62), .90)!;
    // A campaign artwork, not an app screen: the dark stage, energetic
    // diagonal ribbons and a luminous portrait anchor the composition.
    canvas.drawRect(bounds, Paint()..shader = LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [background, const Color(0xFF031D2B),
        Color.lerp(background, primary, .27)!],
      stops: const [0, .56, 1],
    ).createShader(bounds));
    final glow = Rect.fromCircle(
      center: Offset(story ? 845 : 255, story ? 540 : 355),
      radius: story ? 670 : 560);
    canvas.drawRect(glow, Paint()..shader = RadialGradient(
      colors: [primary.withValues(alpha: .42), primary.withValues(alpha: 0)],
    ).createShader(glow));

    // The route-inspired strokes are ornamental, not representations of a
    // driver's real journey. They remain behind all foreground artwork.
    final sweepY = story ? 745.0 : 415.0;
    final ribbon = ui.Path()
      ..moveTo(-95, sweepY + 315)
      ..cubicTo(280, sweepY + 370, 660, sweepY - 280, 1175, sweepY - 190);
    canvas.drawPath(ribbon, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = story ? 115 : 95
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(colors: [
        primary.withValues(alpha: .02), primary.withValues(alpha: .19),
        lime.withValues(alpha: .10),
      ]).createShader(bounds));
    final route = ui.Path()
      ..moveTo(-60, sweepY + 360)
      ..cubicTo(290, sweepY + 402, 685, sweepY - 224, 1145, sweepY - 145);
    canvas.drawPath(route, Paint()
      ..style = PaintingStyle.stroke ..strokeWidth = 3
      ..color = accent.withValues(alpha: .38));
    final routeLight = ui.Path()
      ..moveTo(-60, sweepY + 385)
      ..cubicTo(310, sweepY + 430, 720, sweepY - 196, 1145, sweepY - 122);
    canvas.drawPath(routeLight, Paint()
      ..style = PaintingStyle.stroke ..strokeWidth = 2
      ..color = lime.withValues(alpha: .22));

    // Approved campaign composition: logo left, large agency wordmark,
    // circular portrait left, vehicle upper right, identity beneath it.
    // The taller format uses an expanded vertical rhythm, not stretched art.
    final headerY = story ? 85.0 : 42.0;
    final iconSize = story ? 135.0 : 112.0;
    if (logo != null) {
      _promoFitImage(canvas, logo, Rect.fromLTWH(72, headerY, iconSize, iconSize));
      canvas.drawLine(Offset(72 + iconSize + 25, headerY + 8),
        Offset(72 + iconSize + 25, headerY + iconSize - 8),
        Paint()..color = accent.withValues(alpha: .65)..strokeWidth = 3);
    }
    final brandX = logo == null ? 72.0 : 72.0 + iconSize + 52;
    _promoText(canvas, 'Agencia TukTuk', brandX, headerY,
      1015 - brandX, story ? 63 : 59, white, lines: 1,
      weight: FontWeight.w900, minFontSize: 35, letterSpacing: -1.3,
      boxHeight: iconSize);
    final brandRule = Rect.fromLTWH(48, headerY + iconSize + 27, 984, 7);
    canvas.drawRRect(RRect.fromRectAndRadius(brandRule, const Radius.circular(4)),
      Paint()..shader = LinearGradient(colors: [
        lime, accent, white.withValues(alpha: .75), primary.withValues(alpha: .04),
      ], stops: const [0, .32, .51, 1]).createShader(brandRule));

    canvas.drawRRect(RRect.fromRectAndRadius(brandRule, const Radius.circular(4)),
      Paint()..color = accent.withValues(alpha: .65)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
    final vehicleArea = story
      ? const Rect.fromLTWH(500, 285, 650, 365)
      : const Rect.fromLTWH(520, 202, 570, 215);
    if (vehicleCategory == 'light_car') {
      // The original approved car illustration, with its edges faded into
      // the campaign background. The original personal portrait, badge,
      // wordmark and QR are NOT baked into this asset.
      final car = await _promoDecode(base64Decode(_promoApprovedCarArtwork));
      try {
        canvas.saveLayer(vehicleArea, Paint());
        _promoFitImage(canvas, car, vehicleArea, cover: true);
        canvas.drawRect(vehicleArea, Paint()..blendMode = BlendMode.dstIn
          ..shader = const LinearGradient(begin: Alignment.topCenter,
            end: Alignment.bottomCenter, colors: [Colors.transparent,
              Colors.white, Colors.white, Colors.transparent],
            stops: [0, .05, .82, 1]).createShader(vehicleArea));
        canvas.drawRect(vehicleArea, Paint()..blendMode = BlendMode.dstIn
          ..shader = const LinearGradient(colors: [Colors.transparent,
            Colors.white, Colors.white, Colors.transparent],
            stops: [0, .12, .92, 1]).createShader(vehicleArea));
        canvas.restore();
      } finally {
        car.dispose();
      }
    } else {
      _promoVehicleWatermark(canvas, vehicleCategory, vehicleArea, accent);
    }

    final photoRect = story
        ? const Rect.fromLTWH(65, 365, 400, 400)
        : const Rect.fromLTWH(66, 236, 350, 350);
    final photoRadius = photoRect.width / 2;
    final portraitGlow = Rect.fromCircle(center: photoRect.center, radius: photoRadius + 47);
    canvas.drawCircle(photoRect.center, photoRadius + 47,
      Paint()..shader = RadialGradient(colors: [
        accent.withValues(alpha: .52), primary.withValues(alpha: 0),
      ]).createShader(portraitGlow));
    canvas.drawCircle(photoRect.center, photoRadius + 14,
      Paint()..color = const Color(0xFF07121D));
    canvas.drawCircle(photoRect.center, photoRadius + 9,
      Paint()..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [accent, const Color(0xFF00E5FF), primary.withValues(alpha: .90)],
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

    final nameArea = story ? const Rect.fromLTWH(494, 570, 530, 145)
      : const Rect.fromLTWH(448, 330, 570, 100);
    final nameBottom = _promoVerifiedName(canvas, name, nameArea,
      fontSize: story ? 92 : 78, minFontSize: 32, center: false,
      identityVerified: identityVerified);
    final roleY = nameBottom + 10;
    _promoText(canvas, identityVerified ? 'Conductor verificado de la Agencia TukTuk'
      : 'Conductor de la Agencia TukTuk', nameArea.left, roleY,
      nameArea.width, story ? 35 : 29, white, lines: 2,
      weight: FontWeight.w600, minFontSize: 23);
    final identityRule = Rect.fromLTWH(nameArea.left, story ? 825 : 521, nameArea.width, 5);
    canvas.drawRRect(RRect.fromRectAndRadius(identityRule, const Radius.circular(3)),
      Paint()..shader = LinearGradient(colors: [lime, accent,
        accent.withValues(alpha: 0)]).createShader(identityRule));

    final servicePill = story
      ? const Rect.fromLTWH(155, 935, 770, 108)
      : const Rect.fromLTWH(448, 540, 570, 65);
    final pill = RRect.fromRectAndRadius(servicePill, Radius.circular(servicePill.height / 2));
    canvas.drawRRect(pill, Paint()..color = accent.withValues(alpha: .50)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    canvas.drawRRect(pill, Paint()..shader = LinearGradient(
      colors: [lime.withValues(alpha: .66), accent.withValues(alpha: .19),
        const Color(0xFF0A2635)]).createShader(servicePill));
    canvas.drawRRect(pill, Paint()..style = PaintingStyle.stroke
      ..strokeWidth = 3 ..color = accent);
    final miniVehicle = Rect.fromLTWH(servicePill.left + 16,
      servicePill.center.dy - servicePill.height * .31,
      servicePill.height * 1.45, servicePill.height * .62);
    final modalityIcon = switch (vehicleCategory) {
      'motorcycle' => Icons.two_wheeler,
      'bicycle' || 'bicitaxi' => Icons.pedal_bike,
      'tricycle' => Icons.electric_rickshaw,
      'van' => Icons.airport_shuttle,
      'truck' => Icons.local_shipping,
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
      Paint()..color = accent..strokeWidth = 2);
    _promoText(canvas, modality, dividerX + 17,
      servicePill.top, servicePill.right - dividerX - 30,
      story ? 43 : 29, white, center: true, lines: 2, minFontSize: 23,
      boxHeight: servicePill.height, weight: FontWeight.w800);

    // Use the actual approved static campaign artwork, not a redrawing.
    // This local asset contains the original lettering, light effects,
    // pin, arrow and empty white QR well. No personal data or mock QR.
    final panel = story
      ? const Rect.fromLTWH(40, 1135, 1000, 430)
      : const Rect.fromLTWH(40, 620, 1000, 405);
    final bookingData = await rootBundle.load('assets/branding/tuktuk_promo_booking.webp');
    final bookingArt = await _promoDecode(bookingData.buffer.asUint8List(
      bookingData.offsetInBytes, bookingData.lengthInBytes));
    try {
      // Remove the rectangular exterior of the source artwork, preserving
      // the luminous rounded frame and its original typography.
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(panel.deflate(7), const Radius.circular(49)));
      canvas.drawImageRect(bookingArt, Rect.fromLTWH(0, 0,
        bookingArt.width.toDouble(), bookingArt.height.toDouble()), panel,
        Paint()..filterQuality = FilterQuality.high);
      canvas.restore();
    } finally {
      bookingArt.dispose();
    }

    // Overlay the real code in the center of the original white well.
    // Integer modules and four full white modules of quiet zone preserve
    // the scanner contract. The surrounding graphic is not resized with QR.
    final qr = marketplaceDriverPromoQr(code);
    const module = 6.0;
    final qrSize = (qr.moduleCount + 8) * module;
    const qrX = 686.0;
    final qrY = story ? 1194.0 : 668.0;
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
    final footerY = story ? 1690.0 : 1035.0;
    _promoText(canvas, 'Tu conductor de confianza, a un toque.', 120,
      footerY, 840, story ? 35 : 24, white,
      center: true, weight: FontWeight.w700, lines: 1, minFontSize: 20, italic: true);
    for (final x in [48.0, 980.0]) {
      final dash = Rect.fromLTWH(x, footerY + (story ? 21 : 14), 52, 5);
      canvas.drawRRect(RRect.fromRectAndRadius(dash, const Radius.circular(3)),
        Paint()..shader = LinearGradient(colors: [accent, white, accent]).createShader(dash));
    }
    if (story) {
      final lowerSweep = ui.Path()..moveTo(-40, 1900)
        ..cubicTo(280, 1670, 700, 1990, 1140, 1680);
      canvas.drawPath(lowerSweep, Paint()..style = PaintingStyle.stroke
        ..strokeWidth = 34..shader = LinearGradient(colors: [
          primary.withValues(alpha: .08), accent, primary.withValues(alpha: .35),
        ]).createShader(bounds));
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
const _marketplacePromoArtworkVersion = 11;
String marketplacePromoCacheFingerprint({
  required String actor, required String code, required String name,
  required String modality, required bool photoAuthorized,
  required Uri? photoUrl, required ProjectIdentity identity,
  Object? profileUpdatedAt,
  String? photoAssetId,
  bool identityVerified = false,
  String vehicleCategory = 'light_car',
}) => sha256.convert(utf8.encode(jsonEncode([
  _marketplacePromoArtworkVersion, actor, code, name, modality, photoAuthorized, identityVerified, vehicleCategory,
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
  String? _error, _code, _photoAssetId;
  Uint8List? _squareBytes, _storyBytes;
  int _revision = 0;
  bool get _sameUser => _actor != null && _client.auth.currentUser?.id == _actor;
  Uint8List? _artworkFor(bool story) => story ? _storyBytes : _squareBytes;
  String _fileNameFor(bool story) => story ? 'Mi-TukTuk-historia.png' : 'Mi-TukTuk.png';
  String? get _copy => _code == null ? null : marketplaceDriverPromoCopy(_name.text.trim(), _code!, identityVerified: _identityVerified);

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
        actor: actor, code: code, name: name, modality: modality,
        photoAuthorized: photoAuthorized, photoUrl: photoKey,
        identity: identity, photoAssetId: _photoAssetId,
        identityVerified: identityVerified, vehicleCategory: vehicleCategory,
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
      Uint8List? photo;
      if (photoAuthorized && photoPath != null) {
        final signed = await _client.storage.from('marketplace-media').createSignedUrl(photoPath, 120);
        photo = await downloadMarketplacePromoPortrait(Uri.parse(signed));
      }
      if (!mounted || !_sameUser || revision != _revision) return;
      stage = 'tarjeta';
      final logo = await loadMarketplacePromoBrandLogo(identity);
      if (!mounted || !_sameUser || revision != _revision) return;
      final square = await renderMarketplaceDriverPromoCard(name: name, code: code, modality: modality, story: false, photoBytes: photo, logoBytes: logo, identity: identity, identityVerified: identityVerified, vehicleCategory: vehicleCategory);
      final story = await renderMarketplaceDriverPromoCard(name: name, code: code, modality: modality, story: true, photoBytes: photo, logoBytes: logo, identity: identity, identityVerified: identityVerified, vehicleCategory: vehicleCategory);
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
          const Text('Mi TukTuk', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Tu conductor de confianza, a un toque.', style: TextStyle(color: kMuted)),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: kDanger)),
            TextButton(onPressed: _busy ? null : _load, child: const Text('Reintentar')),
          ],
          if (!_enabled && !_busy && _error == null)
            const Text('Tu ficha estará disponible cuando la Agencia TukTuk verifique tu identidad y active Mi TukTuk desde Administración.'),
          if (_enabled) ...[
            const SizedBox(height: 12),
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
              const SizedBox(height: 8),
              Text('Compartir incluye la tarjeta elegida, tu mensaje y el enlace personal.',
                style: TextStyle(color: appMutedColor(context), fontSize: 12)),
            ],
            const SizedBox(height: 12),
            if (previewReady) ...[
              TextButton.icon(onPressed: () => _load(force: true),
                icon: const Icon(Icons.refresh), label: const Text('Actualizar tarjeta')),
              const SizedBox(height: 12),
              const Text('Tu enlace personal', style: TextStyle(fontWeight: FontWeight.w800)),
              SelectableText(marketplaceDriverPromoUri(_code!).toString()),
              TextButton.icon(onPressed: ready ? () => _copyText(marketplaceDriverPromoUri(_code!).toString()) : null,
                icon: const Icon(Icons.link), label: const Text('Copiar enlace')),
              const SizedBox(height: 8),
              const Text('Mensaje para compartir', style: TextStyle(fontWeight: FontWeight.w800)),
              SelectableText(copy),
              TextButton.icon(onPressed: ready ? () => _copyText(copy) : null, icon: const Icon(Icons.copy),
                label: const Text('Copiar mensaje')),
              const Text('Si tu red social no admite compartir imagen y texto juntos, descarga la tarjeta y pega el mensaje completo en tu publicación.', style: TextStyle(color: kMuted, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _busy || !_sameUser ? null : _revoke,
              child: const Text('Desactivar mi perfil público')),
          ],
        ]),
      )),
    ]);
  }
}
