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
          // Row height is driven by its own content, not a global aspect ratio.
          expect(lastSize.height, greaterThan(0));
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
          if (width >= 390 && scale == 1) {
            expect(firstSize.height, lessThan(125));
          }
          expect(find.text('Próximo en 2.688 km'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('Monthly chart restores one overlay bar per month and fits all eight',
      (tester) async {
    await initializeDateFormatting();
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cycles = [
      for (var month = 1; month <= 10; month++)
        CycleSummary(start: DateTime(2026, month), label: '$month',
          earnings: month * 100.0, expenses: month * 25.0, distance: 10),
    ];
    Finder bar(CycleSummary cycle) => find.byKey(ValueKey(
      'monthly-income-bar-${cycle.start.toIso8601String()}'));
    for (final width in [320.0, 390.0, 720.0]) {
      await tester.binding.setSurfaceSize(Size(width, 640));
      await tester.pumpWidget(MaterialApp(home: Scaffold(
        body: SingleChildScrollView(
          child: MonthlyEarningsBars(cycles: cycles, statisticsStyle: true),
        ),
      )));
      expect(bar(cycles.first), findsNothing);
      expect(bar(cycles[1]), findsNothing);
      for (final cycle in cycles.skip(2)) {
        final finder = bar(cycle);
        expect(finder, findsOneWidget);
        final rect = tester.getRect(finder);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
        final expense = tester.widget<FractionallySizedBox>(find.descendant(
          of: finder, matching: find.byType(FractionallySizedBox)));
        expect(expense.heightFactor, .25);
        expect(rect.height, closeTo(130 * cycle.earnings / 1000, .01));
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Daily income returns to the original compact list and supplied order',
      (tester) async {
    await initializeDateFormatting();
    final records = [
      DailyRecord(id: 'a', date: DateTime(2026, 11, 3), earnings: 7000, odometer: 1),
      DailyRecord(id: 'b', date: DateTime(2026, 6, 18), earnings: 7620, odometer: 2),
      DailyRecord(id: 'c', date: DateTime(2026, 10, 28), earnings: 9580, odometer: 3),
    ];
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: EarningsTrendCard(records: records, statisticsStyle: true),
    )));
    final rows = tester.widgetList<InfoLine>(find.byType(InfoLine)).toList();
    expect(rows.map((row) => row.value).toList(),
      records.map((record) => money(record.earnings)).toList());
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home and statistics mirror only the right edge of each row',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const cards = [
      MetricCard(label: 'Ingresos', value: '125.000', currency: 'CUP',
        icon: Icons.payments_outlined),
      MetricCard(label: 'Gastos', value: '25.000', currency: 'CUP',
        icon: Icons.receipt_long_outlined, note: 'Este mes'),
      MetricCard(label: 'Promedio', value: '10.000', currency: 'CUP',
        icon: Icons.calendar_today_outlined, note: 'Por día'),
    ];
    for (final prefix in ['home-card', 'statistics-card']) {
      for (final width in [320.0, 480.0, 720.0]) {
        final columns = width >= 700 ? 3 : 2;
        await tester.binding.setSurfaceSize(Size(width, 900));
        await tester.pumpWidget(MaterialApp(home: Scaffold(
          body: SingleChildScrollView(child: Padding(
            padding: const EdgeInsets.all(16),
            child: StatisticsMetricGrid(cards: cards, columns: columns,
              keyPrefix: prefix),
          )),
        )));
        Finder cardAt(int index) => find.byKey(ValueKey(
          '$prefix-${cards[index].icon.codePoint}'));
        for (var index = 0; index < cards.length; index++) {
          final right = index == columns - 1;
          final root = cardAt(index);
          final icon = find.descendant(of: root,
            matching: find.byIcon(cards[index].icon));
          final rect = tester.getRect(root);
          final iconRect = tester.getRect(icon);
          expect(right ? rect.right - iconRect.right : iconRect.left - rect.left,
            lessThan(30));
          final label = tester.widget<Text>(find.descendant(of: root,
            matching: find.text(cards[index].label)));
          expect(label.textAlign, right ? TextAlign.right : TextAlign.left);
          final valueFinder = find.descendant(of: root,
            matching: find.byType(FittedBox));
          final value = tester.widget<FittedBox>(valueFinder);
          final valueRect = tester.getRect(valueFinder);
          final labelRect = tester.getRect(find.descendant(of: root,
            matching: find.text(cards[index].label)));
          // Values occupy the space beside the icon, with the title below.
          expect(valueRect.bottom, lessThanOrEqualTo(labelRect.top));
          if (width >= 320) {
            expect(right ? valueRect.right : iconRect.right,
              lessThanOrEqualTo(right ? iconRect.left : valueRect.left));
            expect(valueRect.top, lessThan(iconRect.bottom));
          }
          final currency = find.descendant(of: root, matching: find.text('CUP'));
          expect(currency, findsOneWidget);
          expect(tester.getRect(currency).bottom, lessThanOrEqualTo(labelRect.top));
          expect(value.alignment,
            right ? Alignment.centerRight : Alignment.centerLeft);
          if (cards[index].note != null) {
            final note = tester.widget<Text>(find.descendant(of: root,
              matching: find.text(cards[index].note!)));
            expect(note.textAlign, right ? TextAlign.right : TextAlign.left);
            expect(tester.getRect(find.descendant(of: root,
              matching: find.text(cards[index].note!))).bottom,
              lessThanOrEqualTo(labelRect.top));
          }
        }
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('Metric units share the discreet efficiency style in both themes',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final brightness in Brightness.values) {
      for (final width in [320.0, 390.0, 720.0]) {
        await tester.binding.setSurfaceSize(Size(width, 900));
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StatisticsMetricGrid(
                columns: width >= 700 ? 3 : 2,
                cards: const [
                  MetricCard(label: 'Ingresos', value: '736.412',
                    currency: 'CUP', icon: Icons.payments_outlined),
                  MetricCard(label: 'Distancia', value: '958',
                    currency: 'km', icon: Icons.route_outlined),
                  MetricCard(label: 'Eficiencia', value: '85,39',
                    note: 'CUP/km', icon: Icons.speed_outlined),
                ],
              ),
            ),
          )),
        ));
        final expected = brightness == Brightness.dark
            ? const Color(0xFFA8BACD) : const Color(0xFF52677B);
        for (final unit in ['CUP', 'km', 'CUP/km']) {
          final style = tester.widget<Text>(find.text(unit)).style!;
          expect(style.fontSize, 11);
          expect(style.fontWeight, FontWeight.w500);
          expect(style.color, expected);
        }
        for (final value in ['736.412', '958', '85,39']) {
          expect(tester.widget<Text>(find.text(value)).style!.fontSize, 26);
        }
        expect(tester.takeException(), isNull);
      }
    }
  });

}
