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

  testWidgets('Only the logo hat changes during Christmas, with unchanged card geometry',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const hatKey = ValueKey('seasonal-logo-hat');
    for (final width in [320.0, 390.0, 720.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 2.0]) {
          Widget screen(DateTime date, {bool seasonal = true}) => MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: SingleChildScrollView(child: Padding(
                padding: const EdgeInsets.all(16),
                child: MetricHero(label: 'Ingreso de hoy', value: '125.000',
                  currency: 'CUP', sublabel: 'Mes actual: 125.000 CUP',
                  icon: Icons.payments_outlined, seasonal: seasonal, seasonalDate: date,
                  trailing: const Icon(Icons.directions_car, size: 90)),
              )),
            )),
          );
          await tester.pumpWidget(screen(DateTime(2026, 12, 26)));
          final hero = find.byType(GradientMetricCard);
          final amount = find.text('125.000');
          final logo = find.byIcon(Icons.directions_car);
          final heroRect = tester.getRect(hero);
          final amountRect = tester.getRect(amount);
          final logoRect = tester.getRect(logo);
          expect(find.byKey(hatKey), findsNothing);
          expect(tester.takeException(), isNull);

          await tester.pumpWidget(screen(DateTime(2026, 12, 1)));
          final hat = find.byKey(hatKey);
          expect(hat, findsOneWidget);
          expect(find.text('Felices fiestas'), findsNothing);
          expect(find.text('125.000'), findsOneWidget);
          expect(tester.getRect(hero), heroRect);
          expect(tester.getRect(amount), amountRect);
          expect(tester.getRect(logo), logoRect);
          expect(amountRect.right, lessThanOrEqualTo(logoRect.left));
          expect(tester.getSize(hat), const Size(39, 24));
          expect(heroRect.contains(tester.getRect(hat).center), isTrue);
          expect(tester.getRect(hat).overlaps(logoRect), isTrue);
          expect(tester.takeException(), isNull);

          await tester.pumpWidget(screen(DateTime(2026, 12, 1), seasonal: false));
          expect(hat, findsNothing);
          expect(tester.getRect(hero), heroRect);
          expect(tester.takeException(), isNull);
        }
      }
    }
  });
}
