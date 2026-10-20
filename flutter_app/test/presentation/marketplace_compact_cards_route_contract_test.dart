import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final jobs = File('lib/presentation/marketplace_jobs.dart').readAsStringSync();
  final map = File('lib/presentation/marketplace_driver_map.dart').readAsStringSync();

  test('paneles compactos limitan altura sin rellenar huecos', () {
    expect(jobs, contains('alignment: Alignment.bottomCenter'));
    expect(jobs, contains('mainAxisSize: MainAxisSize.min'));
    expect(jobs, contains('fit: FlexFit.loose'));
    expect(jobs, contains("'work-active-price'"));
    expect(jobs, contains("'work-map-offer-price-"));
    expect(jobs, contains("'work-map-offer-accept-"));
  });

  test('aviso y reintento de ruta quedan encima de la ficha', () {
    expect(map, contains('top: ride != null ? 96 : null'));
    expect(map, contains("tooltip: 'Reintentar cargar ruta'"));
    expect(map, contains('onPressed: () => unawaited(_load())'));
  });

  test('omitir evaluacion no se presenta como finalizar carrera', () {
    expect(jobs, contains('forFinishing: true'));
    expect(jobs, contains("'Volver a carrera'"));
    expect(jobs, contains('La carrera se cierra al enviar tu evaluación.'));
  });
}