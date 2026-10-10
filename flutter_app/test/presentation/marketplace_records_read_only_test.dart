import 'dart:io';

import 'package:control_tuk_tuk/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _IncomeService extends MarketplaceService {
  _IncomeService() : super(Supabase.instance.client);
  List<MarketplaceJob> feed = [];
  final cursors = <String?>[];
  bool fail = false;
  @override
  Future<List<MarketplaceJob>> incomePage({MarketplaceJob? after}) async {
    cursors.add(after?.id);
    if (fail) throw const SocketException('offline');
    return feed
        .where((job) =>
            after == null ||
            job.updatedAt!.isAfter(after.updatedAt!) ||
            (job.updatedAt == after.updatedAt &&
                job.id.compareTo(after.id) > 0))
        .take(50)
        .toList();
  }
}

MarketplaceJob _settled(String id,
        {bool? isTest = false,
        String billingMode = 'wallet_commission',
        DateTime? updatedAt}) =>
    MarketplaceJob.fromMap({
      'job_id': id,
      'status': 'settled',
      'is_test': isTest,
      'vehicle_id': 'marketplace-assigned-id',
      'vehicle_name': 'Triciclo asignado',
      'vehicle_registration': 'P123',
      'final_price': 123,
      'billing_mode': billingMode,
      'created_at': '2000-01-01T00:00:00Z',
      'updated_at': (updatedAt ?? DateTime.utc(2026, 10, 10)).toIso8601String(),
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late RecordStore store;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => call.method == 'getAll' ? <String, dynamic>{} : true,
    );
    await initializeDateFormatting('es');
    directory = await Directory.systemTemp.createTemp('b9-read-only-test-');
    Hive.init(directory.path);
    for (final name in [
      'daily_records',
      'maintenance_records',
      'meta',
      'sync_queue',
    ]) {
      await Hive.openBox<dynamic>(name);
    }
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

  setUp(() async {
    await Hive.box('daily_records').clear();
    await Hive.box('sync_queue').clear();
    final meta = Hive.box('meta');
    for (final key in meta.keys
        .where((key) => '$key'.startsWith('marketplaceIncome'))
        .toList()) {
      await meta.delete(key);
    }
    store = RecordStore();
    final userId = store.activeUserId;
    final vehicle = VehicleProfile(
      id: 'vehicle-$userId-primary',
      userId: userId,
      name: 'Vehículo de prueba',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await Hive.box('meta').put('activeVehicleId:$userId', vehicle.id);
    await Hive.box('meta').put('vehicle:${vehicle.id}', vehicle.toMap());
    while (!store.initialized) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    store.license = const LicenseSnapshot(
      planId: 'personal',
      licenseStatus: LicenseStatus.expired,
      canWrite: false,
    );
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  tearDown(() => store.dispose());

  test('periodic missing-income recovery is bounded and resumes its own cursor',
      () async {
    final service = _IncomeService();
    service.feed = List.generate(
        120,
        (index) => _settled('sweep-${index.toString().padLeft(3, '0')}',
            updatedAt:
                DateTime.utc(2026, 10, 10).add(Duration(seconds: index))));
    await store.reconcileMarketplaceIncomes(service);
    await store.reconcileMarketplaceIncomes(service);
    service.feed.insert(
        0,
        _settled('missing-after-restore',
            updatedAt: DateTime.utc(2026, 10, 9)));
    await Hive.box('meta').put(
        'marketplaceIncomeSweepCompleted:${store.activeUserId}',
        DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 2))
            .toIso8601String());
    var calls = service.cursors.length;
    await store.reconcileMarketplaceIncomes(service);
    expect(service.cursors.length - calls, 2);
    expect(service.cursors.last, isNull);
    expect(Hive.box('daily_records').length, 121);
    calls = service.cursors.length;
    await store.reconcileMarketplaceIncomes(service);
    expect(service.cursors.length - calls, 2);
    expect(service.cursors.last, 'sweep-048');
    await store.reconcileMarketplaceIncomes(service);
    expect(service.cursors.last, 'sweep-098');
    calls = service.cursors.length;
    await store.reconcileMarketplaceIncomes(service);
    expect(service.cursors.length - calls, 1);
    expect(service.cursors.last, 'sweep-119');
    expect(Hive.box('daily_records').length, 121);
  });

  test(
      'server test flag excludes test rides, preserves existing data and allows real trial_free fares',
      () async {
    final box = Hive.box('daily_records');
    final previous = DailyRecord(
        id: 'marketplace-job-test-existing',
        date: DateTime(2026),
        earnings: 75,
        odometer: 0,
        userId: store.activeUserId,
        vehicleId: store.activeVehicleId);
    await box.put(previous.id, previous.toMap());
    await store.reconcileMarketplaceJob(_settled('test-new', isTest: true));
    await store
        .reconcileMarketplaceJob(_settled('test-existing', isTest: true));
    expect(box.get('marketplace-job-test-new'), isNull);
    expect(DailyRecord.fromMap(box.get(previous.id) as Map).earnings, 75);
    await store.reconcileMarketplaceJob(
        _settled('real-promo', billingMode: 'trial_free'));
    expect(
        DailyRecord.fromMap(box.get('marketplace-job-real-promo') as Map)
            .earnings,
        123);
    await expectLater(
        () => store.reconcileMarketplaceJob(_settled('unknown', isTest: null)),
        throwsStateError);
    expect(box.get('marketplace-job-unknown'), isNull);
  });

  test(
      'bounded recovery persists progress, retries errors and catches a late close of an old booking',
      () async {
    final service = _IncomeService();
    service.feed = List.generate(
        120,
        (index) => _settled('bounded-${index.toString().padLeft(3, '0')}',
            updatedAt:
                DateTime.utc(2026, 10, 10).add(Duration(seconds: index))));
    await store.reconcileMarketplaceIncomes(service);
    expect(service.cursors.length, 2);
    expect(Hive.box('daily_records').length, 100);
    expect(service.cursors[1], 'bounded-049');
    service.fail = true;
    await store.reconcileMarketplaceIncomes(service);
    expect(store.marketplaceIncomeReconciliationError, isNotNull);
    expect(service.cursors.last, 'bounded-099');
    service.fail = false;
    store.dispose();
    store = RecordStore();
    while (!store.initialized) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await store.reconcileMarketplaceIncomes(service);
    expect(service.cursors.last, 'bounded-099');
    expect(Hive.box('daily_records').length, 120);
    expect(store.marketplaceIncomeReconciliationError, isNull);
    service.feed.add(_settled('old-booking-closed-later',
        updatedAt: DateTime.utc(2026, 10, 11)));
    await store.reconcileMarketplaceIncomes(service);
    expect(service.cursors.last, 'bounded-119');
    expect(Hive.box('daily_records').length, 121);
    await store.reconcileMarketplaceIncomes(service);
    expect(service.cursors.last, 'old-booking-closed-later');
    expect(Hive.box('daily_records').length, 121);
  });

  test(
      'one failed income leaves the page retryable while other fares are recovered',
      () async {
    final service = _IncomeService();
    service.feed = [_settled('bad', isTest: null), _settled('good')];
    await store.reconcileMarketplaceIncomes(service);
    expect(store.marketplaceIncomeReconciliationError, isNotNull);
    expect(Hive.box('daily_records').get('marketplace-job-good'), isNotNull);
    service.feed[0] = _settled('bad');
    await store.reconcileMarketplaceIncomes(service);
    expect(service.cursors, [null, null]);
    expect(Hive.box('daily_records').length, 2);
    expect(store.marketplaceIncomeReconciliationError, isNull);
  });

  testWidgets(
      'reconciled fare appears in Registros only under the identical assigned vehicle ID',
      (tester) async {
    final initialVehicleId = store.activeVehicleId;
    final service = _IncomeService()..feed = [_settled('visible')];
    await tester.runAsync(() => store.reconcileMarketplaceIncomes(service));
    expect(store.activeVehicleId, initialVehicleId);
    expect(store.records.where((record) => record.isMarketplaceJobIncome),
        isEmpty);
    final assigned = store.vehicles
        .singleWhere((vehicle) => vehicle.id == 'marketplace-assigned-id');
    expect(assigned.name, 'Triciclo asignado');
    expect(assigned.registration, 'P123');
    await tester.runAsync(() => store.selectVehicle(assigned.id));
    expect(store.records.single.vehicleId, service.feed.single.vehicleId);
    expect(store.records.single.id, 'marketplace-job-visible');
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: HistoryScreen(store: store))));
    await tester.tap(find.text('Trabajo'));
    await tester.pumpAndSettle();
    final tile = tester.widget<RecordTile>(find.byType(RecordTile));
    expect(tile.record.id, 'marketplace-job-visible');
    expect(tile.record.earnings, 123);
    expect(tile.record.vehicleId, 'marketplace-assigned-id');
    await tester.runAsync(() => store.selectVehicle(initialVehicleId));
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: HistoryScreen(store: store))));
    await tester.pumpAndSettle();
    expect(find.byType(RecordTile), findsNothing);
  });

  test('legacy settlement corrects vehicle without changing amount or date',
      () async {
    final box = Hive.box('daily_records');
    final prior = DailyRecord(
      id: 'marketplace-job-legacy',
      date: DateTime.utc(2026, 9, 1),
      earnings: 80,
      odometer: 25,
      userId: store.activeUserId,
      vehicleId: 'incorrect-active-vehicle',
    );
    await box.put(prior.id, prior.toMap());
    await store.ensureMarketplaceJobIncome(
      jobId: 'legacy',
      amount: 999,
      vehicleId: 'assigned-vehicle',
    );
    final corrected = DailyRecord.fromMap(box.get(prior.id) as Map);
    expect(corrected.vehicleId, 'assigned-vehicle');
    expect(corrected.earnings, prior.earnings);
    expect(corrected.date, DailyRecord.fromMap(prior.toMap()).date);
    expect(corrected.odometer, prior.odometer);
  });

  test(
      'settlement persists once under concurrent retries and keeps previous income',
      () async {
    final box = Hive.box('daily_records');
    final previous = DailyRecord(
        id: 'previous-income',
        date: DateTime(2026),
        earnings: 75,
        odometer: 10,
        userId: store.activeUserId,
        vehicleId: 'assigned-historical-vehicle');
    await box.put(previous.id, previous.toMap());
    final completed = DateTime.utc(2026, 10, 8);
    await Future.wait(List.generate(
        3,
        (_) => store.ensureMarketplaceJobIncome(
              jobId: 'settled-test',
              amount: 100,
              vehicleId: 'assigned-historical-vehicle',
              completedAt: completed,
              distanceKm: 5,
            )));
    final income =
        DailyRecord.fromMap(box.get('marketplace-job-settled-test') as Map);
    expect(income.vehicleId, 'assigned-historical-vehicle');
    expect(income.userId, store.activeUserId);
    expect(income.earnings, 100);
    expect(income.odometer, 15);
    expect(income.date, DateTime(2026, 10, 8));
    expect(box.keys.where((key) => key == income.id).length, 1);
    expect(DailyRecord.fromMap(box.get(previous.id) as Map).earnings, 75);
    await store.ensureMarketplaceJobIncome(
        jobId: 'settled-test',
        amount: 999,
        vehicleId: 'assigned-historical-vehicle');
    expect(DailyRecord.fromMap(box.get(income.id) as Map).earnings, 100);
    expect(DailyRecord.fromMap(box.get(income.id) as Map).vehicleId,
        'assigned-historical-vehicle');
  });

  testWidgets(
    'una licencia legado vencida no bloquea Registros ni Guardar',
    (tester) async {
      await tester.pumpWidget(MaterialApp(home: AppShell(store: store)));
      await tester.pump();

      await tester.tap(find.text('Registros'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Tu licencia no permite realizar cambios'),
        findsNothing,
      );

      final tabs = DefaultTabController.of(
        tester.element(find.byType(TabBarView)),
      );
      expect(tabs.index, 0);

      await tester.tap(find.text('Nuevo'));
      await tester.pumpAndSettle();
      expect(tabs.index, 0);

      final saveIcon = find.byIcon(Icons.save_outlined);
      await tester.scrollUntilVisible(
        saveIcon,
        250,
        scrollable: find
            .descendant(
              of: find.byType(RegisterScreen),
              matching: find.byType(Scrollable),
            )
            .first,
        maxScrolls: 20,
      );
      expect(saveIcon, findsOneWidget);
      final saveButton = tester.widget<FilledButton>(
        find.ancestor(
          of: saveIcon,
          matching: find.byType(FilledButton),
        ),
      );
      expect(saveButton.onPressed, isNotNull);
    },
  );
}
