import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  _LocalNetworkBinding();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, dynamic>{} : true);

  test(
      'login y resume reintentan automáticamente y refrescan referidos y licencia',
      () async {
    final dir = await Directory.systemTemp.createTemp('referral-store-test-');
    Hive.init(dir.path);
    for (final name in [
      'daily_records',
      'maintenance_records',
      'meta',
      'sync_queue'
    ]) {
      await Hive.openBox<dynamic>(name);
    }
    final pending = HivePendingReferralCodeStore(Hive.box('meta'));
    await PendingReferralClaimController(pending).captureCode('TUK-AA01');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var claims = 0;
    var programReads = 0;
    var licenseReads = 0;
    final failed = Completer<void>();
    final refreshed = Completer<void>();
    server.listen((request) async {
      await utf8.decoder.bind(request).join();
      dynamic payload = [];
      final path = request.uri.path;
      if (path.endsWith('/claim_referral_code')) {
        claims++;
        if (claims == 1) {
          request.response.statusCode = 503;
          payload = {'message': 'temporary network failure', 'code': '503'};
          failed.complete();
        } else {
          payload = '55555555-5555-5555-5555-555555555555';
        }
      } else if (path.endsWith('/get_my_referral_program')) {
        programReads++;
        payload = {
          'enabled': true,
          'code': 'TUK-BB02',
          'referred_count': 1,
          'applied_days': 15
        };
      } else if (path.endsWith('/get_my_referrals')) {
        payload = [
          {
            'relationship_id': 'fixture',
            'name': 'Fixture',
            'status': 'rewarded',
            'reward_days': 15
          }
        ];
      } else if (path.endsWith('/profiles')) {
        payload = {
          'id': '33333333-3333-3333-3333-333333333333',
          'created_at': '2026-01-01'
        };
      } else if (path.endsWith('/licenses')) {
        licenseReads++;
        // Suspended avoids unrelated first-vehicle writes in this attribution test.
        payload = {
          'id': 'license',
          'status': 'suspended',
          'license_type': 'paid',
          'expires_at':
              claims > 1 ? '2030-01-16T00:00:00Z' : '2030-01-01T00:00:00Z'
        };
        if (claims > 1 && !refreshed.isCompleted) refreshed.complete();
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(payload));
      await request.response.close();
    });
    await Supabase.initialize(
        url: 'http://127.0.0.1:${server.port}',
        publishableKey: 'test-only',
        authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false,
            detectSessionInUri: false,
            localStorage: EmptyLocalStorage()));
    final store = RecordStore();
    addTearDown(() async {
      store.dispose();
      await Supabase.instance.dispose();
      await server.close(force: true);
      await Hive.close();
      await dir.delete(recursive: true);
    });
    final expiry =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000;
    String encode(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token = '${encode({'alg': 'none'})}.${encode({
          'exp': expiry,
          'sub': '33333333-3333-3333-3333-333333333333'
        })}.test';
    await Supabase.instance.client.auth.recoverSession(jsonEncode({
      'access_token': token,
      'refresh_token': 'test',
      'token_type': 'bearer',
      'expires_in': 3600,
      'expires_at': expiry,
      'user': {
        'id': '33333333-3333-3333-3333-333333333333',
        'app_metadata': {},
        'user_metadata': {},
        'aud': 'authenticated',
        'created_at': '2026-01-01T00:00:00Z'
      }
    }));
    await failed.future.timeout(const Duration(seconds: 10));
    // Wait until the failure is persisted, then resume while the retry is due.
    while (pending.failure == null) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await pending.saveFailure({
      'attempts': 1,
      'nextAttemptAt':
          DateTime.now().subtract(const Duration(seconds: 1)).toIso8601String()
    });
    store.handleAppResumed();
    store.handleAppResumed();
    await refreshed.future.timeout(const Duration(seconds: 10));
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (store.license.expiresAt != DateTime.utc(2030, 1, 16) &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(claims, 2);
    expect(pending.code, isNull);
    expect(programReads, greaterThan(0));
    expect(licenseReads, greaterThan(0));
    expect(store.referrals.single.status, ReferralEntryStatus.rewarded);
    expect(store.referralProgram?.appliedDays, 15);
    expect(store.license.expiresAt, DateTime.utc(2030, 1, 16));
  });
  test('RPC conserva la autorización original durante un cambio de cuenta',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = Completer<String?>();
    server.listen((request) async {
      await request.drain<void>();
      received.complete(request.headers.value(HttpHeaders.authorizationHeader));
      request.response.headers.contentType = ContentType.json;
      request.response
          .write(jsonEncode('55555555-5555-5555-5555-555555555555'));
      await request.response.close();
    });
    final client = SupabaseClient(
        'http://127.0.0.1:${server.port}', 'test-only',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });
    String session(String id) {
      final expiry =
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
              1000;
      String encode(Object value) =>
          base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      final token = '${encode({'alg': 'none'})}.${encode({
            'exp': expiry,
            'sub': id
          })}.test';
      return jsonEncode({
        'access_token': token,
        'refresh_token': 'test',
        'token_type': 'bearer',
        'expires_in': 3600,
        'expires_at': expiry,
        'user': {
          'id': id,
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z'
        }
      });
    }

    await client.auth.recoverSession(session('account-a'));
    final originalToken = client.auth.currentSession!.accessToken;
    final request =
        ReferralRemoteService(client).claim('TUK-AA01', userId: 'account-a');
    await client.auth.recoverSession(session('account-b'));
    await request;
    expect(await received.future, 'Bearer $originalToken');
    await expectLater(
        ReferralRemoteService(client).claim('TUK-AA01', userId: 'account-a'),
        throwsStateError);
  });
}

// This test uses only a loopback HTTP fixture, never a real Supabase project.
class _LocalNetworkBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}
