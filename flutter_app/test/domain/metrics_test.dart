import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('La búsqueda de Revolico codifica términos personalizados', () {
    final uri = buildRevolicoSearchUri(' batería 72V & litio ');

    expect(uri.scheme, 'https');
    expect(uri.host, 'www.revolico.com');
    expect(uri.path, '/search');
    expect(uri.queryParameters['q'], 'batería 72V & litio');
    expect(uri.queryParameters['order'], 'relevance');
    expect(uri.toString(), isNot(contains(' ')));
  });

  test('El soporte abre el número correcto de WhatsApp', () {
    final uri = buildWhatsAppSupportUri();

    expect(uri.scheme, 'https');
    expect(uri.host, 'wa.me');
    expect(uri.path, '/5355592873');
    expect(uri.queryParameters['text'],
        'Hola, necesito ayuda con TukTuk Control.');
    expect(uri.toString(), isNot(contains(' ')));
  });

  test('Metrics calcula ingresos, distancia, eficiencia y cargas', () {
    final records = [
      DailyRecord(
        id: 'first',
        date: DateTime(2026, 7, 14),
        earnings: 3000,
        odometer: 100,
        expense: 200,
      ),
      DailyRecord(
        id: 'second',
        date: DateTime(2026, 7, 15),
        earnings: 5000,
        odometer: 150,
        batteryVoltage: 80,
      ),
    ];

    final maintenances = [
      MaintenanceRecord(
        id: 'maintenance',
        dateTime: DateTime(2026, 7, 15),
        odometer: 150,
        type: 'General',
        description: 'Mantenimiento de prueba',
        cost: 1000,
      ),
    ];
    final metrics = Metrics(records, maintenances);

    expect(metrics.totalEarnings, 8000);
    expect(metrics.totalExpenses, 1200);
    expect(metrics.netEarnings, 6800);
    expect(metrics.currentCycleExpenses, 1200);
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

  test('comparación mensual usa exclusivamente el mes anterior como 100%', () {
    final metrics = Metrics([
      DailyRecord(
        id: 'may',
        date: DateTime(2026, 5, 10),
        earnings: 97000,
        odometer: 0,
      ),
      DailyRecord(
        id: 'june-a',
        date: DateTime(2026, 6, 2),
        earnings: 4000,
        odometer: 0,
      ),
      DailyRecord(
        id: 'june-b',
        date: DateTime(2026, 6, 9),
        earnings: 6000,
        odometer: 0,
      ),
    ]);

    final comparison = metrics.comparisonFor(DateTime(2026, 6));

    expect(comparison.currentEarnings, 10000);
    expect(comparison.previousEarnings, 97000);
    expect(comparison.percentage, closeTo(10.309, .001));
    expect(comparison.scaleMaximum, 100);
  });

  test('la escala mensual se extiende cuando el resultado supera 100%', () {
    final comparison = MonthlyComparison(
      month: DateTime(2026, 6),
      currentEarnings: 129000,
      previousEarnings: 97000,
    );

    expect(comparison.percentage, closeTo(132.989, .001));
    expect(comparison.scaleMaximum, comparison.percentage);
  });

  test('el velocímetro formatea miles sin decimales y cambia por zona', () {
    expect(moneyCompact(10000), r'$10k');
    expect(moneyCompact(97000, includeCurrency: false), '97k');
    expect(moneyCompact(129000), r'$129k');
    expect(monthlyGaugeColor(10).toARGB32(), 0xFFFF2340);
    expect(monthlyGaugeColor(40).toARGB32(), 0xFFFF7A00);
    expect(monthlyGaugeColor(60).toARGB32(), 0xFFFFD600);
    expect(monthlyGaugeColor(90).toARGB32(), 0xFF63D916);
    expect(monthlyGaugeColor(100).toARGB32(), 0xFF168BFF);
    expect(monthlyGaugeColor(101).toARGB32(), 0xFFB832FF);
    expect(monthlyGaugeColor(133).toARGB32(), 0xFFB832FF);
  });
}
