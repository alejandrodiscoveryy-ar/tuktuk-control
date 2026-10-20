import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final jobs = File('lib/presentation/marketplace_jobs.dart').readAsStringSync();
  final driver = File('lib/presentation/marketplace_driver_map.dart').readAsStringSync();
  final vector = File('lib/presentation/marketplace_driver_vector_map.dart').readAsStringSync();

  test('La misma superficie sirve para espera y carrera', () {
    final a = jobs.indexOf('Widget _workMapSurface(BuildContext context)');
    final b = jobs.indexOf('Widget _workPremiumAvatar(', a);
    final surface = jobs.substring(a, b);
    expect(surface, contains('return MarketplaceDriverMap('));
    expect(surface, contains('job: active'));
    expect(surface, contains('idleCenter: center'));
    expect(surface, isNot(contains('mbx.MapWidget(')));
    expect(driver, contains('final MarketplaceJob? job;'));
    expect(driver, contains('if (widget.job == null)'));
    expect(driver, contains('widget.showIdleLocation && ride == null'));
    expect(jobs, contains('showIdleLocation: _workMapPosition != null'));
    expect(driver, isNot(contains('ValueKey(')));
  });
  test('La ruta actualiza GeoJSON y camara, sin recrear el mapa', () {
    expect(vector, contains('mbx.MapWidget('));
    expect(vector, contains('await s.updateGeoJSON(item.value)'));
    expect(vector, contains('await map.setCamera(mbx.CameraOptions('));
    expect(vector, contains('map.setStyleLayerProperty('));
    expect(vector, contains('final MarketplaceMapPoint? pickup;'));
    expect(vector, contains('final MarketplaceMapPoint? destination;'));
  });
  test('Cristal marino translucido conserva botones de servicio', () {
    final a = jobs.indexOf('child: onRide');
    expect(a, greaterThan(0));
    final b = jobs.indexOf(': _available.isNotEmpty', a);
    expect(b, greaterThan(a));
    final card = jobs.substring(a, b);
    expect(card, contains('work-map-glass-active-card'));
    expect(card, contains('ui.ImageFilter.blur'));
    expect(card, contains('Color(0xC00A2833)'));
    expect(card, contains('work-map-advance-job'));
    expect(card, contains('work-map-contact-customer'));
    expect(card, contains('work-map-cancel-job'));
    expect(card, contains('_advanceJob(active)'));
    expect(card, contains('_contactJob(active)'));
    expect(card, contains('_cancelJob(active)'));
  });
}