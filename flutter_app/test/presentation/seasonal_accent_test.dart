import 'package:control_tuk_tuk/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Christmas campaign is recurring, bounded and can be disabled', () {
    for (final year in [2026, 2027]) {
      expect(seasonalCampaignFor(DateTime(year, 11, 25)), isNull);
      expect(seasonalCampaignFor(DateTime(year, 11, 26))?.id, 'christmas');
      expect(seasonalCampaignFor(DateTime(year, 12, 25))?.id, 'christmas');
      expect(seasonalCampaignFor(DateTime(year, 12, 26)), isNull);
      expect(seasonalCampaignFor(DateTime(year, 12, 1), enabled: false), isNull);
    }
  });

  test('Future campaigns may span calendar years', () {
    const campaign = SeasonalCampaign(
      id: 'new-year', startMonth: 12, startDay: 31, endMonth: 1, endDay: 2,
      messages: {'es': 'Feliz año'}, icon: Icons.auto_awesome_rounded,
      accent: Colors.green, highlight: Colors.amber,
    );
    expect(campaign.includes(DateTime(2026, 12, 31)), isTrue);
    expect(campaign.includes(DateTime(2027, 1, 2)), isTrue);
    expect(campaign.includes(DateTime(2027, 1, 3)), isFalse);
  });

  testWidgets('Home hero displays only the original logo and metrics',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 390.0, 720.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 2.0]) {
          await tester.pumpWidget(MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: SingleChildScrollView(child: Padding(
                padding: const EdgeInsets.all(16),
                child: MetricHero(label: 'Ingreso de hoy', value: '125.000',
                  currency: 'CUP', sublabel: 'Mes actual: 125.000 CUP',
                  icon: Icons.payments_outlined,
                  trailing: const Icon(Icons.directions_car, size: 90)),
              )),
            )),
          ));
          final amount = find.text('125.000');
          final logo = find.byIcon(Icons.directions_car);
          expect(find.byKey(const ValueKey('seasonal-logo-hat')), findsNothing);
          expect(find.text('Felices fiestas'), findsNothing);
          expect(amount, findsOneWidget);
          expect(logo, findsOneWidget);
          expect(find.text('Mes actual: 125.000 CUP'), findsOneWidget);
          expect(tester.getRect(amount).right,
            lessThanOrEqualTo(tester.getRect(logo).left));
          expect(tester.takeException(), isNull);
        }
      }
    }
  });
}
