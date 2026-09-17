import 'dart:io';

import 'package:control_tuk_tuk/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    store
      ..initialized = true
      ..license = const LicenseSnapshot(
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

  testWidgets(
    'modo solo lectura abre Registros en Historial y deshabilita guardar',
    (tester) async {
      await tester.pumpWidget(MaterialApp(home: AppShell(store: store)));
      await tester.pump();

      await tester.tap(find.text('Registros'));
      await tester.pumpAndSettle();

      final tabs = DefaultTabController.of(
        tester.element(find.byType(TabBarView)),
      );
      expect(tabs.index, 1);
      expect(
        find.text('Cuando guardes registros, apareceran aqui.'),
        findsOneWidget,
      );

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
      expect(saveButton.onPressed, isNull);
    },
  );
}
