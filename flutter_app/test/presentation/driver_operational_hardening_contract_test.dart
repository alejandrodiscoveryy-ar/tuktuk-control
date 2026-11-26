import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final jobs = File('lib/presentation/marketplace_jobs.dart').readAsStringSync();
  final push = File('lib/services/push_notification_service.dart').readAsStringSync();

  test('recovery reloads authoritative state without retrying mutations', () {
    final recovery = jobs.substring(
      jobs.indexOf('void _recoverAvailableWhileWorking()'),
      jobs.indexOf('void _alertRecoveredOffers('),
    );
    expect(recovery, contains('_busyJobId != null'));
    expect(recovery, contains('_acceptingJobId != null'));
    expect(recovery, contains('const Duration(seconds: 60)'));
    expect(recovery, contains('_load(refreshHistory: false)'));
    expect(recovery, contains('_scopeErrors.containsKey'));
    expect(recovery, isNot(contains('_setAcceptingJobs(')));
    expect(recovery, isNot(contains('_advanceJob(')));
  });

  test('GPS confirmation is scoped to the current driver and vehicle', () {
    expect(jobs, contains('generation != _operationalLocationStreamGeneration'));
    expect(jobs, contains('_operationalLocationVehicle()?.id != vehicle.id'));
    expect(jobs, contains('widget.store.user?.id != ownerId'));
  });

  test('Android recovered offers share notification identity with FCM', () {
    expect(jobs, contains('notifyMarketplaceRecoveredAndroidJob(job.id)'));
    expect(push, contains('_showAndroidOffer(message.data, title, body)'));
    expect(push, contains('id: jobId.hashCode & 0x7fffffff'));
    expect(push, contains('onlyAlertOnce: alreadyShown'));
    expect(push, contains('payload: encodePushMessageData(data)'));
  });

  test('ride assistance uses configured support and explicit confirmation', () {
    expect(jobs, contains('widget.store.supportWhatsAppAction()'));
    expect(jobs, contains('work-map-ride-assistance'));
    expect(jobs, contains('send != true'));
    expect(jobs, contains('No es un servicio de emergencias'));
  });
}
