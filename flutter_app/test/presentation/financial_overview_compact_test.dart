import 'package:control_tuk_tuk/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('money uses a smaller secondary currency without shrinking the amount unnecessarily',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox(
      width: 150,
      child: MetricCard(label: 'Ingresos', value: '12.500', currency: 'CUP',
        icon: Icons.payments_outlined),
    ))));
    final amount = tester.widget<Text>(find.text('12.500'));
    final currency = tester.widget<Text>(find.text('CUP'));
    expect(currency.style!.fontSize!, lessThan(amount.style!.fontSize!));
    expect(tester.takeException(), isNull);
  });

  testWidgets('statistics preserve complete values and units at mobile width',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: [
              StatOverviewCard(
                width: 150,
                label: 'Eficiencia',
                value: '85,52',
                note: 'CUP/km',
                icon: Icons.speed_outlined,
              ),
              StatOverviewCard(
                width: 150,
                label: 'Promedio por día trabajado',
                value: '4.035,92',
                icon: Icons.calendar_today_outlined,
              ),
              StatOverviewCard(
                width: 150,
                label: 'Mantenimiento',
                value: 'Normal',
                note: 'Próximo en 2.688 km',
                icon: Icons.build_outlined,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('85,52'), findsOneWidget);
    expect(find.text('CUP/km'), findsOneWidget);
    expect(find.text('4.035,92'), findsOneWidget);
    expect(find.text('Próximo en 2.688 km'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard keeps efficiency units separate from its value',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 150,
            child: MetricCard(
              label: 'Eficiencia',
              value: '85,52',
              note: 'CUP/km',
              icon: Icons.bolt_outlined,
            ),
          ),
        ),
      ),
    );
    expect(find.text('85,52'), findsOneWidget);
    expect(find.text('CUP/km'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
