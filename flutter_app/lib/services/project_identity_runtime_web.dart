import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('document')
external JSObject get _document;

@JS('tuktukApplyStartupIcon')
external void _tuktukApplyStartupIcon(JSString iconUrl);

void applyProjectIdentityToPlatform({
  required String name,
  String? iconUrl,
  bool clearMissingIcon = false,
}) {
  try {
    _document.setProperty('title'.toJS, name.toJS);
    if (iconUrl != null && iconUrl.isNotEmpty || clearMissingIcon) {
      _tuktukApplyStartupIcon((iconUrl ?? '').toJS);
    }
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

@JS('tuktukFinishStartup')
external void _tuktukFinishStartup();

/// Muestra Flutter solamente cuando la autorización inicial ya se resolvió.
/// La función JS es idempotente y no altera autenticación ni notificaciones.
void finishTuktukWebStartup() {
  try {
    _tuktukFinishStartup();
  } catch (_) {
    // La integración de inicio no debe bloquear Flutter si no existe el shell.
  }
}
