import 'dart:async';
import 'dart:convert';

import 'package:control_tuk_tuk/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const methods = [
  {
    'code': 'cash',
    'name': 'Efectivo',
    'requires_reference': false,
    'sort_order': 1
  },
  {
    'code': 'remote_custom',
    'name': 'Método del servidor',
    'requires_reference': true,
    'sort_order': 2
  },
];

void main() {
  late SupabaseClient client;
  late MarketplaceService service;
  late List<Map<String, dynamic>> submissions;
  late Future<http.Response> Function() reply;
  late bool failMethods;

  setUp(() {
    submissions = [];
    failMethods = false;
    reply = () async => http.Response(
        jsonEncode({'topup_id': 'id', 'status': 'requested'}), 200);
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('list_my_marketplace_payment_methods')) {
          if (failMethods) throw Exception('network unavailable');
          return http.Response(jsonEncode(methods), 200, request: request);
        }
        expect(request.url.path, '/rest/v1/rpc/request_my_marketplace_topup');
        submissions
            .add(Map<String, dynamic>.from(jsonDecode(request.body) as Map));
        final response = await reply();
        return http.Response(response.body, response.statusCode,
            headers: response.headers, request: request);
      }),
    );
    service = MarketplaceService(client);
  });
  tearDown(() async => client.dispose());

  Future<void> openForm(WidgetTester tester,
      {Map<String, String>? keys}) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            isDismissible: false,
            enableDrag: false,
            builder: (_) =>
                MarketplaceTopupForm(service: service, requestKeys: keys)),
        child: const Text('Abrir'),
      ),
    ))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String label) async {
    await tester
        .tap(find.byType(DropdownButtonFormField<MarketplacePaymentMethod>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Solicitar recarga'));
    await tester.tap(find.text('Solicitar recarga'));
    await tester.pumpAndSettle();
  }

  testWidgets('rejects missing method and nonpositive or nonfinite amounts',
      (tester) async {
    await openForm(tester);
    await submit(tester);
    expect(find.text('Selecciona un método de pago.'), findsOneWidget);
    await choose(tester, 'Efectivo');
    for (final amount in ['', '0', '-1', 'NaN', 'Infinity']) {
      await tester.enterText(find.byType(TextFormField).first, amount);
      await submit(tester);
      expect(find.text('Introduce un importe mayor que cero.'), findsOneWidget);
    }
    expect(submissions, isEmpty);
  });

  testWidgets('server flag requires reference and accepts a dynamic method',
      (tester) async {
    await openForm(tester);
    await tester.enterText(find.byType(TextFormField).first, '0,50');
    await choose(tester, 'Método del servidor');
    await submit(tester);
    expect(find.text('Debes indicar la referencia de esta operación.'),
        findsOneWidget);
    expect(submissions, isEmpty);
    await tester.enterText(find.byType(TextFormField).last, ' REF-1 ');
    await submit(tester);
    expect(submissions.single['target_amount'], 0.5);
    expect(submissions.single['target_method'], 'remote_custom');
    expect(submissions.single['target_reference'], 'REF-1');
    expect(find.byType(MarketplaceTopupForm), findsNothing);
  });

  testWidgets('cash needs no reference; duplicate taps and retry keep one UUID',
      (tester) async {
    final pending = Completer<http.Response>();
    reply = () => pending.future;
    await openForm(tester);
    await tester.enterText(find.byType(TextFormField).first, '10');
    await choose(tester, 'Efectivo');
    expect(find.byType(TextFormField), findsOneWidget);
    await tester.tap(find.text('Solicitar recarga'));
    await tester.tap(find.text('Solicitar recarga'));
    await tester.pump();
    expect(submissions, hasLength(1));
    expect(submissions.single['target_reference'], isNull);
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancelar'))
            .onPressed,
        isNull);
    expect(tester.widget<PopScope>(find.byType(PopScope).last).canPop, isFalse);
    pending.completeError(Exception('connection lost after server commit'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'No pudimos enviar la solicitud de recarga. Inténtalo nuevamente.'),
        findsOneWidget);
    reply = () async =>
        http.Response('{"topup_id":"same","status":"requested"}', 200);
    await submit(tester);
    expect(submissions, hasLength(2));
    expect(submissions[0], submissions[1]);
    expect(
        submissions[0]['target_request_idempotency_key'],
        matches(RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    expect(find.byType(MarketplaceTopupForm), findsNothing);
  });

  testWidgets('uncertain request retains key when reopening the wallet form',
      (tester) async {
    final keys = <String, String>{};
    reply = () async => throw Exception('offline');
    await openForm(tester, keys: keys);
    await tester.enterText(find.byType(TextFormField).first, '5');
    await choose(tester, 'Efectivo');
    await submit(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '5.0');
    await choose(tester, 'Efectivo');
    await submit(tester);
    expect(submissions[0], submissions[1]);
    await tester.enterText(find.byType(TextFormField).first, '6');
    await submit(tester);
    expect(submissions[2]['target_request_idempotency_key'],
        isNot(submissions[0]['target_request_idempotency_key']));
  });

  testWidgets('offline methods offer retry without sending a topup',
      (tester) async {
    failMethods = true;
    await openForm(tester);
    expect(
        find.text(
            'No pudimos cargar los métodos de pago. Revisa tu conexión y actualiza.'),
        findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    failMethods = false;
    await tester.tap(find.text('Actualizar métodos'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<MarketplacePaymentMethod>),
        findsOneWidget);
    expect(submissions, isEmpty);
  });

  test('status and technical errors use driver-facing Spanish', () {
    expect(marketplaceTopupStatusLabel('requested'), 'Pendiente');
    expect(marketplaceTopupStatusLabel('confirmed'), 'Confirmada');
    expect(marketplaceTopupStatusLabel('reconciled'), 'Confirmada');
    expect(marketplaceTopupStatusLabel('rejected'), 'Rechazada');
    const messages = {
      'TOPUP_AMOUNT_MUST_BE_POSITIVE': 'Introduce un importe mayor que cero.',
      'INVALID_TOPUP_METHOD':
          'Ese método de pago ya no está disponible. Actualiza e inténtalo nuevamente.',
      'TOPUP_REFERENCE_REQUIRED':
          'Debes indicar la referencia de esta operación.',
      'AUTHENTICATION_REQUIRED':
          'Tu sesión venció. Inicia sesión nuevamente para solicitar una recarga.',
      'PROFILE_NOT_FOUND':
          'Tu perfil no está disponible. Revisa tu perfil e inténtalo nuevamente.',
      'SQL secret details':
          'No pudimos enviar la solicitud de recarga. Inténtalo nuevamente.',
    };
    for (final entry in messages.entries) {
      expect(
          marketplaceTopupErrorMessage(
              PostgrestException(message: entry.key, code: '42501')),
          entry.value);
    }
  });

  testWidgets(
      'history renders empty state, reference, reason and reconciled status',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MarketplaceTopupHistory(topups: []))));
    expect(find.text('Aún no tienes recargas.'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MarketplaceTopupHistory(topups: [
      MarketplaceTopup.fromMap({
        'topup_id': '1',
        'amount': 25,
        'currency': 'CUP',
        'method_name': 'Efectivo',
        'status': 'reconciled',
        'requested_at': '2026-10-05T12:00:00Z'
      }),
      MarketplaceTopup.fromMap({
        'topup_id': '2',
        'amount': 10,
        'currency': 'CUP',
        'method_name': 'Método remoto',
        'status': 'rejected',
        'reference': 'R123',
        'rejection_reason': 'No recibido',
        'requested_at': '2026-10-05T12:00:00Z'
      }),
    ]))));
    expect(find.text('Confirmada'), findsOneWidget);
    expect(find.text('Rechazada'), findsOneWidget);
    expect(find.text('25 CUP'), findsOneWidget);
    expect(find.text('Efectivo'), findsOneWidget);
    expect(find.textContaining('05/10/2026'), findsNWidgets(2));
    expect(find.text('Referencia: R123'), findsOneWidget);
    expect(find.text('Motivo: No recibido'), findsOneWidget);
  });
}
