part of '../main.dart';

class MetricHero extends StatelessWidget {
  const MetricHero({
    required this.label,
    required this.value,
    required this.sublabel,
    required this.icon,
    super.key,
  });

  final String label;
  final String value;
  final String sublabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GradientMetricCard(
      child: Stack(
        children: [
          Positioned(
            right: 2,
            top: 2,
            child: Icon(icon, size: 86, color: kText.withValues(alpha: .08)),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 92,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  colors: [kPrimary, kSecondary, kAccentPink],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Label(label),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  color: kPrimary,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              const Divider(color: kOutline),
              Text(sublabel, style: const TextStyle(color: kMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class MaintenanceDashboardCard extends StatelessWidget {
  const MaintenanceDashboardCard({required this.snapshot, super.key});

  final MaintenanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final last = snapshot.lastMaintenance;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Label('Mantenimiento general')),
              Icon(Icons.build_circle_outlined, color: snapshot.color),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            snapshot.status,
            style: TextStyle(
              color: snapshot.color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          InfoLine(
            label: 'Ultimo mantenimiento',
            value: last == null
                ? 'Sin registrar'
                : DateFormat('d MMM yyyy, HH:mm', 'es').format(last.dateTime),
          ),
          InfoLine(
            label: 'Km del ultimo mantenimiento',
            value: last == null ? '-' : '${numFmt(last.odometer)} km',
          ),
          InfoLine(
            label: 'Proximo mantenimiento',
            value: '${numFmt(snapshot.nextMaintenanceKm)} km',
          ),
          InfoLine(
            label: 'Km restantes',
            value: snapshot.remainingKm < 0
                ? 'Vencido por ${numFmt(snapshot.remainingKm.abs())} km'
                : '${numFmt(snapshot.remainingKm)} km',
          ),
        ],
      ),
    );
  }
}

class DataHealthCard extends StatelessWidget {
  const DataHealthCard({required this.metrics, super.key});

  final Metrics metrics;

  @override
  Widget build(BuildContext context) {
    final missing = metrics.earningsWithoutOdometer.length;
    final drops = metrics.odometerDrops;
    final statusColor = missing == 0 && drops.isEmpty ? kPrimary : kTertiary;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Label('Salud de datos')),
              Icon(Icons.fact_check_outlined, color: statusColor),
            ],
          ),
          const SizedBox(height: 12),
          InfoLine(
            label: 'Registros con ganancia',
            value: metrics.records
                .where((record) => record.earnings > 0)
                .length
                .toString(),
          ),
          InfoLine(
            label: 'Cargas a 80 V',
            value: metrics.chargeEvents.toString(),
          ),
          InfoLine(
            label: 'Ganancias sin odometro',
            value: missing.toString(),
          ),
          InfoLine(
            label: 'Lecturas sospechosas',
            value: drops.length.toString(),
          ),
          if (missing > 0 || drops.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _healthMessage(missing, drops),
              style: const TextStyle(color: kMuted),
            ),
          ],
        ],
      ),
    );
  }

  String _healthMessage(int missing, List<OdometerIssue> drops) {
    final parts = <String>[];
    if (missing > 0) {
      parts.add('$missing registros con ganancia no tienen odometro.');
    }
    if (drops.isNotEmpty) {
      final issue = drops.first;
      parts.add(
        'Revisa ${DateFormat('d MMM', 'es').format(issue.current.date)}: '
        '${numFmt(issue.current.odometer)} km es menor que '
        '${numFmt(issue.previous.odometer)} km.',
      );
    }
    return parts.join(' ');
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color = kPrimary,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Label(label)),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class InfoLine extends StatelessWidget {
  const InfoLine({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: kMuted))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class RecordTile extends StatelessWidget {
  const RecordTile({required this.record, this.onTap, super.key});

  final DailyRecord record;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (record.odometer > 0) '${numFmt(record.odometer)} km',
      if (record.chargeTo80v) 'Carga hasta 80 V',
      if (record.note.isNotEmpty) record.note,
    ];
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.zero,
        title: Text(DateFormat('d MMMM yyyy', 'es').format(record.date)),
        subtitle: Text(details.isEmpty ? 'Sin detalles' : details.join(' - ')),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              record.earnings > 0
                  ? '+${money(record.earnings)}'
                  : record.chargeTo80v
                      ? '80 V'
                      : '0 CUP',
              style: TextStyle(
                color: record.earnings > 0 ? kPrimary : kSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (record.batteryPercent != null)
              Text('${record.batteryPercent}% bateria',
                  style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class BarRow extends StatelessWidget {
  const BarRow({
    required this.label,
    required this.value,
    required this.percent,
    super.key,
  });

  final String label;
  final String value;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(value, style: const TextStyle(color: kPrimary)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent.clamp(0, 1),
              minHeight: 10,
              color: kPrimary,
              backgroundColor: kSurfaceHigh,
            ),
          ),
        ],
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.margin,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kCardGradientTop, kCardGradientBottom],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A3645)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class GradientMetricCard extends StatelessWidget {
  const GradientMetricCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF18362F),
            Color(0xFF142237),
            Color(0xFF21192B),
          ],
        ),
        border: Border.all(color: const Color(0xFF2C4B46)),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withValues(alpha: .12),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({required this.title, this.trailing, super.key});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          if (trailing != null)
            Text(trailing!,
                style: const TextStyle(color: kMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class Label extends StatelessWidget {
  const Label(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: kMuted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: .7,
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Text(text, style: const TextStyle(color: kMuted)),
    );
  }
}

String money(double value) =>
    '${NumberFormat('#,##0.##', 'es').format(value)} CUP';
String numFmt(double value) => NumberFormat('#,##0.##', 'es').format(value);
String trimNum(double value) =>
    value % 1 == 0 ? value.toInt().toString() : value.toString();

double _numFromMap(Map<dynamic, dynamic> map, String key) {
  final value = map[key];
  if (value is num) return value.toDouble();
  return double.tryParse('$value'.replaceAll(',', '.')) ?? 0;
}

double? _parseOptionalNumber(String value) {
  final normalized = value.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

int _compareRecordsAsc(DailyRecord a, DailyRecord b) {
  final date = a.date.compareTo(b.date);
  if (date != 0) return date;
  final updated = a.updatedAt.compareTo(b.updatedAt);
  if (updated != 0) return updated;
  final odometer = a.odometer.compareTo(b.odometer);
  if (odometer != 0) return odometer;
  return a.id.compareTo(b.id);
}

int _compareRecordsDesc(DailyRecord a, DailyRecord b) =>
    _compareRecordsAsc(b, a);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
