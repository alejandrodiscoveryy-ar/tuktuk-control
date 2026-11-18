part of '../main.dart';

/// Fit the complete public name in the approved print-card name area.
/// Keep short names large; allow up to three lines and never use an ellipsis.
/// The same layout is exported to PNG and embedded losslessly in the PDF.
const _printNameWidth = 378.0;
const _printBadgeSize = 32.0;
const _printBadgeGap = 8.0;

/// Full public name, including last surname, must fit with its checkmark
/// on the final line. Only verified identities reserve checkmark space.
TextPainter marketplaceDriverPrintNameLayout(String name, {
  bool identityVerified = false,
}) {
  final painter = TextPainter(
    textDirection: ui.TextDirection.ltr, maxLines: 3);
  final publicName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
  var size = 46.0;
  while (true) {
    painter.text = TextSpan(text: publicName, style: TextStyle(
      color: const Color(0xFF172028), fontSize: size,
      fontFamily: 'ImpulsaMontserrat', fontWeight: FontWeight.w800,
      height: 1.08));
    painter.layout(maxWidth: _printNameWidth);
    final lines = painter.computeLineMetrics();
    final last = lines.isEmpty ? null : lines.last;
    final badgeFits = !identityVerified || (last != null &&
      last.left + last.width + _printBadgeGap + _printBadgeSize
        <= _printNameWidth);
    if (!painter.didExceedMaxLines && painter.height <= 124 && badgeFits) {
      return painter;
    }
    if (size <= 12) {
      painter.dispose();
      // Never silently cut a surname or paint a seal over the QR.
      throw StateError('PRINT_CARD_NAME_TOO_LONG');
    }
    size -= 1;
  }
}

/// Position the verified seal against the final surname, not the subtitle.
Offset marketplaceDriverPrintBadgeOffset(TextPainter painter) {
  final last = painter.computeLineMetrics().last;
  const nameLeft = 308.0, nameTop = 220.0;
  return Offset(nameLeft + last.left + last.width + _printBadgeGap,
    nameTop + last.baseline + last.ascent / 2 - _printBadgeSize / 2);
}

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
  // TukTuk Cliente palette: charcoal, white, gold, orange and mint.
  // Only the standard verified-identity badge remains blue.
  const charcoal = Color(0xFF050B10);
  const charcoalSoft = Color(0xFF172028);
  const gold = Color(0xFFE5A84E);
  const orange = Color(0xFFFF963E);
  const mint = Color(0xFF35D6A2);
  const mutedText = Color(0xFF46525B);
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
      colors: [charcoal, charcoalSoft, Color(0xFF09141C)],
    ).createShader(full));

    // Ivory center, curved composition and dark footer. No vehicle imagery.
    final body = ui.Path()
      ..moveTo(0, 123)
      ..cubicTo(172, 182, 341, 140, 530, 107)
      ..cubicTo(695, 77, 835, 118, 1004, 170)
      ..lineTo(1004, 548)
      ..cubicTo(760, 588, 521, 579, 290, 542)
      ..cubicTo(166, 526, 73, 542, 0, 561)
      ..close();
    canvas.drawPath(body, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFFF6F8F7), Colors.white, Color(0xFFFFF3E5)],
    ).createShader(const Rect.fromLTWH(0, 110, 1004, 490)));
    final bottomLine = ui.Path()..moveTo(0, 562)
      ..cubicTo(135, 520, 241, 532, 354, 547)
      ..cubicTo(566, 574, 791, 585, 1004, 548);
    canvas.drawPath(bottomLine, Paint()..color = orange
      ..style = PaintingStyle.stroke..strokeWidth = 6);

    // Keep the approved stacked identity: "Agencia" over the two-tone
    // "TUKTUK". Both color spans are in ONE text run, with no fixed gap.
    // The configured icon remains unchanged.
    if (icon != null) {
      _promoFitImage(canvas, icon, const Rect.fromLTWH(38, 25, 90, 88));
    }
    final brandLeft = icon == null ? 57.0 : 146.0;
    _promoText(canvas, 'Agencia', brandLeft + 2, 23, 310, 28,
      Colors.white, lines: 1, minFontSize: 22,
      weight: FontWeight.w700);
    final brandPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      text: const TextSpan(
        style: TextStyle(
          fontFamily: 'ImpulsaMontserrat',
          fontSize: 48, fontWeight: FontWeight.w800, height: 1.0),
        children: [
          TextSpan(text: 'TUK', style: TextStyle(color: Colors.white)),
          TextSpan(text: 'TUK', style: TextStyle(color: gold)),
        ],
      ),
    )..layout(maxWidth: 380);
    brandPainter.paint(canvas, Offset(brandLeft, 55));
    brandPainter.dispose();

    // Move the approved Impulsa mark into the former verification corner.
    // It has its own clear area: no overprinted emblem or duplicated label.
    canvas.drawLine(const Offset(719, 27), const Offset(719, 122),
      Paint()..color = gold.withValues(alpha: .65)..strokeWidth = 2.2);
    _promoText(canvas, 'TukTuk', 745, 24, 190, 30, Colors.white,
      center: true, lines: 1, minFontSize: 23, weight: FontWeight.w800);
    final impulseBox = RRect.fromRectAndRadius(
      const Rect.fromLTWH(745, 64, 208, 58), const Radius.circular(22));
    canvas.drawRRect(impulseBox, Paint()..shader = const LinearGradient(
      colors: [Color(0xFFFFAB35), orange, Color(0xFFFF7E1E)],
    ).createShader(const Rect.fromLTWH(745, 64, 208, 58)));
    _promoText(canvas, 'Impulsa', 754, 71, 187, 39, Colors.white,
      center: true, lines: 1, minFontSize: 31, weight: FontWeight.w800);
    for (final d in [0.0, 11.0, 22.0]) {
      canvas.drawLine(Offset(962, 77 + d), Offset(992 - d * .65, 77 + d),
        Paint()..color = mint..strokeWidth = 3..strokeCap = StrokeCap.round);
    }

    // The actual driver portrait, used only when sharing is authorized.
    const photoCircle = Rect.fromLTWH(34, 191, 252, 252);
    canvas.drawCircle(photoCircle.center, 132,
      Paint()..color = Colors.white);
    canvas.drawCircle(photoCircle.center, 125,
      Paint()..color = gold);
    canvas.save();
    canvas.clipPath(ui.Path()..addOval(photoCircle.deflate(9)));
    canvas.drawRect(photoCircle, Paint()..color = charcoalSoft);
    if (portrait != null) {
      _promoFitImage(canvas, portrait, photoCircle.deflate(9), cover: true);
    } else {
      // Neutral placeholder when no photograph has been authorized.
      canvas.drawCircle(const Offset(160, 278), 39,
        Paint()..color = const Color(0xFFC6CDC9));
      canvas.drawOval(const Rect.fromLTWH(75, 326, 169, 142),
        Paint()..color = const Color(0xFFC6CDC9));
    }
    canvas.restore();

    // Full name in up to three lines. Attach the blue verified seal
    // immediately after the last surname without overlapping the QR.
    const nameTop = 220.0, nameLeft = 308.0;
    final painter = marketplaceDriverPrintNameLayout(name,
      identityVerified: identityVerified);
    painter.paint(canvas, const Offset(nameLeft, nameTop));
    final nameBottom = nameTop + painter.height;
    if (identityVerified) {
      _promoVerifiedSeal(canvas, marketplaceDriverPrintBadgeOffset(painter),
        _printBadgeSize);
    }
    painter.dispose();

    final verificationTop = nameBottom + 8;
    _promoText(canvas,
      identityVerified ? 'Conductor verificado de la Agencia TukTuk'
        : 'Conductor de la Agencia TukTuk',
      310, verificationTop, 378, 23, mutedText,
      lines: 2, minFontSize: 16, weight: FontWeight.w700);
    final modalityName = modality.split(' · ').first.trim();
    const modalityRect = Rect.fromLTWH(310, 412, 360, 64);
    canvas.drawRRect(RRect.fromRectAndRadius(modalityRect,
      const Radius.circular(32)), Paint()..shader = const LinearGradient(
        colors: [charcoalSoft, charcoal],
      ).createShader(modalityRect));
    _promoText(canvas, 'Modalidad: $modalityName', 329, 427, 320, 35,
      Colors.white, lines: 1, minFontSize: 19,
      weight: FontWeight.w800);
    final serviceList = modality.split(' · ').skip(1).join(' · ');
    if (serviceList.isNotEmpty) {
      _promoText(canvas, serviceList, 318, 488, 358, 19, mutedText,
        lines: 1, minFontSize: 13);
    }
    // The visible link and QR always resolve to the identical URL.
    _promoText(canvas, marketplaceDriverPromoDisplayLink(code, alias: alias),
      314, 514, 359, 20, const Color(0xFF865006), lines: 1,
      minFontSize: 12, weight: FontWeight.w800);

    // Real QR, on the right where the vehicle appeared in the visual concept.
    // Maintain 4 modules of white quiet zone on every side. No center logo.
    const qrX = 727.0, qrY = 200.0, module = 5.0;
    final qr = marketplaceDriverPromoQr(code, alias: alias);
    final qrSize = (qr.moduleCount + 8) * module;
    final qrFrame = RRect.fromRectAndRadius(
      Rect.fromLTWH(qrX - 14, qrY - 14, qrSize + 28, qrSize + 28),
      const Radius.circular(23));
    canvas.drawRRect(qrFrame, Paint()..color = gold);
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
    const cta = Rect.fromLTWH(707, 476, 284, 75);
    canvas.drawRRect(RRect.fromRectAndRadius(cta,
      const Radius.circular(30)), Paint()..color = charcoal);
    _promoText(canvas, 'Solicita mi servicio', 715, 485, 268, 25,
      Colors.white, center: true, minFontSize: 20, lines: 1);
    _promoText(canvas, 'desde este enlace', 715, 516, 268, 24,
      Colors.white, center: true, minFontSize: 18, lines: 1);

    // Keep the footer clean: no repeated agency logo/wordmark.
    _promoText(canvas, 'Tu conductor de confianza, a un toque.',
      80, 584, 844, 25, Colors.white,
      minFontSize: 18, lines: 1, center: true);

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
