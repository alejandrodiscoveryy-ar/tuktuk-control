import 'dart:js_interop';

@JS('tuktukShowForegroundNotification')
external void _showForegroundNotification(JSString title, JSString body);

void showWebForegroundNotification({
  required String title,
  required String body,
}) {
  try {
    _showForegroundNotification(title.toJS, body.toJS);
  } catch (_) {
    // Browser notification support is optional and cannot block the WebApp.
  }
}
