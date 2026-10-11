import 'dart:convert';

import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const pickup = MarketplaceMapPoint(
    label: 'Recogida',
    lat: 23.08,
    lon: -82.37,
  );
  const destination = MarketplaceMapPoint(
    label: 'Destino',
    lat: 23.10,
    lon: -82.39,
  );
  const driver = MarketplaceMapPoint(
    label: 'Conductor',
    lat: 23.07,
    lon: -82.36,
  );

  test('los pines conservan las coordenadas geograficas Mapbox', () {
    final json = jsonDecode(marketplaceDriverPointGeoJson(pickup)) as Map;
    final features = json['features'] as List;
    expect(features, hasLength(1));
    expect((features.single as Map)['geometry']['coordinates'], [
      -82.37,
      23.08,
    ]);
    expect(
      (jsonDecode(marketplaceDriverPointGeoJson(null)) as Map)['features'],
      isEmpty,
    );
  });

  test('la polilinea solo se publica con al menos dos puntos', () {
    expect(
      (jsonDecode(marketplaceDriverLineGeoJson([pickup])) as Map)['features'],
      isEmpty,
    );
    final json =
        jsonDecode(marketplaceDriverLineGeoJson([pickup, destination])) as Map;
    final geometry = (json['features'] as List).single['geometry'];
    expect(geometry['type'], 'LineString');
    expect(geometry['coordinates'], [
      [-82.37, 23.08],
      [-82.39, 23.10],
    ]);
  });

  test('se prioriza la recogida hasta llegar al cliente', () {
    expect(marketplaceDriverGoingToPickup('accepted'), isTrue);
    expect(marketplaceDriverGoingToPickup('en_route'), isTrue);
    expect(marketplaceDriverGoingToPickup('pickup'), isTrue);
    expect(marketplaceDriverGoingToPickup('in_progress'), isFalse);
    expect(marketplaceDriverGoingToPickup('settled'), isFalse);
  });

  test('el encuadre considera conductor, recogida y destino', () {
    final center = marketplaceDriverMapCenter(
      pickup: pickup,
      destination: destination,
      driver: driver,
      activeRoute: const [pickup, destination],
    );
    expect(center.latitude, closeTo(23.085, .0001));
    expect(center.longitude, closeTo(-82.375, .0001));
    final zoom = marketplaceDriverMapZoom(
      pickup: pickup,
      destination: destination,
      driver: driver,
      activeRoute: const [pickup, destination],
    );
    expect(zoom, inInclusiveRange(9.0, 14.0));
  });
}
