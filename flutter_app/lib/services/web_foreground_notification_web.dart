import 'dart:js_interop';

@JS('tuktukShowForegroundNotification')
external void _showForegroundNotification(
  JSString title,
  JSString body,
  JSString? marketplaceJobId,
);

@JS('tuktukSetJobAlertEnabled')
external void _setJobAlertEnabled(JSBoolean enabled);

@JS('tuktukPrepareJobAlertFromGesture')
external void _prepareJobAlertFromGesture();

void setWebJobAlertEnabled(bool enabled) {
  try {
    _setJobAlertEnabled(enabled.toJS);
  } catch (_) {}
}

void prepareWebJobAlertFromGesture() {
  try {
    _prepareJobAlertFromGesture();
  } catch (_) {}
}

void showWebForegroundNotification({
  required String title,
  required String body,
  String? marketplaceJobId,
}) {
  try {
    _showForegroundNotification(title.toJS, body.toJS, marketplaceJobId?.toJS);
  } catch (_) {
    // Browser notification support is optional and cannot block the WebApp.
  }
}
