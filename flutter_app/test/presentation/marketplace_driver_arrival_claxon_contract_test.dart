import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File('lib/presentation/marketplace_jobs.dart').readAsStringSync();
  test('El boton avisa al cliente y reutiliza mark_pickup', () {
    expect(src, contains("'mark_pickup' => 'Tocar claxon'"));
    expect(src, contains("final action = finishing ? 'finish_service' : 'mark_pickup';"));
    expect(src, contains('if (canFinish || canNotify)'));
    expect(src, contains("? 'Finalizar carrera'"));
    expect(src, contains(": 'Tocar claxon'"));
    expect(src, contains('_ensureEnRouteInternally(job)'));
    expect(src, isNot(contains("'Salir hacia el cliente'")));
    expect(src, contains("action == 'mark_pickup'"));
  });
  test('La calificacion no se ofrece antes de llegada', () {
    final start = src.indexOf('bool _marketplaceJobCanFinish(MarketplaceJob job)');
    final end = src.indexOf('bool _marketplaceJobCanDriverCancel',start);
    final segment = src.substring(start,end);
    expect(segment, contains("job.status == 'pickup'"));
    expect(segment, contains("job.status == 'in_progress'"));
    expect(segment, isNot(contains("job.status == 'en_route'")));
  });
}
