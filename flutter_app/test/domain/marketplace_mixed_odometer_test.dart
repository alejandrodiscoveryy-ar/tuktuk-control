import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';

DailyRecord manual(String id, int day, double odo, {double earnings = 0}) => DailyRecord(
  id: id, date: DateTime.utc(2026, 10, day), earnings: earnings,
  odometer: odo, userId: 'owner', vehicleId: 'vehicle',
);
DailyRecord job(String id, int day, double km, {double earnings = 100}) => DailyRecord(
  id: 'marketplace-job-$id', date: DateTime.utc(2026, 10, day, 12),
  earnings: earnings, odometer: 0, marketplaceDistanceKm: km,
  userId: 'owner', vehicleId: 'vehicle',
);

void main() {
  test('ciclo incluye carreras cuando no hay lectura inicial', () {
    final now = DateTime.now();
    final first = DailyRecord(
      id: 'marketplace-job-current-a',
      date: now,
      earnings: 200,
      odometer: 20,
      marketplaceDistanceKm: 20,
    );
    final second = DailyRecord(
      id: 'marketplace-job-current-b',
      date: now,
      earnings: 300,
      odometer: 30,
      marketplaceDistanceKm: 10,
    );
    expect(Metrics([first, second]).currentCycleDistance, 30);
  });

  test('sin ancla provisional cero; con ancla retroactiva se reajusta', () {
    final a = job('a', 2, 20, earnings: 2000);
    final b = job('b', 4, 10, earnings: 1000);
    expect(marketplaceRebasedOdometers([a, b]), {
      a.id: 20, b.id: 30,
    });
    expect(Metrics([a, b]).marketplaceWorkedKm, 30);
    expect(Metrics([a, b]).totalDistance, 30);
    expect(marketplaceRebasedOdometers([b, manual('m', 1, 500), a]), {
      a.id: 520, b.id: 530,
    });
    expect(marketplaceRebasedOdometers([a, b, manual('m', 1, 600)]), {
      a.id: 620, b.id: 630,
    });
  });
  test('ancla intermedia 560 no se sobrescribe ni duplica distancia', () {
    final a = job('a', 2, 20);
    final b = job('b', 4, 10);
    final c = job('c', 6, 15);
    final anchor = manual('r', 5, 560, earnings: 300);
    final result = marketplaceRebasedOdometers([
      anchor, c, b, manual('base', 1, 500), a,
      manual('expense', 3, 0),
    ]);
    expect(result, {a.id: 520, b.id: 530, c.id: 575});
    expect(anchor.odometer, 560);
    expect(anchor.earnings, 300);
  });
  test('el orden es determinista, excluye borrados y no cambia ganancias', () {
    final a = job('a', 2, 20);
    final b = job('b', 2, 10);
    final other = job('other', 3, 9);
    final removed = DailyRecord(
      id: 'marketplace-job-deleted', date: DateTime.utc(2026, 10, 1),
      earnings: 600, odometer: 900, marketplaceDistanceKm: 50,
      deletedAt: DateTime.utc(2026, 10, 2),
    );
    final result = marketplaceRebasedOdometers([b, removed, a]);
    expect(result, {a.id: 20, b.id: 30});
    expect(a.earnings + b.earnings + other.earnings, 300);
  });
  test('conservar fecha y distancia fuente en serialización para otro dispositivo', () {
    final original = job('sync', 7, 14.5);
    final saved = DailyRecord.fromMap(original.toMap());
    expect(saved.date.hour, 12);
    expect(saved.marketplaceDistanceKm, 14.5);
    expect(saved.withMarketplaceValues(derivedOdometer: 510).earnings, original.earnings);
    expect(saved.withSyncInfo(deviceId: 'other').marketplaceDistanceKm, 14.5);
  });
}
