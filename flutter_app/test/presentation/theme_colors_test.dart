import 'package:control_tuk_tuk/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el tema oscuro conserva sus colores de identidad', () {
    final theme = buildAppTheme(Brightness.dark);

    expect(theme.scaffoldBackgroundColor, kBg);
    expect(theme.colorScheme.surface, kSurface);
    expect(theme.colorScheme.surfaceContainerHighest, kSurfaceHigh);
    expect(theme.colorScheme.onSurface, kText);
    expect(theme.colorScheme.onSurfaceVariant, kMuted);
    expect(theme.colorScheme.outline, kOutline);
    expect(theme.colorScheme.primary, kPrimary);
    expect(theme.colorScheme.secondary, kSecondary);
  });

  test('el tema alternativo expone superficies oscuras y acentos azules', () {
    final scheme = buildAppTheme(Brightness.light).colorScheme;

    expect(scheme.surface, kSurface);
    expect(scheme.onSurface, kText);
    expect(scheme.onSurfaceVariant, kMuted);
    expect(scheme.surfaceContainerHighest, kSurfaceHigh);
    expect(scheme.primary, const Color(0xFF2F80ED));
    expect(scheme.secondary, const Color(0xFF3B82F6));
    expect(
      _contrast(scheme.onSurfaceVariant, scheme.surface),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('componentes principales consumen los colores del tema claro', (
    tester,
  ) async {
    final theme = buildAppTheme(Brightness.light);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(body: Label('Resumen')),
      ),
    );

    final text = tester.widget<Text>(find.text('RESUMEN'));
    expect(text.style?.color, theme.colorScheme.onSurfaceVariant);
  });
}

double _contrast(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first.computeLuminance()
      : second.computeLuminance();
  final darker = first.computeLuminance() > second.computeLuminance()
      ? second.computeLuminance()
      : first.computeLuminance();
  return (lighter + .05) / (darker + .05);
}
