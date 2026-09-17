import 'dart:js_interop';

@JS('tuktukShowForegroundNotification')
external void _showForegroundNotification(
  JSString title,
  JSString body,
  JSString? marketplaceJobId,
);

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
