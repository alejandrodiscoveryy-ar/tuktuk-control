import 'dart:async';
import 'dart:io';

import 'package:control_tuk_tuk/main.dart';
import 'package:control_tuk_tuk/services/push_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Store extends Fake implements RecordStore {
  @override
  User? get user => const User(
        id: 'driver-test',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01',
      );

  @override
  VehicleProfile? get activeVehicle => null;

  @override
  Future<void> ensureMarketplaceJobIncome({
    required String jobId,
    required double amount,
    double? distanceKm,
    DateTime? completedAt,
  }) async {}
}

class _JobsService extends MarketplaceService {
  _JobsService() : super(Supabase.instance.client);
  int availableCalls = 0;
  int historyCalls = 0;
  bool successfulAccept = false;
  int atomicAcceptCalls = 0;
  int legacyAcceptCalls = 0;
  int advanceCalls = 0;
  int finishCalls = 0;
  String? lastAdvanceAction;
  List<MarketplaceAvailableJob> availableJobs = [offer];
  bool failAvailable = false;
  bool failActive = false;
  bool acceptingJobs = true;
  List<MarketplaceJob> active = [];
  Completer<List<MarketplaceAvailableJob>>? pending;

  @override
  Future<MarketplaceOnboarding> onboarding() async =>
      MarketplaceOnboarding.fromMap({
        'driver_profile_exists': true,
        'driver_status': 'active',
        'display_name': 'Conductor de prueba',
        'phone': '+5355555555',
        'driver_photo_asset_id': 'driver-photo-test',
        'vehicles': [
          {
            'vehicle_id': 'vehicle-test',
            'name': 'Vehículo de prueba',
            'marketplace_status': 'active',
            'onboarding_complete': true,
            'is_active': true,
            'is_available': acceptingJobs,
            'accepting_jobs': acceptingJobs,
          },
        ],
      });

  @override
  Future<MarketplaceWorkAccess> access(String vehicleId) async =>
      MarketplaceWorkAccess.fromMap({
        'onboarding_complete': true,
        'driver_active': true,
        'suite_active': true,
        'vehicle_available': acceptingJobs,
        'can_accept_new_job': acceptingJobs,
        'trial_active': true,
        'next_billing_mode': 'trial_free',
      });

  @override
  Future<List<MarketplaceJob>> jobs(String scope) async {
    if (scope == 'history') historyCalls++;
    if (scope == 'active' && failActive) {
      throw const SocketException('offline');
    }
    return scope == 'active' ? active : [];
  }

  @override
  Future<List<MarketplaceAvailableJob>> available(String vehicleId) async {
    availableCalls++;
    if (failAvailable) throw const SocketException('offline');
    return pending == null ? availableJobs : pending!.future;
  }

  @override
  Future<MarketplaceJob> accept(
    String jobId,
    String vehicleId,
    String key,
  ) async {
    legacyAcceptCalls++;
    if (!successfulAccept) {
      throw StateError('INSUFFICIENT_MARKETPLACE_WALLET_BALANCE');
    }
    return MarketplaceJob.fromMap({
      'job_id': jobId,
      'status': 'accepted',
      'final_price': 100,
      'currency': 'CUP',
    });
  }

  @override
  Future<MarketplaceJob> acceptAndStart(
    String jobId,
    String vehicleId,
    String key,
  ) async {
    atomicAcceptCalls++;
    if (!successfulAccept) {
      throw StateError('INSUFFICIENT_MARKETPLACE_WALLET_BALANCE');
    }
    return MarketplaceJob.fromMap({
      'job_id': jobId,
      'status': 'en_route',
      'final_price': 100,
      'currency': 'CUP',
    });
  }

  @override
  Future<MarketplaceJob> finishJob(
    String jobId,
    String idempotencyKey,
  ) async {
    finishCalls++;
    return MarketplaceJob.fromMap({
      'job_id': jobId,
      'status': 'settled',
      'final_price': 100,
      'currency': 'CUP',
    });
  }

  @override
  Future<MarketplaceJob> advance(
    String jobId,
    String action,
    String idempotencyKey,
  ) async {
    advanceCalls++;
    lastAdvanceAction = action;
    return MarketplaceJob.fromMap({
      'job_id': jobId,
      'status': 'en_route',
      'final_price': 100,
      'currency': 'CUP',
    });
  }
}

const offer = MarketplaceAvailableJob(
  id: '12345678-1234-4123-8123-123456789012',
  serviceCode: 'passenger',
  finalPrice: 100,
  currency: 'CUP',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _JobsService service;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => call.method == 'getAll' ? <String, dynamic>{} : true,
    );
    await initializeDateFormatting('es');
    await Supabase.initialize(
      url: 'http://127.0.0.1:54321',
      publishableKey: 'test-only',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
    );
  });

  setUp(() {
    service = _JobsService();
    marketplaceJobPushPending.value = false;
  });

  tearDownAll(() => Supabase.instance.dispose());

  Future<void> pumpJobs(WidgetTester tester) async {
    // Navigation badges can pulse continuously, so settle only these futures.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MarketplaceJobsScreen(store: _Store(), service: service),
      ),
    ));
    await pumpJobs(tester);
  }

  void notify() => handleForegroundPushData({
        'kind': 'marketplace_job_available',
        'job_id': offer.id,
      });

  test('onboarding requires driver data and at least one complete vehicle', () {
    MarketplaceOnboarding onboarding({required bool vehicleComplete}) =>
        MarketplaceOnboarding.fromMap({
          'driver_profile_exists': true,
          'driver_status': 'active',
          'display_name': 'Conductor de prueba',
          'phone': '+5355555555',
          'driver_photo_asset_id': 'driver-photo-test',
          'vehicles': [
            {
              'vehicle_id': 'vehicle-test',
              'name': 'Vehículo de prueba',
              'marketplace_status': vehicleComplete ? 'active' : 'onboarding',
              'onboarding_complete': vehicleComplete,
              'is_active': vehicleComplete,
              'is_available': vehicleComplete,
              'main_photo_asset_id':
                  vehicleComplete ? 'vehicle-photo-test' : null,
            },
          ],
        });

    expect(
      marketplaceDriverOnboardingNeedsSetup(
        MarketplaceOnboarding.fromMap({
          'driver_profile_exists': true,
          'driver_status': 'active',
          'display_name': 'Conductor de prueba',
          'phone': '+5355555555',
          'driver_photo_asset_id': 'driver-photo-test',
          'vehicles': const [],
        }),
      ),
      isTrue,
    );
    expect(
      marketplaceDriverOnboardingNeedsSetup(
        onboarding(vehicleComplete: false),
      ),
      isTrue,
    );
    expect(
      marketplaceDriverOnboardingNeedsSetup(
        onboarding(vehicleComplete: true),
      ),
      isFalse,
    );
  });
  test('acceptance messages distinguish wallet, profile and other errors', () {
    expect(
      marketplaceAcceptErrorMessage('INSUFFICIENT_MARKETPLACE_WALLET_BALANCE'),
      'Saldo insuficiente para aceptar este trabajo. Recarga tu billetera y vuelve a intentarlo.',
    );
    expect(marketplaceAcceptErrorMessage('DRIVER_PROFILE_INCOMPLETE'),
        contains('Completa tu perfil'));
    expect(marketplaceAcceptErrorMessage('network error'),
        contains('Comprueba tu conexión'));
  });

  testWidgets(
      'availability card keeps the switch at the top right and shows active state',
      (tester) async {
    await open(tester);

    expect(find.text('Vehículo activo'), findsOneWidget);
    expect(find.text('Vehículo de prueba'), findsOneWidget);
    expect(find.text('En servicio'), findsOneWidget);
    expect(find.text('Recibiendo nuevas solicitudes'), findsOneWidget);

    final availabilitySwitch =
        find.byKey(const ValueKey('marketplace-availability-switch'));
    expect(availabilitySwitch, findsOneWidget);

    final titleTop = tester.getTopLeft(find.text('Vehículo activo')).dy;
    final switchTop = tester.getTopLeft(availabilitySwitch).dy;
    expect((switchTop - titleTop).abs(), lessThan(30));
  });

  testWidgets('immediate acceptance starts route automatically',
      (tester) async {
    service.successfulAccept = true;
    await open(tester);

    await tester.ensureVisible(find.text('Aceptar e ir a buscar'));
    await tester.tap(find.text('Aceptar e ir a buscar'));
    await pumpJobs(tester);

    expect(service.atomicAcceptCalls, 1);
    expect(service.legacyAcceptCalls, 0);
    expect(service.advanceCalls, 0);
  });

  testWidgets('future scheduled acceptance does not start route',
      (tester) async {
    service.successfulAccept = true;
    service.availableJobs = [
      MarketplaceAvailableJob(
        id: offer.id,
        serviceCode: 'passenger',
        finalPrice: 100,
        currency: 'CUP',
        scheduledFor: DateTime.utc(2099, 1, 1),
      ),
    ];
    await open(tester);

    await tester.ensureVisible(find.text('Aceptar trabajo'));
    await tester.tap(find.text('Aceptar trabajo'));
    await pumpJobs(tester);

    expect(service.atomicAcceptCalls, 0);
    expect(service.legacyAcceptCalls, 1);
    expect(service.advanceCalls, 0);
  });

  testWidgets('availability card shows a distinct resting state',
      (tester) async {
    service.acceptingJobs = false;
    await open(tester);

    expect(find.text('Descansando'), findsOneWidget);
    expect(find.text('No estás recibiendo solicitudes'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('marketplace-availability-switch')),
      findsOneWidget,
    );
    expect(find.text('Aceptar e ir a buscar'), findsNothing);
  });
  testWidgets('ongoing ride finishes without intermediate steps',
      (tester) async {
    service.active = [
      MarketplaceJob.fromMap({
        'job_id': offer.id,
        'status': 'en_route',
        'next_driver_action': 'mark_pickup',
        'service_code': 'passenger',
        'origin_text': 'Origen de prueba',
        'destination_text': 'Destino de prueba',
        'final_price': 100,
        'currency': 'CUP',
      }),
    ];

    await open(tester);

    expect(find.text('Finalizar carrera'), findsOneWidget);
    expect(find.text('Confirmar recogida'), findsNothing);

    await tester.ensureVisible(find.text('Finalizar carrera'));
    await tester.tap(find.text('Finalizar carrera'));
    await pumpJobs(tester);

    expect(service.finishCalls, 1);
    expect(service.advanceCalls, 0);
  });
  testWidgets('advance button is unique below current status and above route',
      (tester) async {
    service.active = [
      MarketplaceJob.fromMap({
        'job_id': offer.id,
        'status': 'accepted',
        'next_driver_action': 'start_en_route',
        'service_code': 'passenger',
        'origin_text': 'Origen de prueba',
        'destination_text': 'Destino de prueba',
        'final_price': 100,
        'currency': 'CUP',
      }),
    ];
    await open(tester);
    expect(find.text('Vehículo activo'), findsNothing);
    expect(find.text('Trabajando'), findsNothing);
    final action = find.text('Salir hacia el cliente');
    expect(action, findsOneWidget);
    expect(
        tester.getTopLeft(action).dy,
        greaterThan(tester
            .getTopLeft(find.text('Servicio aceptado · prepárate para salir'))
            .dy));
    expect(tester.getTopLeft(action).dy,
        lessThan(tester.getTopLeft(find.text('Origen de prueba')).dy));
  });

  testWidgets(
      'foreground refresh coalesces pushes and clears stale offers on error',
      (tester) async {
    await open(tester);
    expect(service.availableCalls, 1);
    expect(service.historyCalls, 1);
    service.pending = Completer<List<MarketplaceAvailableJob>>();
    notify();
    await tester.pump();
    expect(marketplaceJobPushPending.value, isTrue);
    expect(service.availableCalls, 2);
    notify();
    notify();
    await tester.pump();
    expect(service.availableCalls, 2);
    service.failAvailable = true;
    service.pending!.complete([offer]);
    await pumpJobs(tester);
    expect(service.availableCalls, 3);
    expect(service.historyCalls, 1);
    expect(marketplaceJobPushPending.value, isFalse);
    expect(find.text('Aceptar e ir a buscar'), findsNothing);
    expect(find.textContaining('No pudimos actualizar los trabajos'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    final calls = service.availableCalls;
    notify();
    await tester.pump();
    expect(service.availableCalls, calls);
  });

  testWidgets(
      'resume rechecks offers and acceptance shows insufficient balance',
      (tester) async {
    await open(tester);
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await pumpJobs(tester);
    expect(service.availableCalls, 2);
    expect(service.historyCalls, 1);
    await tester.ensureVisible(find.text('Aceptar e ir a buscar'));
    await tester.tap(find.text('Aceptar e ir a buscar'));
    await pumpJobs(tester);
    expect(
        find.text(
            'Saldo insuficiente para aceptar este trabajo. Recarga tu billetera y vuelve a intentarlo.'),
        findsOneWidget);
  });

  testWidgets(
      'unverified active jobs clear offers without querying availability',
      (tester) async {
    await open(tester);
    service.failActive = true;
    notify();
    await pumpJobs(tester);
    expect(service.availableCalls, 1);
    expect(marketplaceJobPushPending.value, isFalse);
    expect(find.text('Aceptar e ir a buscar'), findsNothing);
  });

  testWidgets('resting vehicle remains ineligible after a push',
      (tester) async {
    service.acceptingJobs = false;
    await open(tester);
    notify();
    await pumpJobs(tester);
    expect(service.availableCalls, 0);
    expect(marketplaceJobPushPending.value, isFalse);
    expect(find.text('Aceptar e ir a buscar'), findsNothing);
  });

  testWidgets('receiving push preserves selected tab', (tester) async {
    await open(tester);
    await tester.tap(find.text('Hist.'));
    await pumpJobs(tester);
    final controller = tester.widget<TabBar>(find.byType(TabBar)).controller!;
    expect(controller.index, 2);
    notify();
    await pumpJobs(tester);
    expect(controller.index, 2);
    expect(find.text('Tu historial está vacío'), findsOneWidget);
  });

  testWidgets('hidden Jobs refreshes without building maps or navigating',
      (tester) async {
    service.active = [MarketplaceJob.fromMap({
      'job_id': offer.id,
      'status': 'accepted',
      'next_driver_action': 'start_en_route',
      'origin_lat': 23.1,
      'origin_lon': -82.4,
      'destination_lat': 23.2,
      'destination_lon': -82.5,
    })];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Stack(children: [
      MarketplaceJobsScreen(
        store: _Store(), service: service, isVisible: false,
      ),
      const Text('Otra sección'),
    ]))));
    await pumpJobs(tester);
    notify();
    await pumpJobs(tester);
    expect(find.text('Otra sección'), findsOneWidget);
    expect(find.byType(MarketplaceDriverMap), findsNothing);
    expect(find.byType(TabBar), findsNothing);
    expect(service.historyCalls, 1);
    expect(service.availableCalls, 0);
  });
}
