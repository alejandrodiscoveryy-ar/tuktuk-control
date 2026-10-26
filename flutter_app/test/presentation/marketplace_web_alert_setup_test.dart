import 'package:control_tuk_tuk/main.dart' show MarketplaceWebAlertSetupDialog;
import 'package:control_tuk_tuk/services/push_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('permiso bloqueado muestra pasos y permite seguir descansando', (
    tester,
  ) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                answer = await showDialog<bool>(
                  context: context,
                  builder: (_) => MarketplaceWebAlertSetupDialog(
                    initialStatus:
                        MarketplaceWebAlertReadiness.notificationsBlocked,
                    recheck: () async =>
                        MarketplaceWebAlertReadiness.notificationsBlocked,
                    playSound: () {},
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Prepara las alertas de trabajo'), findsOneWidget);
    expect(find.text('Seguir descansando'), findsOneWidget);
    expect(find.text('Comprobar de nuevo'), findsOneWidget);
    await tester.tap(find.text('Comprobar de nuevo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('siguen bloqueadas'), findsOneWidget);
    await tester.tap(find.text('Seguir descansando'));
    await tester.pumpAndSettle();
    expect(answer, false);
  });

  testWidgets('al recuperar el permiso se cierra la guia con exito', (
    tester,
  ) async {
    bool? answer;
    var checks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                answer = await showDialog<bool>(
                  context: context,
                  builder: (_) => MarketplaceWebAlertSetupDialog(
                    initialStatus:
                        MarketplaceWebAlertReadiness.tokenUnavailable,
                    recheck: () async {
                      checks += 1;
                      return MarketplaceWebAlertReadiness.ready;
                    },
                    playSound: () {},
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comprobar de nuevo'));
    await tester.pumpAndSettle();
    expect(checks, 1);
    expect(answer, true);
    expect(find.byType(MarketplaceWebAlertSetupDialog), findsNothing);
  });
}
