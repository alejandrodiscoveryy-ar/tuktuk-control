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
  testWidgets('dashboard stays symmetric with narrow and scaled text and offline wallet',
      (tester) async {
    for (final width in [320.0, 360.0, 720.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        for (final offline in [false, true]) {
          await tester.pumpWidget(MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: width,
                    child: DashboardMetricGrid(cards: [
                      MetricCard(
                        label: 'Saldo disponible',
                        value: offline ? 'Sin conexión' : '1.250',
                        currency: offline ? null : 'CUP',
                        icon: Icons.account_balance_wallet_outlined,
                        details: Column(children: [
                          Text(offline ? 'Recargado —' : 'Recargado 1.000', style: const TextStyle(fontSize: 10), maxLines: 1),
                          Text(offline ? 'Referido —' : 'Referido 250', style: const TextStyle(fontSize: 10), maxLines: 1),
                        ]),
                      ),
                      const MetricCard(label: 'Distancia del mes', value: '0 km', icon: Icons.route_outlined),
                      const MetricCard(label: 'Ingresos históricos', value: '402.500', currency: 'CUP', icon: Icons.payments_outlined),
                      const MetricCard(label: 'Eficiencia', value: '0', note: 'CUP/km', icon: Icons.bolt_outlined),
                      const MetricCard(label: 'Gastos del mes', value: '0', currency: 'CUP', icon: Icons.receipt_long_outlined),
                      const MetricCard(label: 'Ganancia neta del mes', value: '399.000', currency: 'CUP', icon: Icons.account_balance_outlined),
                    ]),
                  ),
                ),
              ),
            ),
          ));
          await tester.pump();
          final cards = find.byType(MetricCard);
          expect(cards, findsNWidgets(6));
          final first = tester.getSize(cards.first);
          if (width == 360 && scale == 1) {
            expect(first.height, lessThanOrEqualTo(114));
          }
          for (var i = 1; i < 6; i++) {
            expect(tester.getSize(cards.at(i)), first);
          }
          expect(tester.takeException(), isNull);
        }
      }
    }
  });


  testWidgets('Home visual cards preserve wallet breakdown and align only within each row',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 390.0, 720.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        for (final offline in [false, true]) {
          await tester.binding.setSurfaceSize(Size(width, 900));
          await tester.pumpWidget(MaterialApp(
            home: Scaffold(body: MediaQuery(
              data: MediaQueryData(size: Size(width, 900),
                textScaler: TextScaler.linear(scale)),
              child: SingleChildScrollView(child: Padding(
                padding: const EdgeInsets.all(16),
                child: StatisticsMetricGrid(
                  keyPrefix: 'home-card',
                  columns: width >= 700 ? 3 : 2,
                  cards: [
                    MetricCard(
                      label: 'Saldo disponible',
                      value: offline ? 'Sin conexión' : '1.250',
                      currency: offline ? null : 'CUP',
                      icon: Icons.account_balance_wallet_outlined,
                      color: kTertiary,
                      details: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final detail in [
                            ('Recargado', offline ? '—' : '1.000'),
                            ('Referido', offline ? '—' : '250'),
                          ]) ...[
                            Row(children: [
                              Expanded(child: Text(detail.$1, maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, height: 1.2))),
                              const SizedBox(width: 4),
                              Flexible(child: FittedBox(fit: BoxFit.scaleDown,
                                child: Text(detail.$2, maxLines: 1,
                                  style: const TextStyle(fontSize: 10, height: 1.2)))),
                            ]),
                            if (detail.$1 == 'Recargado') const SizedBox(height: 3),
                          ],
                        ],
                      ),
                    ),
                    const MetricCard(label: 'Distancia del mes', value: '958', currency: 'km',
                      icon: Icons.route_outlined),
                    const MetricCard(label: 'Ingresos históricos', value: '402.500',
                      currency: 'CUP', icon: Icons.payments_outlined),
                    const MetricCard(label: 'Eficiencia', value: '0', note: 'CUP/km',
                      icon: Icons.bolt_outlined),
                    const MetricCard(label: 'Gastos del mes', value: '0',
                      currency: 'CUP', icon: Icons.receipt_long_outlined),
                    const MetricCard(label: 'Ganancia neta del mes', value: '399.000',
                      currency: 'CUP', icon: Icons.account_balance_outlined),
                  ],
                ),
              )),
            )),
          ));
          Finder card(IconData icon) => find.byKey(ValueKey('home-card-${icon.codePoint}'));
          final wallet = card(Icons.account_balance_wallet_outlined);
          final distance = card(Icons.route_outlined);
          final expenses = card(Icons.receipt_long_outlined);
          final net = card(Icons.account_balance_outlined);
          expect(find.text('Recargado'), findsOneWidget);
          expect(find.text('Referido'), findsOneWidget);
          expect(find.text(offline ? 'Sin conexión' : '1.250'), findsOneWidget);
          expect(find.text('CUP/km'), findsOneWidget);
          // At standard mobile size, the wallet's two detail rows need
          // extra room; other rows must not inherit that height.
          if (width == 390 && scale == 1) {
            expect(tester.getSize(wallet).height,
              greaterThan(tester.getSize(expenses).height));
            if (!offline) {
              final icon = tester.getRect(find.descendant(of: wallet,
                matching: find.byIcon(Icons.account_balance_wallet_outlined)));
              final label = tester.getRect(find.text('Saldo disponible'));
              expect(label.top - icon.bottom, lessThanOrEqualTo(6));
              final distanceLabel = tester.getRect(find.text('Distancia del mes'));
              expect(tester.getRect(distance).bottom - distanceLabel.bottom,
                lessThanOrEqualTo(36));
            }
          }
          if (scale < 2) {
            expect(tester.getSize(wallet), tester.getSize(distance));
            expect(tester.getSize(expenses), tester.getSize(net));
            expect(tester.getTopLeft(wallet).dy, tester.getTopLeft(distance).dy);
            expect(tester.getTopLeft(expenses).dy, tester.getTopLeft(net).dy);
          } else {
            expect(tester.getTopLeft(distance).dy,
              greaterThan(tester.getTopLeft(wallet).dy));
            expect(tester.getSize(wallet).width, tester.getSize(expenses).width);
          }
          expect(tester.takeException(), isNull);
        }
      }
    }
  });
}
