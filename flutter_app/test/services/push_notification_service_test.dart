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
}

class _PermissionRejected implements Exception {
  const _PermissionRejected();
}
