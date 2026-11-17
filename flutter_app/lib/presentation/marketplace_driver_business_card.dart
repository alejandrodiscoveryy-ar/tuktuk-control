part of '../main.dart';

/// Minimal one-sided 85 x 55 mm business card at 300 dpi (1004x650 px).
/// No vehicle illustrations, private contact details or heavy ink coverage.
Future<Uint8List> renderMarketplaceDriverPrintCard({
  required String name, required String code, required String modality,
  String? alias, Uint8List? logoBytes, bool identityVerified = false,
}) async {
  marketplaceDriverPromoUri(code, alias: alias);
  const width = 1004, height = 650;
  const ink = Color(0xFF182531), secondary = Color(0xFF465564);
  const cyan = Color(0xFF069EB3);
  ui.Image? icon;
  try {
    if (logoBytes != null) icon = await _promoDecode(logoBytes);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.white, BlendMode.src);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1004, 7),
      Paint()..color = cyan);
    if (icon != null) {
      _promoFitImage(canvas, icon, const Rect.fromLTWH(62, 39, 77, 77));
    }
    _promoText(canvas, 'AGENCIA TUKTUK', icon == null ? 61 : 157, 46,
      icon == null ? 630 : 535, 39, ink, lines: 1,
      weight: FontWeight.w800, minFontSize: 28);
    _promoText(canvas,
      identityVerified ? 'Conductor verificado' : 'Servicio de transporte',
      icon == null ? 61 : 157, 99, 550, 23, secondary, lines: 1,
      minFontSize: 17);
    canvas.drawLine(const Offset(59, 167), const Offset(943, 167),
      Paint()..color = const Color(0xFFD9E1E5)..strokeWidth = 2);
    _promoText(canvas, name.trim(), 60, 215, 575, 55, ink,
      lines: 2, minFontSize: 25, weight: FontWeight.w800);
    _promoText(canvas, modality.split(' · ').first.trim(), 60, 350,
      570, 32, secondary, lines: 1, minFontSize: 24);
    _promoText(canvas, 'Solicita mi servicio', 60, 426,
      565, 30, ink, lines: 1, minFontSize: 23);
    _promoText(canvas, marketplaceDriverPromoDisplayLink(code, alias: alias),
      60, 479, 575, 27, cyan, lines: 1, minFontSize: 14,
      weight: FontWeight.w800);
    final qr = marketplaceDriverPromoQr(code, alias: alias);
    const module = 6.0, qrX = 674.0, qrY = 217.0;
    canvas.drawRect(Rect.fromLTWH(qrX, qrY,
      (qr.moduleCount + 8) * module, (qr.moduleCount + 8) * module),
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
    _promoText(canvas, 'ESCANEA Y SOLICITA', 669, 536, 309, 20,
      secondary, center: true, lines: 1, minFontSize: 16);
    canvas.drawLine(const Offset(59, 572), const Offset(943, 572),
      Paint()..color = const Color(0xFFE7ECEE)..strokeWidth = 2);
    _promoText(canvas, 'Tu conductor de confianza, a un toque.',
      60, 592, 885, 20, secondary, lines: 1, minFontSize: 16);
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
