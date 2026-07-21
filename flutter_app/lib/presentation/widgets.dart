part of '../main.dart';

class MetricHero extends StatelessWidget {
  const MetricHero({
    required this.label,
    required this.value,
    required this.sublabel,
    required this.icon,
    this.trailing,
    super.key,
  });

  final String label;
  final String value;
  final String sublabel;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GradientMetricCard(
      child: Stack(
        children: [
          Positioned(
            right: 2,
            top: 2,
            child: trailing ??
                Icon(icon, size: 86, color: kText.withValues(alpha: .08)),
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
              Expanded(child: Label(tr('Mantenimiento general'))),
              Icon(Icons.build_circle_outlined, color: snapshot.color),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tr(snapshot.status),
            style: TextStyle(
              color: snapshot.color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          InfoLine(
            label: tr('Ultimo mantenimiento'),
            value: last == null
                ? tr('Sin registrar')
                : DateFormat('d MMM yyyy, HH:mm', activeLanguage)
                    .format(last.dateTime),
          ),
          InfoLine(
            label: tr('Km del ultimo mantenimiento'),
            value: last == null ? '-' : '${numFmt(last.odometer)} km',
          ),
          InfoLine(
            label: tr('Proximo mantenimiento'),
            value: '${numFmt(snapshot.nextMaintenanceKm)} km',
          ),
          InfoLine(
            label: tr('Km restantes'),
            value: snapshot.remainingKm < 0
                ? '${tr('Vencido por')} ${numFmt(snapshot.remainingKm.abs())} km'
                : '${numFmt(snapshot.remainingKm)} km',
          ),
        ],
      ),
    );
  }
}

class DriverSystemMessages extends StatelessWidget {
  const DriverSystemMessages(
      {required this.metrics,
      required this.maintenance,
      required this.comparison,
      super.key});

  final Metrics metrics;
  final MaintenanceSnapshot maintenance;
  final MonthlyComparison comparison;

  @override
  Widget build(BuildContext context) {
    final messages = <_DriverMessage>[_maintenanceMessage()];
    if (metrics.records.isNotEmpty) messages.add(_progressMessage());
    if (metrics.records.any((record) => record.earnings > 0)) {
      messages.add(_bestDayMessage());
    } else {
      messages.add(_DriverMessage(
          Icons.add_road_outlined,
          kSecondary,
          tr('Comienza tu recorrido'),
          tr('Agrega registros para recibir recomendaciones personalizadas.')));
    }
    return GlassCard(
      child: Column(children: [
        for (var i = 0; i < messages.length; i++) ...[
          _DriverMessageRow(message: messages[i]),
          if (i != messages.length - 1)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: kOutline)),
        ],
      ]),
    );
  }

  _DriverMessage _maintenanceMessage() {
    final remaining = maintenance.remainingKm;
    final overdue = remaining < 0;
    return _DriverMessage(
      overdue ? Icons.warning_amber_rounded : Icons.build_circle_outlined,
      maintenance.color,
      tr(maintenance.status),
      overdue
          ? '${tr('El mantenimiento esta vencido por')} ${numFmt(remaining.abs())} km. ${tr('Atiendelo cuanto antes.')}'
          : '${tr('Proximo servicio en')} ${numFmt(remaining)} km (${numFmt(maintenance.nextMaintenanceKm)} km).',
    );
  }

  _DriverMessage _progressMessage() {
    final percentage = comparison.percentage;
    return _DriverMessage(
      percentage >= 100
          ? Icons.emoji_events_outlined
          : Icons.trending_up_rounded,
      monthlyGaugeColor(percentage),
      tr(percentage >= 100 ? 'Meta mensual superada' : 'Avance del mes'),
      '${tr('Has alcanzado')} ${percentage.toStringAsFixed(1)}% ${tr('del resultado del mes anterior')}.',
    );
  }

  _DriverMessage _bestDayMessage() {
    final totals = <DateTime, double>{};
    for (final record in metrics.records.where((r) => r.earnings > 0)) {
      final day =
          DateTime(record.date.year, record.date.month, record.date.day);
      totals[day] = (totals[day] ?? 0) + record.earnings;
    }
    final best = totals.entries.reduce(
        (current, entry) => entry.value > current.value ? entry : current);
    return _DriverMessage(
        Icons.workspace_premium_outlined,
        kTertiary,
        tr('Mejor jornada registrada'),
        '${DateFormat('d MMM yyyy', activeLanguage).format(best.key)} · ${money(best.value)}');
  }
}

class _DriverMessage {
  const _DriverMessage(this.icon, this.color, this.title, this.body);
  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

class _DriverMessageRow extends StatelessWidget {
  const _DriverMessageRow({required this.message});
  final _DriverMessage message;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: message.color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: message.color.withValues(alpha: .28))),
              child: Icon(message.icon, color: message.color, size: 23)),
          const SizedBox(width: 13),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.title,
                  style: TextStyle(
                      color: message.color,
                      fontSize: 15,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(message.body,
                  style: const TextStyle(color: kMuted, height: 1.35)),
            ],
          )),
        ],
      );
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
              Expanded(child: Label(tr('Salud de datos'))),
              Icon(Icons.fact_check_outlined, color: statusColor),
            ],
          ),
          const SizedBox(height: 12),
          InfoLine(
            label: tr('Registros con ingreso'),
            value: metrics.records
                .where((record) => record.earnings > 0)
                .length
                .toString(),
          ),
          InfoLine(
            label: tr('Cargas a 80 V'),
            value: metrics.chargeEvents.toString(),
          ),
          InfoLine(
            label: tr('Ingresos sin odometro'),
            value: missing.toString(),
          ),
          InfoLine(
            label: tr('Lecturas sospechosas'),
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
      parts.add('$missing ${tr('registros con ingreso no tienen odometro.')}');
    }
    if (drops.isNotEmpty) {
      final issue = drops.first;
      parts.add(
        '${tr('Revisa')} ${DateFormat('d MMM', activeLanguage).format(issue.current.date)}: '
        '${numFmt(issue.current.odometer)} ${tr('km es menor que')} '
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

class StatOverviewCard extends StatelessWidget {
  const StatOverviewCard({
    required this.width,
    required this.label,
    required this.value,
    this.note,
    this.color = kPrimary,
    super.key,
  });

  final double width;
  final String label;
  final String value;
  final String? note;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 126,
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Label(label),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (note != null) ...[
              const SizedBox(height: 5),
              Text(
                note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: kMuted, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MonthlyEarningsBars extends StatelessWidget {
  const MonthlyEarningsBars({required this.cycles, super.key});

  final List<CycleSummary> cycles;

  @override
  Widget build(BuildContext context) {
    if (cycles.isEmpty) {
      return EmptyState(tr('Todavía no hay ingresos para graficar.'));
    }
    final visible = cycles.take(8).toList().reversed.toList();
    final maximum = visible.map((cycle) => cycle.earnings).reduce(max);
    return GlassCard(
      child: SizedBox(
        height: 210,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final cycle in visible)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        moneyCompact(cycle.earnings, includeCurrency: false),
                        style: const TextStyle(color: kMuted, fontSize: 10),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        height:
                            maximum == 0 ? 2 : 130 * cycle.earnings / maximum,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [kPrimary, kSecondary],
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        DateFormat('MMM', activeLanguage).format(cycle.start),
                        style: const TextStyle(color: kMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class EarningsTrendCard extends StatelessWidget {
  const EarningsTrendCard({required this.records, super.key});

  final Iterable<DailyRecord> records;

  @override
  Widget build(BuildContext context) {
    final values = records.toList();
    if (values.isEmpty) {
      return EmptyState(tr('Todavía no hay ingresos para mostrar.'));
    }
    return GlassCard(
      child: Column(
        children: [
          for (final record in values)
            InfoLine(
              label: DateFormat('d MMM', activeLanguage).format(record.date),
              value: money(record.earnings),
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
      if (record.expenseCategory.isNotEmpty) record.expenseCategory,
      if (record.chargeTo80v) tr('Carga hasta 80 V'),
      if (record.note.isNotEmpty) record.note,
    ];
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.zero,
        leading: SizedBox(
          width: 50,
          child: Wrap(
            spacing: 3,
            runSpacing: 3,
            children: [
              if (record.earnings > 0)
                const _HistoryTypeIcon(
                  icon: Icons.payments_outlined,
                  color: kPrimary,
                ),
              if (record.expense > 0)
                const _HistoryTypeIcon(
                  icon: Icons.receipt_long_outlined,
                  color: kDanger,
                ),
              if (record.odometer > 0)
                const _HistoryTypeIcon(
                  icon: Icons.speed_rounded,
                  color: kSecondary,
                ),
              if (record.chargeTo80v)
                const _HistoryTypeIcon(
                  icon: Icons.ev_station_outlined,
                  color: kTertiary,
                ),
              if (record.earnings <= 0 &&
                  record.expense <= 0 &&
                  record.odometer <= 0 &&
                  !record.chargeTo80v)
                const _HistoryTypeIcon(
                  icon: Icons.notes_outlined,
                  color: kMuted,
                ),
            ],
          ),
        ),
        title:
            Text(DateFormat('d MMMM yyyy', activeLanguage).format(record.date)),
        subtitle:
            Text(details.isEmpty ? tr('Sin detalles') : details.join(' - ')),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              record.earnings > 0
                  ? '+${money(record.earnings)}'
                  : record.expense > 0
                      ? '-${money(record.expense)}'
                      : record.chargeTo80v
                          ? '80 V'
                          : '0 $activeCurrency',
              style: TextStyle(
                color: record.earnings > 0
                    ? kPrimary
                    : record.expense > 0
                        ? kDanger
                        : kSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (record.batteryPercent != null)
              Text('${record.batteryPercent}% ${tr('bateria')}',
                  style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _HistoryTypeIcon extends StatelessWidget {
  const _HistoryTypeIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 23,
      height: 23,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Icon(icon, color: color, size: 14),
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
    final monthLabel = DateFormat('MMMM yyyy', activeLanguage)
        .format(comparison.month)
        .toUpperCase();
    return GlassCard(
      child: Column(
        children: [
          Label(tr('Comparación de ingresos')),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                tooltip: tr('Mes anterior'),
                onPressed: onPreviousMonth,
                color: color,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  monthLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
              ),
              IconButton(
                tooltip: tr('Mes siguiente'),
                onPressed: canGoNext ? onNextMonth : null,
                color: color,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Text(
            tr('Mes anterior = 100%'),
            style: const TextStyle(color: kMuted, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AspectRatio(
                aspectRatio: 1.65,
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
                            top: dimension * .23,
                            left: 0,
                            right: 0,
                            child: Column(
                              children: [
                                Text(
                                  formatGaugePercentage(animatedPercentage),
                                  style: TextStyle(
                                    color: animatedColor,
                                    fontSize: (dimension * .12).clamp(36, 58),
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  moneyCompact(comparison.currentEarnings),
                                  style: TextStyle(
                                    color: animatedColor,
                                    fontSize: (dimension * .055).clamp(19, 28),
                                    fontWeight: FontWeight.w800,
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
          Transform.translate(
            offset: const Offset(0, -4),
            child: Row(
              children: [
                Expanded(
                  child: _GaugeSummaryValue(
                    label: tr('Ingreso actual'),
                    value: moneyCompact(comparison.currentEarnings),
                    color: color,
                  ),
                ),
                Container(width: 1, height: 42, color: kOutline),
                Expanded(
                  child: _GaugeSummaryValue(
                    label: tr('Mes anterior'),
                    value: moneyCompact(comparison.previousEarnings),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugeSummaryValue extends StatelessWidget {
  const _GaugeSummaryValue({
    required this.label,
    required this.value,
    this.color = kText,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: kMuted, fontSize: 11)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w900,
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
    final center = Offset(size.width / 2, size.height * .82);
    final radius = min(size.width * .39, size.height * .67);
    final arcRect = Rect.fromCircle(center: center, radius: radius);
    final strokeWidth = size.width * .065;
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
      gradientColors.add(const Color(0xFFB832FF));
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
    canvas.drawArc(
      arcRect,
      pi,
      pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 6
        ..strokeCap = StrokeCap.round
        ..color = kMuted.withValues(alpha: .10),
    );
    canvas.drawArc(arcRect, pi, pi, false, arcPaint);

    // SweepGradient vuelve al primer color justo después de su ángulo final.
    // Pintamos los remates encima para conservar el color correcto en cada lado.
    final capRadius = strokeWidth / 2;
    canvas.drawCircle(
      center + Offset(-radius, 0),
      capRadius,
      Paint()..color = const Color(0xFFFF2340),
    );
    canvas.drawCircle(
      center + Offset(radius, 0),
      capRadius,
      Paint()
        ..color = scaleMaximum > 100
            ? const Color(0xFFB832FF)
            : const Color(0xFF168BFF),
    );

    final labelPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    for (final value in const [0, 25, 50, 75, 100]) {
      final angle = pi + pi * (value / scaleMaximum);
      final labelCenter = center +
          Offset(cos(angle), sin(angle)) * (radius + strokeWidth * .72);
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
  if (percentage > 100) return const Color(0xFFB832FF);
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
  final symbol = switch (activeCurrency) {
    'EUR' => '€',
    'USD' || 'MXN' => r'$',
    _ => r'$',
  };
  final prefix = includeCurrency ? symbol : '';
  if (value.abs() >= 1000) return '$prefix${(value / 1000).round()}k';
  return '$prefix${value.round()}';
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.margin,
    this.padding = const EdgeInsets.all(18),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [kCardGradientTop, kCardGradientBottom]
              : const [Color(0xF8FFFFFF), Color(0xF0E8F0F8)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: dark ? const Color(0xFF304055) : const Color(0xFFCBD9E8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .22 : .08),
            blurRadius: 28,
            offset: const Offset(0, 14),
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [
                  Color(0xFF153329),
                  Color(0xFF132239),
                  Color(0xFF191A2A),
                ]
              : const [
                  Color(0xFFDDF8EF),
                  Color(0xFFE7F0FF),
                  Color(0xFFF4EFFF),
                ],
        ),
        border: Border.all(color: const Color(0xFF315044)),
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
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: -.3,
              ),
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
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
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
    '${NumberFormat('#,##0.##', activeLanguage).format(value)} $activeCurrency';
String numFmt(double value) =>
    NumberFormat('#,##0.##', activeLanguage).format(value);
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
