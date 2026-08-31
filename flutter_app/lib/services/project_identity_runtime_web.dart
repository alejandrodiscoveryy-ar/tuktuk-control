import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('document')
external JSObject get _document;

void applyProjectIdentityToPlatform({
  required String name,
  String? iconUrl,
}) {
  try {
    _document.setProperty('title'.toJS, name.toJS);
    if (iconUrl == null || iconUrl.isEmpty) return;
    final favicon = _document.callMethod<JSObject?>(
      'querySelector'.toJS,
      'link[rel~="icon"]'.toJS,
    );
    favicon?.setProperty('href'.toJS, iconUrl.toJS);
  } catch (_) {
    // La identidad web dinámica nunca debe impedir el inicio de la WebApp.
  }
}
