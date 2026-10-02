import 'package:control_tuk_tuk/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _RatingsStore extends Fake implements RecordStore {
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
}

class _RatingsService extends MarketplaceService {
  _RatingsService() : super(Supabase.instance.client);

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
            'is_available': true,
            'accepting_jobs': true,
          },
        ],
      });

  @override
  Future<MarketplaceWorkAccess> access(String vehicleId) async =>
      MarketplaceWorkAccess.fromMap({
        'onboarding_complete': true,
        'driver_active': true,
        'suite_active': true,
        'vehicle_available': true,
        'can_accept_new_job': true,
        'trial_active': true,
        'next_billing_mode': 'trial_free',
      });

  @override
  Future<List<MarketplaceJob>> jobs(String scope) async => const [];

  @override
  Future<List<MarketplaceAvailableJob>> available(String vehicleId) async =>
      const [];

  @override
  Future<List<MarketplaceDriverRatingEntry>> ratings({
    int limit = 100,
  }) async =>
      [
        MarketplaceDriverRatingEntry.fromMap({
          'job_id': 'job-1',
          'service_code': 'passenger',
          'service_date': '2026-10-02T14:00:00Z',
          'received_stars': 5,
          'given_stars': 4,
          'is_test': false,
        }),
      ];

  @override
  Future<MarketplaceDriverRatingSummary> ratingSummary() async =>
      MarketplaceDriverRatingSummary.fromMap({
        'average_stars': 4.8,
        'rating_count': 37,
        'rank_position': 4,
        'ranked_driver_count': 12,
        'ranking_eligible': true,
        'minimum_ratings': 5,
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  tearDownAll(() => Supabase.instance.dispose());

  test('rating models parse the reputation contract', () {
    final entry = MarketplaceDriverRatingEntry.fromMap({
      'job_id': 'job-1',
      'received_stars': 5,
      'given_stars': 4,
      'is_test': true,
    });

    final summary = MarketplaceDriverRatingSummary.fromMap({
      'average_stars': 4.75,
      'rating_count': 8,
      'rank_position': 2,
      'ranked_driver_count': 10,
      'ranking_eligible': true,
      'minimum_ratings': 5,
    });

    expect(entry.receivedStars, 5);
    expect(entry.givenStars, 4);
    expect(entry.isTest, isTrue);
    expect(summary.averageStars, 4.75);
    expect(summary.rankPosition, 2);
  });

  testWidgets('ratings tab shows stars and ranking without internal notes',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarketplaceJobsScreen(
            store: _RatingsStore(),
            service: _RatingsService(),
          ),
        ),
      ),
    );

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final evaluations = find.text('Evaluaciones');
    await tester.ensureVisible(evaluations);
    await tester.tap(evaluations);

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Mi valoración'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('37 evaluaciones'), findsOneWidget);
    expect(find.text('Ranking #4 de 12'), findsOneWidget);
    expect(find.text('Cliente → Tú'), findsOneWidget);
    expect(find.text('Tú → Cliente'), findsOneWidget);
    expect(find.textContaining('Nota interna'), findsNothing);
  });
}