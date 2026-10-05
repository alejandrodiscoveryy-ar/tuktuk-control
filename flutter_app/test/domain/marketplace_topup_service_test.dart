import 'dart:convert';

import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('payment method parses flags, display name and ordering', () {
    final method = MarketplacePaymentMethod.fromMap({
      'code': 'custom',
      'name': 'Método remoto',
      'confirmation_mode': 'manual',
      'requires_reference': true,
      'sort_order': 12,
    });
    expect(method.code, 'custom');
    expect(method.name, 'Método remoto');
    expect(method.confirmationMode, 'manual');
    expect(method.requiresReference, isTrue);
    expect(method.sortOrder, 12);
    expect(
        MarketplacePaymentMethod.fromMap({'requires_reference': false})
            .requiresReference,
        isFalse);
  });

  test('topup parses numeric values, nullable fields and UTC dates', () {
    final topup = MarketplaceTopup.fromMap({
      'topup_id': 'topup-1',
      'amount': '125.50',
      'currency': 'CUP',
      'status': 'rejected',
      'method': 'custom',
      'method_name': 'Método remoto',
      'reference': ' ABC ',
      'rejection_reason': 'Referencia incorrecta',
      'requested_at': '2026-10-05T08:00:00-04:00',
      'rejected_at': '2026-10-05T13:00:00Z',
    });
    expect(topup.id, 'topup-1');
    expect(topup.amount, 125.5);
    expect(topup.currency, 'CUP');
    expect(topup.status, 'rejected');
    expect(topup.method, 'custom');
    expect(topup.methodName, 'Método remoto');
    expect(topup.reference, 'ABC');
    expect(topup.rejectionReason, 'Referencia incorrecta');
    expect(topup.requestedAt, DateTime.utc(2026, 10, 5, 12));
    expect(topup.rejectedAt, DateTime.utc(2026, 10, 5, 13));
    expect(topup.confirmedAt, isNull);
    final cash = MarketplaceTopup.fromMap({
      'amount': 2,
      'reference': null,
      'rejection_reason': null,
      'confirmed_at': '2026-10-05T14:00:00Z',
    });
    expect(cash.amount, 2);
    expect(cash.reference, isNull);
    expect(cash.rejectionReason, isNull);
    expect(cash.confirmedAt, DateTime.utc(2026, 10, 5, 14));
  });

  test('service calls exact RPC contracts, including optional history cursor',
      () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        final rpc = request.url.pathSegments.last;
        final Object response = switch (rpc) {
          'list_my_marketplace_payment_methods' => [
              {'code': 'later', 'sort_order': 5},
              {'code': 'first', 'sort_order': 1},
            ],
          'list_my_marketplace_topups' => [
              {'topup_id': 'recent', 'amount': '2.5'}
            ],
          'request_my_marketplace_topup' => {
              'topup_id': 'sent',
              'status': 'requested'
            },
          _ => throw StateError('Unexpected RPC $rpc'),
        };
        return http.Response(jsonEncode(response), 200, request: request,
            headers: {'content-type': 'application/json'});
      }),
    );
    addTearDown(client.dispose);
    final service = MarketplaceService(client);
    expect((await service.paymentMethods()).first.code, 'first');
    expect(requests.last.url.path,
        '/rest/v1/rpc/list_my_marketplace_payment_methods');
    expect((await service.topups()).single.amount, 2.5);
    expect(requests.last.url.path, '/rest/v1/rpc/list_my_marketplace_topups');
    expect(jsonDecode(requests.last.body), {
      'target_limit': 50,
      'target_before_requested_at': null,
      'target_before_topup_id': null,
    });
    final before = DateTime.parse('2026-10-05T08:00:00-04:00');
    await service.topups(
        limit: 10, beforeRequestedAt: before, beforeTopupId: 'cursor');
    expect(jsonDecode(requests.last.body), {
      'target_limit': 10,
      'target_before_requested_at': before.toUtc().toIso8601String(),
      'target_before_topup_id': 'cursor',
    });
    final sent = await service.requestTopup(
        amount: 2.5,
        method: 'custom',
        reference: 'REF',
        idempotencyKey: '792080ed-cfa2-41b8-8487-3267853fc944');
    expect(sent.id, 'sent');
    expect(sent.status, 'requested');
    expect(requests.last.url.path, '/rest/v1/rpc/request_my_marketplace_topup');
    expect(jsonDecode(requests.last.body), {
      'target_amount': 2.5,
      'target_method': 'custom',
      'target_reference': 'REF',
      'target_request_idempotency_key': '792080ed-cfa2-41b8-8487-3267853fc944',
    });
    expect(requests.every((request) => request.method == 'POST'), isTrue);
    expect(requests, hasLength(4));
  });
}
