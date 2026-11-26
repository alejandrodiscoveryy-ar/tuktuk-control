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

  testWidgets('Seasonal accent is compact and disappears out of season', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 640));
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        Widget screen(DateTime date) => MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Column(children: [
              SeasonalAccent(date: date, language: 'es'),
              const Text('Métricas'),
            ]),
          )),
        );
        await tester.pumpWidget(screen(DateTime(2026, 12, 1)));
        final accent = find.byKey(const ValueKey('seasonal-accent-christmas'));
        expect(accent, findsOneWidget);
        expect(find.text('Felices fiestas'), findsOneWidget);
        expect(tester.getSize(accent).height, lessThan(80));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(screen(DateTime(2026, 12, 26)));
        expect(accent, findsNothing);
        expect(find.text('Métricas'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('Home hero contains greeting without a separate banner or overlap',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 390.0, 720.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      for (final scale in [1.0, 2.0]) {
        Widget screen(DateTime date) => MaterialApp(home: Scaffold(
          body: MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: SingleChildScrollView(child: Padding(
              padding: const EdgeInsets.all(16),
              child: MetricHero(label: 'Ingreso de hoy', value: '125.000',
                currency: 'CUP', sublabel: 'Mes actual: 125.000 CUP',
                icon: Icons.payments_outlined, seasonal: true, seasonalDate: date,
                trailing: const Icon(Icons.directions_car, size: 90)),
            )),
          ),
        ));
        await tester.pumpWidget(screen(DateTime(2026, 12, 1)));
        final hero = find.byType(GradientMetricCard);
        final greeting = find.descendant(of: hero, matching: find.text('Felices fiestas'));
        expect(greeting, findsOneWidget);
        final amount = tester.getRect(find.text('125.000'));
        final logo = tester.getRect(find.byIcon(Icons.directions_car));
        expect(amount.right, lessThanOrEqualTo(logo.left));
        expect(tester.getRect(hero).contains(tester.getRect(greeting).center), isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(screen(DateTime(2026, 12, 26)));
        expect(find.text('Felices fiestas'), findsNothing);
        expect(find.text('125.000'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('Statistics greeting is embedded in the metric row',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 640));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Padding(
      padding: const EdgeInsets.all(16),
      child: StatisticsMetricGrid(cards: [
        MetricCard(label: 'Ingresos', value: '125.000', icon: Icons.payments_outlined,
          details: SeasonalAccent(date: DateTime(2026, 12, 1), language: 'es', compact: true)),
        const MetricCard(label: 'Gastos', value: '0', icon: Icons.receipt_long_outlined),
      ]),
    ))));
    final card = find.byKey(ValueKey('statistics-card-${Icons.payments_outlined.codePoint}'));
    expect(find.descendant(of: card, matching: find.text('Felices fiestas')), findsOneWidget);
    expect(tester.getSize(card), tester.getSize(find.byKey(
      ValueKey('statistics-card-${Icons.receipt_long_outlined.codePoint}'))));
    expect(tester.takeException(), isNull);
  });
}
