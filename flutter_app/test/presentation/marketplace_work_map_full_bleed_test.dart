import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Mapa de Trabajos sin recorte, otros mapas conservan bordes', () {
    final map =
        File('lib/presentation/marketplace_driver_map.dart').readAsStringSync();
    final jobs =
        File('lib/presentation/marketplace_jobs.dart').readAsStringSync();
    expect(map, contains('this.fullBleed = false'));
    // Dart format puede partir la expresion ternaria en varias lineas.
    // Verificar la condicion real sin depender de espacios ni saltos.
    expect(
      RegExp(
        r'borderRadius:\s*widget\.fullBleed\s*\?\s*BorderRadius\.zero\s*:\s*BorderRadius\.circular\(18\)',
      ).hasMatch(map),
      isTrue,
    );
    expect(map, contains('BorderRadius.zero'));
    expect(jobs, contains('fullBleed: true,'));
  });
  test('Creditos de Mapbox visibles y fuera de la barra inferior', () {
    final vector = File('lib/presentation/marketplace_driver_vector_map.dart')
        .readAsStringSync();
    expect(vector, contains('map.logo.updateSettings'));
    expect(vector, contains('map.attribution.updateSettings'));
    expect(vector, contains('marginBottom: bottomMargin'));
  });
}
