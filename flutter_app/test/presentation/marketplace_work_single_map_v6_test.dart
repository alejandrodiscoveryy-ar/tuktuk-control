import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final jobs = File('lib/presentation/marketplace_jobs.dart').readAsStringSync();
  final map = File('lib/presentation/marketplace_driver_map.dart').readAsStringSync();

  test('carrera activa se gestiona desde el mapa principal', () {
    final begin = jobs.indexOf('Widget _buildWorkMapHome(BuildContext context)');
    final end = jobs.indexOf('Widget _buildWorkPanel(BuildContext context)', begin);
    expect(begin, greaterThanOrEqualTo(0));
    expect(end, greaterThan(begin));
    final home = jobs.substring(begin, end);
    expect(home, contains('work-map-advance-job'));
    expect(home, contains('work-map-contact-customer'));
    expect(home, contains('work-map-cancel-job'));
    expect(home, contains('_advanceJob(active!)'));
    expect(home, contains('_contactJob(active!)'));
    expect(home, contains('_cancelJob(active!)'));
    expect(home, isNot(contains('Gestionar servicio en curso')));
    expect(home, contains('onAccept: () => _acceptJob(job)'));
  });

  test('evaluacion y retorno preservan estado real del servidor', () {
    final start = jobs.indexOf('Future<void> _advanceJob(MarketplaceJob job)');
    final end = jobs.indexOf('Future<void> _cancelJob(MarketplaceJob job)', start);
    final advance = jobs.substring(start, end);
    expect(advance, contains('await _showCustomerRatingSurvey(job.id)'));
    expect(advance, contains('await _refreshAfterJobMutation()'));
    expect(advance, contains('_active.isEmpty && _workPanelIndex == 0'));
    expect(advance, contains('_refreshIncome()'));
  });

  test('leyenda permanece disponible solo en mapas detallados', () {
    expect(jobs, contains('MarketplaceDriverMap(job: active, showLegend: false)'));
    expect(map, contains('this.showLegend = true'));
    expect(map, contains('if (widget.showLegend)'));
  });
}