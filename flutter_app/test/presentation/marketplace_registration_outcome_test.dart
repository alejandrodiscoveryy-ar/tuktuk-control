import 'package:control_tuk_tuk/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MarketplaceOnboarding profile({bool suspended = false, String status = 'active'}) =>
    MarketplaceOnboarding.fromMap({'driver_profile_exists': true,
      'driver_suspended': suspended, 'driver_status': status});
  MarketplaceVehicle vehicle({String status = 'active'}) =>
    MarketplaceVehicle.fromMap({'vehicle_id': 'v', 'marketplace_status': status});
  MarketplaceWorkAccess access({bool complete = true, bool active = true}) =>
    MarketplaceWorkAccess.fromMap({'onboarding_complete': complete, 'driver_active': active});
  test('approval is confirmed by the server and never inferred from saved data', () {
    expect(marketplaceRegistrationOutcome(profile: profile(), vehicle: vehicle(), access: access()), MarketplaceRegistrationOutcome.approved);
    expect(marketplaceRegistrationOutcome(profile: profile(), vehicle: vehicle(), access: access(complete: false)), MarketplaceRegistrationOutcome.incomplete);
    expect(marketplaceRegistrationOutcome(profile: profile(), vehicle: vehicle(status: 'pending_activation'), access: access()), MarketplaceRegistrationOutcome.incomplete);
    expect(marketplaceRegistrationOutcome(profile: profile(suspended: true), vehicle: vehicle(), access: access()), MarketplaceRegistrationOutcome.incomplete);
    expect(marketplaceRegistrationOutcome(profile: profile(), vehicle: vehicle(), access: null), MarketplaceRegistrationOutcome.unconfirmed);
  });
  testWidgets('home receipt clearly names missing requirements and resumes registration', (tester) async {
    var resumed = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MarketplaceRegistrationStatusCard(
      receipt: const MarketplaceRegistrationReceipt(userId: 'test',
        outcome: MarketplaceRegistrationOutcome.incomplete,
        issues: ['Falta la foto del vehículo.']),
      onResume: () => resumed = true,
    ))));
    expect(find.text('Inscripción pendiente de completar'), findsOneWidget);
    expect(find.textContaining('Falta la foto del vehículo.'), findsOneWidget);
    expect(find.text('Inscripción aprobada'), findsNothing);
    await tester.tap(find.text('Revisar inscripción'));
    expect(resumed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
