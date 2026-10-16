import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Trabajo usa un mapa como portada sin cambiar otras pestañas', () {
    final code = File(
      'lib/presentation/marketplace_jobs.dart',
    ).readAsStringSync();
    final shell = File('lib/presentation/screens.dart').readAsStringSync();
    expect(code, contains("ValueKey('tuktuk-work-map-home')"));
    expect(code, contains('Widget _buildWorkMapHome(BuildContext context)'));
    expect(code, contains('return _buildWorkMapHome(context);'));
    expect(shell, contains('MarketplaceRecordsScreen(store: store)'));
    expect(shell, contains('MarketplaceJobsScreen('));
    expect(shell, contains('bottom: index != 2 || useDesktopNavigation'));
    expect(shell, contains('StatsScreen(store: store)'));
  });

  test('Mapa reutiliza rutas y gestión de disponibilidad existentes', () {
    final code = File(
      'lib/presentation/marketplace_jobs.dart',
    ).readAsStringSync();
    expect(code, contains('return MarketplaceDriverMap('));
    expect(code, contains('_setAcceptingJobs(!available)'));
    expect(code, contains("ValueKey('work-map-availability-toggle')"));
    expect(code, contains('final bottomNavInset = MediaQuery.paddingOf(context).bottom;'));
    expect(code, contains('bottom: bottomNavInset + 12'));
    expect(
      code,
      contains(
        RegExp(r'MarketplaceMapService\s*\(\s*Supabase\.instance\.client,?\s*\)'),
      ),
    );
    expect(code, contains('return MarketplaceDriverMap('));
    expect(code, contains('_AvailableJobCard('));
    expect(code, contains('onAccept: () => _acceptJob(job)'));
  });

  test('Accesos conservan las pantallas operativas', () {
    final code = File(
      'lib/presentation/marketplace_jobs.dart',
    ).readAsStringSync();
    expect(
      code,
      contains(RegExp(r"'Programados'\s*,\s*'Historial'")),
    );
    expect(
      code,
      contains('managementSection: MarketplaceManagementSection.wallet'),
    );
    expect(code, contains('_buildRatingsTab(context)'));
    expect(code, contains('StatsScreen(store: widget.store)'));
    expect(code, contains("ValueKey('work-map-back')"));
    expect(code, contains('if (_workDrawerOpen) _buildWorkDrawer(context)'));
  });
}
