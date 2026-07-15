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

class MonthlyComparisonGauge extends StatelessWidget {
  const MonthlyComparisonGauge({
    required this.comparison,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.canGoNext,
    super.key,
  });

  final MonthlyComparison comparison;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final bool canGoNext;

  @override
  Widget build(BuildContext context) {
    final color = monthlyGaugeColor(comparison.percentage);
    final monthLabel =
        DateFormat('MMMM yyyy', 'es').format(comparison.month).toUpperCase();
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Mes anterior',
              onPressed: onPreviousMonth,
              color: color,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                monthLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Mes siguiente',
              onPressed: canGoNext ? onNextMonth : null,
              color: color,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AspectRatio(
              aspectRatio: 1,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: comparison.percentage),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, animatedPercentage, _) {
                  final animatedColor = monthlyGaugeColor(animatedPercentage);
                  return LayoutBuilder(builder: (context, constraints) {
                    final dimension = constraints.maxWidth;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: MonthlyGaugePainter(
                              percentage: animatedPercentage,
                              scaleMaximum: comparison.scaleMaximum,
                              activeColor: animatedColor,
                            ),
                          ),
                        ),
                        Positioned(
                          top: dimension * .29,
                          left: 0,
                          right: 0,
                          child: Column(
                            children: [
                              Text(
                                formatGaugePercentage(animatedPercentage),
                                style: TextStyle(
                                  color: animatedColor,
                                  fontSize: (dimension * .14).clamp(38, 64),
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                moneyCompact(comparison.currentEarnings),
                                style: TextStyle(
                                  color: animatedColor,
                                  fontSize: (dimension * .075).clamp(22, 34),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: dimension * .035,
                          child: Column(
                            children: [
                              const Text(
                                'Meta',
                                style: TextStyle(color: kMuted, fontSize: 13),
                              ),
                              Text(
                                moneyCompact(comparison.previousEarnings,
                                    includeCurrency: false),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  });
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MonthlyGaugePainter extends CustomPainter {
  MonthlyGaugePainter({
    required this.percentage,
    required this.scaleMaximum,
    required this.activeColor,
  });

  final double percentage;
  final double scaleMaximum;
  final Color activeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .64);
    final radius = size.width * .39;
    final arcRect = Rect.fromCircle(center: center, radius: radius);
    final strokeWidth = size.width * .075;
    final gradientValues = <double>[0, 25, 50, 75, 100];
    final gradientColors = <Color>[
      const Color(0xFFFF2340),
      const Color(0xFFFF7A00),
      const Color(0xFFFFD600),
      const Color(0xFF63D916),
      const Color(0xFF168BFF),
    ];
    if (scaleMaximum > 100) {
      gradientValues.add(scaleMaximum);
      gradientColors.add(
        percentage > 120 ? const Color(0xFFB832FF) : const Color(0xFF168BFF),
      );
    }
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: pi,
        endAngle: pi * 2,
        colors: gradientColors,
        stops: gradientValues.map((value) => value / scaleMaximum).toList(),
      ).createShader(arcRect);
    canvas.drawArc(arcRect, pi, pi, false, arcPaint);

    final labelPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    for (final value in const [0, 25, 50, 75, 100]) {
      final angle = pi + pi * (value / scaleMaximum);
      final labelCenter = center +
          Offset(cos(angle), sin(angle)) * (radius - strokeWidth * 1.05);
      labelPainter.text = TextSpan(
        text: '$value',
        style: const TextStyle(
          color: Color(0xFFD9E1EA),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
      labelPainter.layout();
      labelPainter.paint(
        canvas,
        labelCenter - Offset(labelPainter.width / 2, labelPainter.height / 2),
      );
    }

    final normalized = (percentage / scaleMaximum).clamp(0.0, 1.0);
    final needleAngle = pi + pi * normalized;
    final needleEnd =
        center + Offset(cos(needleAngle), sin(needleAngle)) * radius * .70;
    final needlePaint = Paint()
      ..color = activeColor
      ..strokeWidth = max(4, size.width * .014)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, size.width * .035, needlePaint);
    canvas.drawCircle(
      center,
      size.width * .015,
      Paint()..color = const Color(0xFF080B10),
    );
  }

  @override
  bool shouldRepaint(covariant MonthlyGaugePainter oldDelegate) =>
      oldDelegate.percentage != percentage ||
      oldDelegate.scaleMaximum != scaleMaximum ||
      oldDelegate.activeColor != activeColor;
}

Color monthlyGaugeColor(double percentage) {
  if (percentage > 120) return const Color(0xFFB832FF);
  if (percentage >= 100) return const Color(0xFF168BFF);
  if (percentage >= 75) return const Color(0xFF63D916);
  if (percentage >= 50) return const Color(0xFFFFD600);
  if (percentage >= 25) return const Color(0xFFFF7A00);
  return const Color(0xFFFF2340);
}

String formatGaugePercentage(double value) {
  final rounded = value.roundToDouble();
  return value == rounded
      ? '${rounded.toInt()}%'
      : '${value.toStringAsFixed(1)}%';
}

String moneyCompact(double value, {bool includeCurrency = true}) {
  final prefix = includeCurrency ? r'$' : '';
  if (value.abs() >= 1000) return '$prefix${(value / 1000).round()}k';
  return '$prefix${value.round()}';
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
