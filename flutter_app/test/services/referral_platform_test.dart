import 'dart:async';
import 'dart:io';

import 'package:control_tuk_tuk/main.dart';
import 'package:control_tuk_tuk/services/install_referrer_service.dart';
import 'package:control_tuk_tuk/services/referral_link_listener.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('com.alejandrocruz.tuktukcontrol/referrals');

  for (final status in [
    'service_unavailable',
    'service_disconnected',
    'platform_error'
  ]) {
    test('MethodChannel recupera $status y preserva ref de Google Play',
        () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getInstallReferrer');
        calls++;
        return calls == 1
            ? {'status': status}
            : {
                'status': 'ok',
                'installReferrer': 'utm_source=share&ref=tuk%2Dqc59'
              };
      });
      const service = AndroidInstallReferrerService();
      expect((await service.read()).isDefinitive, isFalse);
      final result = await service.read();
      expect(result.isDefinitive, isTrue);
      expect(parseInstallReferrerCode(result.installReferrer), 'TUK-QC59');
      messenger.setMockMethodCallHandler(channel, null);
    });
  }

  test('App Links captura arranque frío y enlace con app abierta', () async {
    const messages = MethodChannel('com.llfbandit.app_links/messages');
    const events = MethodChannel('com.llfbandit.app_links/events');
    const initial = 'https://www.vrixora.com/tuktuk/app/?ref=TUK-QC59';
    const live = 'https://www.vrixora.com/tuktuk?ref=PEDRO-7K4P';
    messenger.setMockMethodCallHandler(messages, (call) async {
      expect(call.method, 'getInitialLink');
      return initial;
    });
    messenger.setMockMethodCallHandler(events, (_) async => null);
    final received = <Uri>[];
    final delivered = Completer<void>();
    final listener = ReferralLinkListener(onUri: (uri) {
      received.add(uri);
      if (uri.toString() == live) delivered.complete();
    });
    await listener.start();
    expect(received.map((uri) => uri.toString()), [initial]);
    await messenger.handlePlatformMessage(events.name,
        const StandardMethodCodec().encodeSuccessEnvelope(live), (_) {});
    await delivered.future;
    expect(received.map((uri) => uri.queryParameters['ref']),
        ['TUK-QC59', 'PEDRO-7K4P']);
    await listener.dispose();
    messenger.setMockMethodCallHandler(messages, null);
    messenger.setMockMethodCallHandler(events, null);
  });

  test('Hive conserva captura antes de login, fallo, cuenta y reinicio',
      () async {
    final dir = await Directory.systemTemp.createTemp('referral-test-');
    Hive.init(dir.path);
    var box = await Hive.openBox<dynamic>('referral-test');
    var now = DateTime.utc(2026, 9, 7);
    var controller = PendingReferralClaimController(
        HivePendingReferralCodeStore(box),
        now: () => now);
    await controller.captureCode('TUK-QC59');
    expect(
        await controller.claimForUser(
            userId: 'a',
            claim: (_) async {
              throw TimeoutException('offline');
            }),
        PendingReferralClaimResult.failed);
    await box.close();
    box = await Hive.openBox<dynamic>('referral-test');
    controller = PendingReferralClaimController(
        HivePendingReferralCodeStore(box),
        now: () => now);
    var calls = 0;
    expect(
        await controller.claimForUser(
            userId: 'b',
            claim: (_) async {
              calls++;
            }),
        PendingReferralClaimResult.accountMismatch);
    now = now.add(const Duration(seconds: 5));
    expect(
        await controller.claimForUser(
            userId: 'a',
            claim: (_) async {
              calls++;
            }),
        PendingReferralClaimResult.success);
    expect(calls, 1);
    await controller.captureCode('TUK-QC59');
    expect(
        await controller.claimForUser(
            userId: 'a',
            claim: (_) async {
              calls++;
            }),
        PendingReferralClaimResult.alreadyAttempted);
    expect(calls, 1);
    await box.close();
    await dir.delete(recursive: true);
  });
}
