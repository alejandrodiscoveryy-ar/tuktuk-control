import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Trabajo usa render vectorial; carreras mantienen su mapa protegido',
    () {
      final code = File(
        'lib/presentation/marketplace_jobs.dart',
      ).readAsStringSync();
      final begin = code.indexOf(
        'Widget _workMapSurface(BuildContext context)',
      );
      final end = code.indexOf(
        'Widget _buildWorkMapHome(BuildContext context)',
      );
      expect(begin, greaterThan(0));
      expect(end, greaterThan(begin));
      final surface = code.substring(begin, end);
      expect(surface, contains('return MarketplaceDriverMap('));
      expect(surface, contains('configuration: config'));
      expect(surface, contains('return MarketplaceDriverMap('));
      expect(surface, isNot(contains('TileLayer(')));
      expect(surface, isNot(contains('FlutterMap(')));
      expect(surface, contains('idleZoom: _workMapZoom'));
      expect(surface, contains("'mapbox/dark-v11'"));
      expect(surface, contains('Reintentar'));
    },
  );
  test('Conserva accesos y operacion de Trabajo', () {
    final code = File(
      'lib/presentation/marketplace_jobs.dart',
    ).readAsStringSync();
    expect(code, contains("ValueKey('work-map-open-menu')"));
    expect(code, contains("ValueKey('work-map-availability-toggle')"));
    expect(code, contains('onAccept: () => _acceptJob(job)'));
    expect(
      code,
      contains('managementSection: MarketplaceManagementSection.wallet'),
    );
  });
}
