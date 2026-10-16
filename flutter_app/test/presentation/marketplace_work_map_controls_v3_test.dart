import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/presentation/marketplace_jobs.dart').readAsStringSync();

  test('Trabajo presenta disponibilidad compacta en lugar de pastilla plana', () {
    final start = source.indexOf('Widget _buildWorkMapHome(BuildContext context)');
    final end = source.indexOf('Widget _buildWorkPanel(', start);
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    final home = source.substring(start, end);
    expect(home, contains('_workPremiumAvatar(photo)'));
    expect(home, contains('_workPremiumAvailability('));
    expect(home, contains('BoxConstraints(maxWidth: 238)'));
    expect(source, contains("ValueKey('work-map-availability-toggle')"));
    expect(source, contains('_setAcceptingJobs(!available)'));
    expect(source, contains('_openActivation'));
  });

  test('Mapa agrupa controles sin cambiar las acciones existentes', () {
    final start = source.indexOf('Widget _buildWorkMapHome(BuildContext context)');
    final end = source.indexOf('Widget _buildWorkPanel(', start);
    final home = source.substring(start, end);
    expect(home, contains('_workPremiumMapTools()'));
    expect(home, isNot(contains('FloatingActionButton.small(')));
    expect(source, contains("actionKey: 'work-map-locate'"));
    expect(source, contains("actionKey: 'work-map-zoom-in'"));
    expect(source, contains("actionKey: 'work-map-zoom-out'"));
    expect(source, contains('onPressed: () => unawaited(_centerWorkMap())'));
    expect(source, contains('_workMapZoom = (_workMapZoom + 1)'));
    expect(source, contains('_workMapZoom = (_workMapZoom - 1)'));
    expect(source, contains('onAccept: () => _acceptJob(job)'));
  });

  test('Carrera activa conserva mapa, menú y acceso a su gestión', () {
    expect(source, contains('MarketplaceDriverMap(job: active)'));
    expect(source, contains("ValueKey('work-map-open-menu')"));
    expect(source, contains('if (_workDrawerOpen) _buildWorkDrawer(context)'));
    expect(source, contains('Gestionar servicio en curso'));
  });
  test('Boton grande para trabajar y descansar con toda la tarjeta tactil', () {
    final start = source.indexOf('Widget _workPremiumAvailability(');
    final end = source.indexOf('Widget _workPremiumMapAction(', start);
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    final availability = source.substring(start, end);
    expect(availability, contains('height: 70'));
    expect(availability, contains('width: 52'));
    expect(availability, contains('height: 52'));
    expect(availability, contains('Icons.pause_rounded'));
    expect(availability, contains('Icons.play_arrow_rounded'));
    expect(availability, contains('Toca para trabajar'));
    expect(availability, contains('Toca para descansar'));
    expect(availability, contains('_setAcceptingJobs(!available)'));
    expect(availability, contains('onRide'));
  });

  test('Mapa despejado sin carreras y ofertas reales visibles', () {
    final start = source.indexOf('Widget _buildWorkMapHome(BuildContext context)');
    final end = source.indexOf('Widget _buildWorkPanel(', start);
    final home = source.substring(start, end);
    expect(home, isNot(contains("'Esperando solicitudes'")));
    expect(home, isNot(contains("'Activa Trabajar para recibir solicitudes'")));
    expect(home, contains('if (onRide ||'));
    expect(home, contains('_available.isNotEmpty ||'));
    expect(home, contains('_error != null)'));
    expect(home, contains('bottom: _available.isNotEmpty'));
    expect(home, contains('onAccept: () => _acceptJob(job)'));
    expect(home, contains('Gestionar servicio en curso'));
  });
}