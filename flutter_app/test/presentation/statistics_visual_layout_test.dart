import 'package:control_tuk_tuk/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  testWidgets('Statistics cards align per row without reserving unrelated note space',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const cards = [
      MetricCard(label: 'Ingresos totales', value: '125.000', currency: 'CUP',
        icon: Icons.account_balance_wallet_outlined, color: Color(0xFF56D2A1)),
      MetricCard(label: 'Gastos totales', value: '25.000', currency: 'CUP',
        icon: Icons.receipt_long_outlined, color: Color(0xFFF87171)),
      MetricCard(label: 'Promedio por día trabajado', value: '4.035,92',
        currency: 'CUP', icon: Icons.calendar_today_outlined,
        color: Color(0xFF72A7FF)),
      MetricCard(label: 'Mantenimiento', value: 'Normal',
        note: 'Próximo en 2.688 km', icon: Icons.build_outlined),
    ];
    for (final brightness in Brightness.values) {
      for (final width in [320.0, 390.0, 720.0]) {
        for (final scale in [1.0, 1.5, 2.0]) {
          await tester.binding.setSurfaceSize(Size(width, 900));
          await tester.pumpWidget(MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(body: MediaQuery(
              data: MediaQueryData(size: Size(width, 900),
                textScaler: TextScaler.linear(scale)),
              child: SingleChildScrollView(
                child: Padding(padding: const EdgeInsets.all(16),
                  child: StatisticsMetricGrid(cards: cards,
                    columns: width >= 700 ? 3 : 2)),
              ),
            )),
          ));
          Finder cardAt(int index) => find.byKey(ValueKey(
            'statistics-card-${cards[index].icon.codePoint}'));
          final first = cardAt(0);
          final last = cardAt(3);
          final firstSize = tester.getSize(first);
          final lastSize = tester.getSize(last);
          expect(firstSize.width, lastSize.width);
          expect(lastSize.height, greaterThan(firstSize.height));
          if (scale < 2) {
            expect(tester.getSize(cardAt(1)), firstSize);
            expect(tester.getTopLeft(cardAt(1)).dy, tester.getTopLeft(first).dy);
            if (width >= 700) {
              expect(tester.getSize(cardAt(2)), firstSize);
              expect(tester.getTopLeft(cardAt(2)).dy, tester.getTopLeft(first).dy);
            } else {
              expect(tester.getSize(cardAt(2)), lastSize);
              expect(tester.getTopLeft(cardAt(2)).dy, tester.getTopLeft(last).dy);
            }
          } else {
            expect(tester.getTopLeft(cardAt(1)).dy,
              greaterThan(tester.getTopLeft(first).dy));
          }
          final income = tester.widget<Icon>(
            find.byIcon(Icons.account_balance_wallet_outlined));
          final expenses = tester.widget<Icon>(
            find.byIcon(Icons.receipt_long_outlined));
          expect(income.size, 31);
          expect(income.color, isNot(expenses.color));
          expect(find.text('125.000'), findsOneWidget);
          expect(tester.widget<Text>(find.text('125.000')).style!.fontSize, 26);
          if (width == 720 && scale == 1) {
            expect(firstSize.height, lessThan(125));
          }
          expect(find.text('Próximo en 2.688 km'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('Monthly chart supports expense-only months and narrow phones',
      (tester) async {
    await initializeDateFormatting();
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cycles = [
      CycleSummary(start: DateTime(2026, 9), label: 'September',
        earnings: 0, expenses: 1200, distance: 0),
      CycleSummary(start: DateTime(2026, 10), label: 'October',
        earnings: 600, expenses: 150, distance: 10),
    ];
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: SingleChildScrollView(
        child: MonthlyEarningsBars(cycles: cycles, statisticsStyle: true),
      ),
    )));
    final bars = find.byWidgetPredicate((widget) =>
      widget is Container && widget.constraints?.maxWidth == 23);
    expect(bars, findsNWidgets(4));
    final heights = tester.widgetList<Container>(bars)
      .map((bar) => bar.constraints!.maxHeight).toList();
    expect(heights, [0.0, 150.0, 75.0, 18.75]);
    expect(tester.takeException(), isNull);
  });
}
