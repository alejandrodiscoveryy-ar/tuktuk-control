import 'package:control_tuk_tuk/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Store has colorful equally sized categories and larger icons',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: const Scaffold(body: StoreScreen()),
    ));
    final battery = find.byKey(const ValueKey('store-category-Baterías'));
    final tools = find.byKey(const ValueKey('store-category-Herramientas'));
    expect(battery, findsOneWidget);
    expect(tools, findsOneWidget);
    expect(tester.getSize(battery), tester.getSize(tools));
    final firstIcon = tester.widget<Icon>(find.descendant(
      of: battery, matching: find.byIcon(Icons.battery_charging_full)));
    final toolsIcon = tester.widget<Icon>(find.descendant(
      of: tools, matching: find.byIcon(Icons.handyman)));
    expect(firstIcon.size, 31);
    expect(toolsIcon.size, 31);
    expect(firstIcon.color, isNot(toolsIcon.color));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Store remains readable and scrollable on narrow displays',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(320, 540),
          textScaler: TextScaler.linear(1.5)),
        child: Scaffold(body: StoreScreen()),
      ),
    ));
    final workshop = find.byKey(const ValueKey('store-category-Talleres y reparación'));
    await tester.scrollUntilVisible(workshop, 200);
    expect(workshop, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
