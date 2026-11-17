part of '../main.dart';

/// Horizontal premium card based on the approved Agencia TukTuk / Impulsa
/// presentation design. Every personal element is rendered at export time:
/// approved public name, authorized photo, verified badge, real QR and link.
/// No stock vehicle photo, fake rating, invented years or fabricated trip stats.
Future<Uint8List> renderMarketplaceDriverPrintCard({
  required String name, required String code, required String modality,
  String? alias, Uint8List? logoBytes, Uint8List? photoBytes,
  bool identityVerified = false,
}) async {
  // Validate the link before drawing anything. The same URL powers the QR.
  marketplaceDriverPromoUri(code, alias: alias);
  const width = 1004, height = 650;
  const navy = Color(0xFF061E57);
  const royal = Color(0xFF0564DC);
  const orange = Color(0xFFFF8509);
  const darkText = Color(0xFF09204C);
  const mutedText = Color(0xFF314B6E);
  ui.Image? icon, portrait;
  try {
    if (logoBytes != null) icon = await _promoDecode(logoBytes);
    if (photoBytes != null) portrait = await _promoDecode(photoBytes);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const full = Rect.fromLTWH(0, 0, 1004, 650);
    canvas.drawRect(full, Paint()..color = Colors.white);
    canvas.drawRect(full, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [navy, royal, Color(0xFF06419B)],
    ).createShader(full));

    // Delicate curved light-blue center, keeping the approved horizontal
    // composition and navy footer. No vehicle rendering anywhere.
    final body = Path()
      ..moveTo(0, 123)
      ..cubicTo(172, 182, 341, 140, 530, 107)
      ..cubicTo(695, 77, 835, 118, 1004, 170)
      ..lineTo(1004, 548)
      ..cubicTo(760, 588, 521, 579, 290, 542)
      ..cubicTo(166, 526, 73, 542, 0, 561)
      ..close();
    canvas.drawPath(body, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFFEAF5FF), Color(0xFFF8FBFF), Color(0xFFC9E7FF)],
    ).createShader(const Rect.fromLTWH(0, 110, 1004, 490)));
    final bottomLine = Path()..moveTo(0, 562)
      ..cubicTo(135, 520, 241, 532, 354, 547)
      ..cubicTo(566, 574, 791, 585, 1004, 548);
    canvas.drawPath(bottomLine, Paint()..color = const Color(0xFF27C6FF)
      ..style = PaintingStyle.stroke..strokeWidth = 6);

    // Agency identity: use the centrally configured real project icon,
    // never the obsolete Conductor brand asset or an invented car graphic.
    if (icon != null) _promoFitImage(canvas, icon,
      const Rect.fromLTWH(41, 24, 96, 93));
    _promoText(canvas, 'Agencia', icon == null ? 58 : 148, 24,
      icon == null ? 290 : 300, 27, Colors.white,
      lines: 1, minFontSize: 22, weight: FontWeight.w700);
    _promoText(canvas, 'TukTuk', icon == null ? 55 : 147, 52,
      icon == null ? 335 : 320, 49, Colors.white,
      lines: 1, minFontSize: 33, weight: FontWeight.w800);

    // The Impulsa mark occupies its own dedicated space: no duplicated
    // underlying image or overprinted brand artwork.
    _promoText(canvas, 'TukTuk', 548, 24, 214, 30, Colors.white,
      center: true, lines: 1, minFontSize: 24, weight: FontWeight.w800);
    final impulseBox = RRect.fromRectAndRadius(
      const Rect.fromLTWH(543, 64, 222, 58), const Radius.circular(22));
    canvas.drawRRect(impulseBox, Paint()..shader = const LinearGradient(
      colors: [Color(0xFFFFA821), orange, Color(0xFFFF6F00)],
    ).createShader(const Rect.fromLTWH(543, 64, 222, 58)));
    _promoText(canvas, 'Impulsa', 558, 71, 192, 39, Colors.white,
      center: true, lines: 1, minFontSize: 32, weight: FontWeight.w800);
    for (final d in [0.0, 13.0, 26.0]) {
      canvas.drawLine(Offset(780, 81 + d), Offset(824 - d * .7, 81 + d),
        Paint()..color = Colors.white.withValues(alpha: .88)
          ..strokeWidth = 3..strokeCap = StrokeCap.round);
    }
    if (identityVerified) {
      _promoText(canvas, 'Verificado', 841, 65, 140, 22, Colors.white,
        lines: 1, center: true, minFontSize: 18);
      canvas.drawCircle(const Offset(963, 48), 18,
        Paint()..color = const Color(0xFF1D9BF0));
      final tick = Path()..moveTo(955, 48)
        ..lineTo(961, 54)..lineTo(973, 41);
      canvas.drawPath(tick, Paint()..color = Colors.white
        ..strokeWidth = 4..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round..style = PaintingStyle.stroke);
    }

    // The actual driver portrait, used only when sharing is authorized.
    const photoCircle = Rect.fromLTWH(34, 191, 252, 252);
    canvas.drawCircle(photoCircle.center, 132,
      Paint()..color = Colors.white);
    canvas.drawCircle(photoCircle.center, 125,
      Paint()..color = const Color(0xFF0E6BCF));
    canvas.save();
    canvas.clipPath(Path()..addOval(photoCircle.deflate(9)));
    canvas.drawRect(photoCircle, Paint()..color = const Color(0xFF143D66));
    if (portrait != null) {
      _promoFitImage(canvas, portrait, photoCircle.deflate(9), cover: true);
    } else {
      // Neutral placeholder when no photograph has been authorized.
      canvas.drawCircle(const Offset(160, 278), 39,
        Paint()..color = const Color(0xFFBCD4EC));
      canvas.drawOval(const Rect.fromLTWH(75, 326, 169, 142),
        Paint()..color = const Color(0xFFBCD4EC));
    }
    canvas.restore();

    // Public name and the existing blue check, immediately after the last
    // visible line of the name. Never show a badge for unverified accounts.
    final publicName = name.trim();
    final painter = TextPainter(textDirection: ui.TextDirection.ltr,
      maxLines: 2, ellipsis: '…');
    var fontSize = 46.0;
    do {
      painter.text = TextSpan(text: publicName, style: TextStyle(
        color: darkText, fontSize: fontSize,
        fontFamily: 'ImpulsaMontserrat', fontWeight: FontWeight.w800,
        height: 1.08));
      painter.layout(maxWidth: identityVerified ? 347 : 378);
      if (painter.height <= 102 || fontSize <= 25) break;
      fontSize -= 2;
    } while (true);
    const nameTop = 220.0, nameLeft = 308.0;
    painter.paint(canvas, const Offset(nameLeft, nameTop));
    final nameBottom = nameTop + painter.height;
    if (identityVerified) {
      final line = painter.computeLineMetrics().last;
      final badgeCenter = Offset(
        nameLeft + line.left + line.width + 22,
        nameTop + line.baseline - line.ascent / 2);
      canvas.drawCircle(badgeCenter, 17,
        Paint()..color = const Color(0xFF1D9BF0));
      final mark = Path()
        ..moveTo(badgeCenter.dx - 8, badgeCenter.dy)
        ..lineTo(badgeCenter.dx - 2, badgeCenter.dy + 6)
        ..lineTo(badgeCenter.dx + 9, badgeCenter.dy - 8);
      canvas.drawPath(mark, Paint()..color = Colors.white
        ..style = PaintingStyle.stroke..strokeWidth = 4
        ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    }
    painter.dispose();

    _promoText(canvas,
      identityVerified ? 'Conductor verificado de la Agencia TukTuk'
        : 'Conductor de la Agencia TukTuk',
      310, nameBottom + 10, 375, 23, mutedText,
      lines: 2, minFontSize: 16, weight: FontWeight.w700);
    final modalityName = modality.split(' · ').first.trim();
    final modalityRect = const Rect.fromLTWH(310, 412, 360, 64);
    canvas.drawRRect(RRect.fromRectAndRadius(modalityRect,
      const Radius.circular(32)), Paint()..shader = const LinearGradient(
        colors: [Color(0xFF0B326D), Color(0xFF0566D2)],
      ).createShader(modalityRect));
    _promoText(canvas, 'Modalidad: ' + modalityName, 329, 427, 320, 35,
      Colors.white, lines: 1, minFontSize: 19,
      weight: FontWeight.w800);
    final serviceList = modality.split(' · ').skip(1).join(' · ');
    if (serviceList.isNotEmpty) {
      _promoText(canvas, serviceList, 318, 488, 358, 19, mutedText,
        lines: 1, minFontSize: 13);
    }
    // The visible link and QR always resolve to the identical URL.
    _promoText(canvas, marketplaceDriverPromoDisplayLink(code, alias: alias),
      314, 514, 359, 20, const Color(0xFF096CC7), lines: 1,
      minFontSize: 12, weight: FontWeight.w800);

    // Real QR, on the right where the vehicle appeared in the visual concept.
    // Maintain 4 modules of white quiet zone on every side. No center logo.
    const qrX = 727.0, qrY = 200.0, module = 5.0;
    final qr = marketplaceDriverPromoQr(code, alias: alias);
    final qrSize = (qr.moduleCount + 8) * module;
    final qrFrame = RRect.fromRectAndRadius(
      Rect.fromLTWH(qrX - 14, qrY - 14, qrSize + 28, qrSize + 28),
      const Radius.circular(23));
    canvas.drawRRect(qrFrame, Paint()..color = const Color(0xFF0864D1));
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(qrX - 7, qrY - 7, qrSize + 14, qrSize + 14),
      const Radius.circular(17)), Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(qrX, qrY, qrSize, qrSize),
      Paint()..color = Colors.white);
    final black = Paint()..color = Colors.black..isAntiAlias = false;
    for (var row = 0; row < qr.moduleCount; row++) {
      for (var col = 0; col < qr.moduleCount; col++) {
        if (qr.isDark(row, col)) {
          canvas.drawRect(Rect.fromLTWH(
            qrX + (col + 4) * module, qrY + (row + 4) * module,
            module, module), black);
        }
      }
    }
    final cta = const Rect.fromLTWH(707, 476, 284, 75);
    canvas.drawRRect(RRect.fromRectAndRadius(cta,
      const Radius.circular(30)), Paint()..color = const Color(0xFF064CB0));
    _promoText(canvas, 'Solicita mi servicio', 715, 485, 268, 25,
      Colors.white, center: true, minFontSize: 20, lines: 1);
    _promoText(canvas, 'desde este enlace', 715, 516, 268, 24,
      Colors.white, center: true, minFontSize: 18, lines: 1);

    _promoText(canvas, 'Agencia TukTuk', 55, 581, 350, 31,
      Colors.white, minFontSize: 26, lines: 1, weight: FontWeight.w800);
    _promoText(canvas, 'Tu conductor de confianza, a un toque.',
      442, 585, 520, 24, Colors.white,
      minFontSize: 17, lines: 1, center: true);

    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(width, height);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw StateError('PRINT_CARD_EXPORT_FAILED');
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  } finally {
    icon?.dispose();
    portrait?.dispose();
  }
}

/// Exactly-sized 85x55 mm single-page PDF. Lossless RGB stream ensures
/// QR modules remain crisp; no additional Flutter dependency required.
Uint8List marketplaceDriverPrintPdf(Uint8List png) {
  final decoded = img.decodePng(png);
  if (decoded == null || decoded.width != 1004 || decoded.height != 650) {
    throw ArgumentError('PRINT_CARD_DIMENSIONS_INVALID');
  }
  final rgb = decoded.convert(numChannels: 3).toUint8List();
  if (rgb.length != 1004 * 650 * 3) {
    throw StateError('PRINT_CARD_RGB_INVALID');
  }
  final out = BytesBuilder(copy: false);
  final positions = <int>[0];
  void write(String value) => out.add(ascii.encode(value));
  void begin(int index) {
    if (positions.length != index) throw StateError('PRINT_CARD_PDF_OBJECT_INVALID');
    positions.add(out.length);
    write('$index 0 obj\n');
  }
  void end() => write('\nendobj\n');
  write('%PDF-1.4\n');
  begin(1);
  write('<< /Type /Catalog /Pages 2 0 R >>');
  end();
  begin(2);
  write('<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
  end();
  begin(3);
  write('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 240.94488 155.90551] '
    '/Resources << /XObject << /Im0 4 0 R >> >> /Contents 5 0 R >>');
  end();
  begin(4);
  write('<< /Type /XObject /Subtype /Image /Width 1004 /Height 650 '
    '/ColorSpace /DeviceRGB /BitsPerComponent 8 /Length ${rgb.length} >>\nstream\n');
  out.add(rgb);
  write('\nendstream');
  end();
  begin(5);
  const commands = 'q\n240.94488 0 0 155.90551 0 0 cm\n/Im0 Do\nQ\n';
  write('<< /Length ${commands.length} >>\nstream\n${commands}endstream');
  end();
  final start = out.length;
  write('xref\n0 6\n0000000000 65535 f \n');
  for (final offset in positions.skip(1)) {
    write("${offset.toString().padLeft(10, '0')} 00000 n \n");
  }
  write('trailer\n<< /Root 1 0 R /Size 6 >>\nstartxref\n$start\n%%EOF\n');
  return out.takeBytes();
}
