import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

bool downloadPromoPng(Uint8List bytes, String name) {
  try {
    final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes], 'image/png'));
    final link = html.AnchorElement(href: url)..download = name;
    html.document.body?.append(link);
    link.click();
    link.remove();
    Timer(const Duration(seconds: 2), () => html.Url.revokeObjectUrl(url));
    return true;
  } catch (_) {
    return false;
  }
}
