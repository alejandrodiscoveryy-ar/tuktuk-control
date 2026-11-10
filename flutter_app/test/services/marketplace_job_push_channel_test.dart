import 'package:control_tuk_tuk/services/push_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canales Android de aviso', () {
    const jobId = '123e4567-e89b-42d3-a456-426614174000';

    test('una nueva carrera válida selecciona canal V2', () {
      expect(
        notificationChannelForPush({
          'kind': 'marketplace_job_available',
          'job_id': jobId,
        }),
        tuktukJobNotificationChannelV2Id,
      );
    });

    test('otros avisos y carreras inválidas conservan canal general', () {
      expect(
        notificationChannelForPush({'kind': 'app_announcement'}),
        tuktukNotificationChannelId,
      );
      expect(
        notificationChannelForPush({
          'kind': 'marketplace_job_available',
          'job_id': 'invalido',
        }),
        tuktukNotificationChannelId,
      );
    });
  });
}
