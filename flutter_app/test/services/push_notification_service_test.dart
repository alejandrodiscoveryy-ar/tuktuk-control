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

  test('app_update usa action_url cuando está disponible', () async {
    Uri? openedUri;

    await openPushMessageAction(
      const {
        'kind': 'app_update',
        'action_url': 'https://play.google.com/store/apps/details?id=custom',
      },
      launcher: (uri) async {
        openedUri = uri;
        return true;
      },
    );

    expect(
      openedUri,
      Uri.parse('https://play.google.com/store/apps/details?id=custom'),
    );
  });

  test('app_update sin action_url usa la ficha oficial como fallback',
      () async {
    Uri? openedUri;

    await openPushMessageAction(
      const {'kind': 'app_update'},
      launcher: (uri) async {
        openedUri = uri;
        return true;
      },
    );

    expect(openedUri, Uri.parse(tuktukGooglePlayUrl));
  });

  test('otros tipos de notificación conservan el comportamiento actual',
      () async {
    var launches = 0;

    for (final kind in [
      'daily_exchange_rate',
      'exchange_rate_update',
      'app_announcement',
    ]) {
      await openPushMessageAction(
        {'kind': kind, 'action_url': 'https://example.com'},
        launcher: (_) async {
          launches += 1;
          return true;
        },
      );
    }

    expect(launches, 0);
  });

  test('payload local conserva kind y action_url', () {
    const data = {
      'kind': 'app_update',
      'action_url': tuktukGooglePlayUrl,
      'title': 'Nueva versión',
    };

    final restored = decodePushMessageData(encodePushMessageData(data));

    expect(restored, data);
  });

  test('solo una oferta Marketplace con UUID válido abre Trabajos', () {
    expect(
      marketplaceJobIdFromPush(const {
        'kind': 'marketplace_job_available',
        'job_id': 'e3ba1a2d-6a1a-4e53-9042-679d7e0f9d46',
      }),
      'e3ba1a2d-6a1a-4e53-9042-679d7e0f9d46',
    );
    expect(
      marketplaceJobIdFromUrl(Uri.parse(
        'https://tuktuk.example/?marketplace_job_id=e3ba1a2d-6a1a-4e53-9042-679d7e0f9d46',
      )),
      'e3ba1a2d-6a1a-4e53-9042-679d7e0f9d46',
    );
    expect(
      marketplaceJobIdFromPush(const {
        'kind': 'marketplace_job_available',
        'job_id': 'https://evil.example',
      }),
      isNull,
    );
  });

  test('payload local inválido se ignora sin bloquear la aplicación', () {
    expect(decodePushMessageData('{invalid'), isEmpty);
  });

  test('la restauración de sesión conserva Trabajos desde una oferta válida', () {
    expect(
      appShellIndexAfterAuthentication(
        currentIndex: 2,
        marketplaceJobId: 'e3ba1a2d-6a1a-4e53-9042-679d7e0f9d46',
      ),
      2,
    );
    expect(
      appShellIndexAfterAuthentication(currentIndex: 2, marketplaceJobId: null),
      0,
    );
  });
}

class _PermissionRejected implements Exception {
  const _PermissionRejected();
}
