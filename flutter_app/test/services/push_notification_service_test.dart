import 'package:control_tuk_tuk/services/push_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('permiso rechazado no interrumpe el inicio de la aplicación', () async {
    await expectLater(
      requestPushPermissionSafely(() async {
        throw const _PermissionRejected();
      }),
      completes,
    );
  });

  test('token web usa VAPID y service worker bajo la base actual', () async {
    String? capturedVapidKey;
    String? capturedServiceWorkerScriptPath;

    final token = await getPushTokenSafely(
      isWeb: true,
      getToken: ({vapidKey, serviceWorkerScriptPath}) async {
        capturedVapidKey = vapidKey;
        capturedServiceWorkerScriptPath = serviceWorkerScriptPath;
        return 'web-token';
      },
    );

    expect(token, 'web-token');
    expect(capturedVapidKey, tuktukWebVapidKey);
    expect(capturedServiceWorkerScriptPath, 'firebase-messaging-sw.js');
  });

  test('fallo al obtener token web no bloquea la aplicación', () async {
    final token = await getPushTokenSafely(
      isWeb: true,
      getToken: ({vapidKey, serviceWorkerScriptPath}) async {
        throw const _PermissionRejected();
      },
    );

    expect(token, isNull);
  });
}

class _PermissionRejected implements Exception {
  const _PermissionRejected();
}
