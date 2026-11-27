import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  await initializeDateFormatting('es');

  test('La búsqueda de Revolico codifica términos personalizados', () {
    final uri = buildRevolicoSearchUri(' batería 72V & litio ');

    expect(uri.scheme, 'https');
    expect(uri.host, 'www.revolico.com');
    expect(uri.path, '/search');
    expect(uri.queryParameters['q'], 'batería 72V & litio');
    expect(uri.queryParameters['order'], 'relevance');
    expect(uri.toString(), isNot(contains(' ')));
  });

  test('Metrics calcula ingresos, distancia, eficiencia y cargas', () {
    final today = DateTime.now();
    final firstDayOfCurrentMonth = DateTime(today.year, today.month);
    final secondDayOfCurrentMonth = DateTime(today.year, today.month, 2);
    final records = [
      DailyRecord(
        id: 'first',
        date: firstDayOfCurrentMonth,
        earnings: 3000,
        odometer: 100,
        expense: 200,
      ),
      DailyRecord(
        id: 'second',
        date: secondDayOfCurrentMonth,
        earnings: 5000,
        odometer: 150,
        batteryVoltage: 80,
      ),
    ];

    final maintenances = [
      MaintenanceRecord(
        id: 'maintenance',
        dateTime: today,
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
    expect(metrics.cycleSummaries.single.expenses, 1200);
  });

  test('mejor día suma ingresos de varios registros y excluye eliminados', () {
    final day = DateTime(2026, 11, 26);
    final metrics = Metrics([
      DailyRecord(id: 'a', date: day.add(const Duration(hours: 8)), earnings: 200000, odometer: 0),
      DailyRecord(id: 'b', date: day.add(const Duration(hours: 9)), earnings: 10000, odometer: 0),
      DailyRecord(id: 'c', date: DateTime(2026, 11, 25), earnings: 205000, odometer: 0),
      DailyRecord(id: 'd', date: DateTime(2026, 11, 24), earnings: 500000, odometer: 0, deletedAt: day),
    ]);
    expect(metrics.bestEarningDay!.key, day);
    expect(metrics.bestEarningDay!.value, 210000);
    expect(Metrics(const []).bestEarningDay, isNull);
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
  test('maintenance-only months count as expenses and deleted rows never contribute', () {
    final metrics = Metrics([
      DailyRecord(id: 'income', date: DateTime(2026, 7, 1), earnings: 73850, odometer: 100),
      DailyRecord(id: 'expense', date: DateTime(2026, 7, 5), earnings: 0, odometer: 0, expense: 12500),
      DailyRecord(id: 'deleted', date: DateTime(2026, 7, 5), earnings: 99999, odometer: 0,
        expense: 99999, deletedAt: DateTime(2026, 7, 6)),
    ], [
      MaintenanceRecord(id: 'maint-jul', dateTime: DateTime(2026, 7, 10), odometer: 100,
        type: 'General', description: '', cost: 10000),
      MaintenanceRecord(id: 'maint-aug', dateTime: DateTime(2026, 8, 10), odometer: 100,
        type: 'General', description: '', cost: 3000),
      MaintenanceRecord(id: 'maint-deleted', dateTime: DateTime(2026, 8, 10), odometer: 100,
        type: 'General', description: '', cost: 99999, deletedAt: DateTime(2026, 8, 11)),
    ]);
    expect(metrics.totalEarnings, 73850);
    expect(metrics.totalExpenses, 25500);
    expect(metrics.netEarnings, 48350);
    expect(metrics.cycleSummaries, hasLength(2));
    expect(metrics.cycleSummaries.first.expenses, 22500);
    expect(metrics.cycleSummaries.last.earnings, 0);
    expect(metrics.cycleSummaries.last.expenses, 3000);
  });

  test('verified financial snapshot uses complete server history and retains only pending local edits', () {
    DailyRecord daily(String id, double income, double expense, {int month = 7, int day = 1, String owner = 'driver', String vehicle = 'car', DateTime? deleted}) => DailyRecord(
      id: id, date: DateTime(2026, month, day), earnings: income, expense: expense,
      odometer: 0, userId: owner, vehicleId: vehicle, deletedAt: deleted,
    );
    RemoteChange change(SyncEntityType type, String id, Map<String, dynamic> payload, {DateTime? deleted}) => RemoteChange(
      entityType: type, entityId: id, userId: 'driver', vehicleId: 'car',
      updatedAt: DateTime.utc(2026, 11, 26), deletedAt: deleted,
      deviceId: 'server', payload: payload, serverVersion: 1, serverSeq: 0,
    );
    final income = daily('income', 73850, 0);
    final garage = daily('garage', 0, 10000, month: 8, day: 6);
    final ordinary = daily('expense', 0, 3000, month: 8);
    final orphan = daily('marketplace-job-123', 2000, 0);
    final verified = daily('marketplace-job-456', 2500, 0);
    final removed = daily('removed', 99999, 99999, deleted: DateTime(2026, 7, 2));
    final maintenance = MaintenanceRecord(
      id: 'maintenance', dateTime: DateTime(2026, 7, 3), odometer: 0,
      type: 'General', description: '', cost: 15000, userId: 'driver', vehicleId: 'car',
    );
    final snapshot = FinancialHistorySnapshot(
      userId: 'driver', vehicleId: 'car',
      verifiedMarketplaceIds: {verified.id},
      changes: [
        for (final record in [income, garage, ordinary, orphan, verified, removed])
          change(SyncEntityType.dailyRecord, record.id, record.toMap(), deleted: record.deletedAt),
        change(SyncEntityType.maintenance, maintenance.id, maintenance.toMap()),
      ],
    );
    final confirmed = snapshot.confirmed;
    expect(confirmed.totalEarnings, 76350);
    expect(confirmed.totalExpenses, 28000);
    expect(confirmed.cycleSummaries.last.expenses, 13000);
    expect(snapshot.matchesLocal([income, garage, ordinary, verified], [maintenance]), isTrue);
    expect(snapshot.matchesLocal([daily('income', 51000, 0), garage, ordinary, verified], [maintenance]), isFalse);
    expect(snapshot.matchesLocal([income, garage, ordinary, verified], []), isFalse);
    final pending = snapshot.withPending([
      daily('garage', 0, 11000, month: 8, day: 6),
      daily('new', 500, 0),
      daily('ordinary-other', 99999, 99999, owner: 'other'),
      daily('expense', 0, 3000, month: 8, deleted: DateTime(2026, 8, 2)),
    ], []);
    expect(pending.totalEarnings, 76850);
    expect(pending.totalExpenses, 26000);
    expect(snapshot.confirmed.totalExpenses, 28000);

    // Closing or reloading the WebApp must not replace verified values
    // with an incomplete local history.
    final cache = snapshot.toCache();
    final reopened = FinancialHistorySnapshot.fromCache(cache,
      userId: 'driver', vehicleId: 'car');
    expect(reopened.confirmed.totalEarnings, 76350);
    expect(reopened.confirmed.totalExpenses, 28000);
    expect(reopened.confirmed.cycleSummaries.last.expenses, 13000);
    expect(reopened.matchesLocal([income, garage, ordinary, verified], [maintenance]), isTrue);
    expect(() => FinancialHistorySnapshot.fromCache(cache,
      userId: 'other', vehicleId: 'car'), throwsStateError);
    expect(() => FinancialHistorySnapshot.fromCache(cache,
      userId: 'driver', vehicleId: 'other'), throwsStateError);
  });

}
