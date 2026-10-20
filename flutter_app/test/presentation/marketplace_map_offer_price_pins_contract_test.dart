import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/presentation/marketplace_jobs.dart',
  ).readAsStringSync();

  test(
    'solicitudes fijan precio y aceptar fuera del desplazamiento interno',
    () {
      final start = source.indexOf('class _AvailableJobCardState');
      expect(start, greaterThan(0));
      final card = source.substring(start);
      final price = card.indexOf("'work-map-offer-price-");
      final scroll = card.indexOf('SingleChildScrollView(');
      final accept = card.indexOf("'work-map-offer-accept-");
      expect(price, greaterThan(0));
      expect(scroll, greaterThan(price));
      expect(accept, greaterThan(scroll));
      expect(card, contains('Expanded('));
      expect(card, contains("'work-map-offer-toggle-"));
      expect(source, contains('PageView.builder('));
    },
  );

  test('fichas reutilizan marcadores del mapa en origen y destino', () {
    final start = source.indexOf('class _WorkMapLocationRow');
    expect(start, greaterThan(0));
    final marker = source.substring(start);
    expect(marker, contains('assets/map_markers/pickup_green.png'));
    expect(marker, contains('assets/map_markers/destination_red.png'));
    expect(marker, contains("'Recogida'"));
    expect(marker, contains("'Destino'"));
    expect(source, contains('key: const ValueKey(\'work-active-price\')'));
  });
}
