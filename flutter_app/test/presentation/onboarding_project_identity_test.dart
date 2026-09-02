import 'package:control_tuk_tuk/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('onboarding sin logo remoto no muestra identidad visual antigua',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            child: onboardingProjectIdentityForTesting(
              ProjectIdentity.fallback,
            ),
          ),
        ),
      ),
    );

    expect(find.text('TukTuk Control'), findsNothing);
    expect(find.byType(Image), findsNothing);
  });
}
