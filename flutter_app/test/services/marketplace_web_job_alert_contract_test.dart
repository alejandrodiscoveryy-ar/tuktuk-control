import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final jobs = File('lib/presentation/marketplace_jobs.dart').readAsStringSync();
  final push = File('lib/services/push_notification_service.dart').readAsStringSync();
  final webInterop =
      File('lib/services/web_foreground_notification_web.dart').readAsStringSync();
  final webIndex = File('web/index.html').readAsStringSync();
  final worker = File('web/firebase-messaging-sw.js').readAsStringSync();

  test('activar trabajo prepara audio mediante gesto; descansar lo desactiva', () {
    expect(jobs, contains('prepareMarketplaceWebJobAlertActivation()'));
    expect(jobs, contains('configureMarketplaceWebJobAlerts(acceptingJobs)'));
    expect(jobs, contains('vehicle?.acceptingJobs == true'));
    expect(jobs, contains('configureMarketplaceWebJobAlerts(false)'));
    expect(push, contains('setWebJobAlertEnabled(enabled)'));
    expect(webInterop, contains("@JS('tuktukSetJobAlertEnabled')"));
  });

  test('aviso audible web exige carrera valida y permiso para notificacion', () {
    expect(webIndex, contains('if (job && !jobAlertEnabled) return'));
    expect(webIndex, contains('soundForNewJob()'));
    expect(webIndex, contains('showOnScreen(body)'));
    expect(webIndex, contains('navigator.serviceWorker.ready'));
    expect(webIndex, contains('Notification.permission'));
    expect(webIndex, contains('recentJobs.set(marketplaceJobId, now)'));
  });

  test('service worker muestra aviso de carrera distinguible', () {
    expect(worker, contains("data.kind === 'marketplace_job_available'"));
    expect(worker, contains('requireInteraction: isJob'));
    expect(worker, contains('renotify: isJob'));
    expect(worker, contains('vibrate: isJob ? [250, 100, 250]'));
    expect(worker, contains('event.notification.close()'));
  });
}
