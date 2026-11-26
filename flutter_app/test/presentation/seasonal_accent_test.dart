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
}
