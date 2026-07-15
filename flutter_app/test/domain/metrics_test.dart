import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Metrics calcula ingresos, distancia, eficiencia y cargas', () {
    final records = [
      DailyRecord(
        id: 'first',
        date: DateTime(2026, 7, 14),
        earnings: 3000,
        odometer: 100,
      ),
      DailyRecord(
        id: 'second',
        date: DateTime(2026, 7, 15),
        earnings: 5000,
        odometer: 150,
        chargeTo80v: true,
      ),
    ];

    final metrics = Metrics(records);

    expect(metrics.totalEarnings, 8000);
    expect(metrics.totalDistance, 50);
    expect(metrics.efficiency, 160);
    expect(metrics.latestOdometer, 150);
    expect(metrics.chargeEvents, 1);
  });

  test('Metrics tolera una lista vacía', () {
    final metrics = Metrics(const []);

    expect(metrics.totalEarnings, 0);
    expect(metrics.totalDistance, 0);
    expect(metrics.efficiency, 0);
    expect(metrics.latestOdometer, 0);
    expect(metrics.chargeEvents, 0);
  });
}
