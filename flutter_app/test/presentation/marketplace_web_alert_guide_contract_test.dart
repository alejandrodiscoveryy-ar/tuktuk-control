import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final jobs = File(
    'lib/presentation/marketplace_jobs.dart',
  ).readAsStringSync();
  final guide = File(
    'lib/presentation/marketplace_web_alert_setup.dart',
  ).readAsStringSync();
  final index = File('web/index.html').readAsStringSync();
  final interop = File(
    'lib/services/web_foreground_notification_web.dart',
  ).readAsStringSync();

  test('la guia recupera alertas antes de llamar al RPC de disponibilidad', () {
    expect(jobs, contains('MarketplaceWebAlertSetupDialog('));
    expect(jobs, contains('recheck: _checkWebJobAlerts'));
    expect(
      jobs,
      contains(
        'if (acceptingJobs && kIsWeb && !(await _verifyWebJobAlerts())) return;',
      ),
    );
    expect(guide, contains('Seguir descansando'));
    expect(guide, contains('Comprobar de nuevo'));
    expect(guide, contains('www.vrixora.com'));
    expect(guide, contains('Notificaciones'));
  });

  test(
    'sonido de prueba es voluntario y no certifica avisos en segundo plano',
    () {
      expect(guide, contains('Probar sonido'));
      expect(guide, contains('No garantiza avisos audibles'));
      expect(index, contains('window.tuktukPlayJobAlertSoundTest'));
      expect(interop, contains("@JS('tuktukPlayJobAlertSoundTest')"));
    },
  );
}
