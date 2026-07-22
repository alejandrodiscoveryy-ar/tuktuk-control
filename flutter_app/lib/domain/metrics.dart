part of '../main.dart';

class Metrics {
  Metrics(this.records, [this.maintenanceRecords = const []]);

  final List<DailyRecord> records;
  final List<MaintenanceRecord> maintenanceRecords;
  DateTime get today => DateTime.now();

  List<DailyRecord> get sorted => [...records]..sort(_compareRecordsAsc);

  List<DailyRecord> get withOdometer =>
      sorted.where((record) => record.odometer > 0).toList();

  double get totalEarnings => records.fold(0, (sum, r) => sum + r.earnings);
  double get totalExpenses =>
      records.fold(0.0, (sum, r) => sum + r.expense) +
      maintenanceRecords.fold(0.0, (sum, r) => sum + (r.cost ?? 0));
  double get netEarnings => totalEarnings - totalExpenses;
  int get chargeEvents =>
      records.where((record) => record.batteryVoltage != null).length;
  List<DailyRecord> get earningsWithoutOdometer => records
      .where((record) => record.earnings > 0 && record.odometer <= 0)
      .toList();

  List<OdometerIssue> get odometerDrops {
    final days = withOdometer;
    final issues = <OdometerIssue>[];
    for (var i = 1; i < days.length; i++) {
      final previous = days[i - 1];
      final current = days[i];
      if (current.odometer < previous.odometer) {
        issues.add(OdometerIssue(previous: previous, current: current));
      }
    }
    return issues;
  }

  double get latestOdometer {
    if (withOdometer.isEmpty) return 0;
    return withOdometer.map((record) => record.odometer).reduce(max);
  }

  double get totalDistance {
    if (withOdometer.length < 2) return 0;
    final values = withOdometer.map((record) => record.odometer);
    return max(0, values.reduce(max) - values.reduce(min));
  }

  double get todayEarnings {
    return records
        .where((r) => _sameDay(r.date, today))
        .fold(0, (sum, r) => sum + r.earnings);
  }

  CycleRange get currentCycle => CycleRange.forDate(today);

  List<DailyRecord> get currentCycleRecords =>
      records.where((r) => currentCycle.contains(r.date)).toList();

  double get currentCycleEarnings =>
      currentCycleRecords.fold(0, (sum, r) => sum + r.earnings);

  double get currentCycleExpenses =>
      currentCycleRecords.fold(0.0, (sum, r) => sum + r.expense) +
      maintenanceRecords
          .where((record) => currentCycle.contains(record.dateTime))
          .fold(0.0, (sum, record) => sum + (record.cost ?? 0));

  double get currentCycleNet => currentCycleEarnings - currentCycleExpenses;

  double get currentCycleDistance {
    final days = [...currentCycleRecords.where((record) => record.odometer > 0)]
      ..sort(_compareRecordsAsc);
    if (days.length < 2) return 0;
    final values = days.map((record) => record.odometer);
    return max(0, values.reduce(max) - values.reduce(min));
  }

  double get averageDailyEarnings {
    final uniqueDays = records
        .where((r) => r.earnings > 0)
        .map((r) => DateFormat('yyyy-MM-dd').format(r.date))
        .toSet();
    return uniqueDays.isEmpty ? 0 : totalEarnings / uniqueDays.length;
  }

  double get efficiency =>
      totalDistance <= 0 ? 0 : totalEarnings / totalDistance;

  Map<String, double> get monthlyEarnings {
    final map = <String, double>{};
    for (final record in records.where((record) => record.earnings > 0)) {
      final key = DateFormat('MMM yyyy', 'es').format(record.date);
      map[key] = (map[key] ?? 0) + record.earnings;
    }
    return map;
  }

  MonthlyComparison comparisonFor(DateTime month) {
    final selectedMonth = DateTime(month.year, month.month);
    final previousMonth = DateTime(month.year, month.month - 1);
    double totalFor(DateTime target) => records
        .where(
          (record) =>
              record.date.year == target.year &&
              record.date.month == target.month,
        )
        .fold(0, (sum, record) => sum + record.earnings);
    return MonthlyComparison(
      month: selectedMonth,
      currentEarnings: totalFor(selectedMonth),
      previousEarnings: totalFor(previousMonth),
    );
  }

  List<CycleSummary> get cycleSummaries {
    final map = <DateTime, List<DailyRecord>>{};
    for (final record in records) {
      final cycle = CycleRange.forDate(record.date);
      map.putIfAbsent(cycle.start, () => []).add(record);
    }
    final summaries = map.entries.map((entry) {
      final cycle = CycleRange(
          entry.key, DateTime(entry.key.year, entry.key.month + 1, 0));
      final days = entry.value.where((record) => record.odometer > 0).toList()
        ..sort(_compareRecordsAsc);
      final values = days.map((record) => record.odometer);
      final distance =
          days.length < 2 ? 0 : max(0, values.reduce(max) - values.reduce(min));
      return CycleSummary(
        start: entry.key,
        label: cycle.label,
        earnings: entry.value.fold(0, (sum, r) => sum + r.earnings),
        distance: distance.toDouble(),
      );
    }).toList();
    summaries.sort((a, b) => a.start.compareTo(b.start));
    return summaries;
  }
}

class MonthlyComparison {
  const MonthlyComparison({
    required this.month,
    required this.currentEarnings,
    required this.previousEarnings,
  });

  final DateTime month;
  final double currentEarnings;
  final double previousEarnings;

  double get percentage =>
      previousEarnings <= 0 ? 0 : currentEarnings / previousEarnings * 100;

  double get scaleMaximum => percentage > 100 ? percentage : 100;
}

class MaintenanceSnapshot {
  MaintenanceSnapshot({
    required this.lastMaintenance,
    required this.intervalKm,
    required this.nextMaintenanceKm,
    required this.remainingKm,
    required this.status,
    required this.color,
  });

  final MaintenanceRecord? lastMaintenance;
  final double intervalKm;
  final double nextMaintenanceKm;
  final double remainingKm;
  final String status;
  final Color color;

  factory MaintenanceSnapshot.from({
    required List<MaintenanceRecord> records,
    required double intervalKm,
    required double currentOdometer,
  }) {
    final sorted = [...records]
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    final last = sorted.isEmpty ? null : sorted.first;
    final next = last == null ? intervalKm : last.odometer + intervalKm;
    final remaining = next - currentOdometer;
    final status = _maintenanceStatus(remaining);
    return MaintenanceSnapshot(
      lastMaintenance: last,
      intervalKm: intervalKm,
      nextMaintenanceKm: next,
      remainingKm: remaining,
      status: status.$1,
      color: status.$2,
    );
  }

  static (String, Color) _maintenanceStatus(double remainingKm) {
    if (remainingKm < 0) return ('Mantenimiento vencido', kDanger);
    if (remainingKm < 50) return ('Mantenimiento pendiente', kDanger);
    if (remainingKm <= 200) return ('Programe el mantenimiento', kTertiary);
    if (remainingKm <= 500) return ('Se aproxima el mantenimiento', kSecondary);
    return ('Estado normal', kPrimary);
  }
}

class OdometerIssue {
  const OdometerIssue({required this.previous, required this.current});

  final DailyRecord previous;
  final DailyRecord current;
}

class CycleRange {
  CycleRange(this.start, this.end);

  final DateTime start;
  final DateTime end;

  factory CycleRange.forDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final start = DateTime(normalized.year, normalized.month);
    final end = DateTime(start.year, start.month + 1, 0);
    return CycleRange(start, end);
  }

  bool contains(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  String get label {
    final month = DateFormat('MMMM yyyy', activeLanguage).format(start);
    return month[0].toUpperCase() + month.substring(1);
  }
}

class CycleSummary {
  CycleSummary({
    required this.start,
    required this.label,
    required this.earnings,
    required this.distance,
  });

  final DateTime start;
  final String label;
  final double earnings;
  final double distance;
}
