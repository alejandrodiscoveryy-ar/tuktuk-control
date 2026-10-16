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
}