part of '../main.dart';

class _OverviewMetricLabel extends StatelessWidget {
  const _OverviewMetricLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      color: appMutedColor(context),
      fontSize: 12,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
  );
}

class _OverviewMetricValue extends StatelessWidget {
  const _OverviewMetricValue(this.value, {required this.style, this.currency, this.currencyStyle, this.alignment = Alignment.centerLeft});
  final String value;
  final TextStyle style;
  final String? currency;
  final TextStyle? currencyStyle;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FittedBox(
      alignment: alignment,
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(value, style: style, maxLines: 1, softWrap: false),
          if (currency != null) ...[
            const SizedBox(width: 5),
            Text(currency!, style: currencyStyle ?? TextStyle(
              color: appMutedColor(context),
              fontSize: (style.fontSize ?? 18) * .58,
              fontWeight: FontWeight.w600,
            )),
          ],
        ],
      ),
    ),
  );
}

/// Presentation-only seasonal campaigns. Dates use the device's local calendar.
class SeasonalCampaign {
  const SeasonalCampaign({
    required this.id,
    required this.startMonth,
    required this.startDay,
    required this.endMonth,
    required this.endDay,
    required this.messages,
    required this.icon,
    required this.accent,
    required this.highlight,
  });

  final String id;
  final int startMonth;
  final int startDay;
  final int endMonth;
  final int endDay;
  final Map<String, String> messages;
  final IconData icon;
  final Color accent;
  final Color highlight;

  bool includes(DateTime date) {
    final day = date.month * 100 + date.day;
    final start = startMonth * 100 + startDay;
    final end = endMonth * 100 + endDay;
    return start <= end ? day >= start && day <= end
        : day >= start || day <= end;
  }
}

// Add future campaigns here, in priority order. No financial colors,
// network requests, authentication or persisted records are involved.
const _seasonalCampaigns = <SeasonalCampaign>[
  SeasonalCampaign(
    id: 'christmas',
    startMonth: 11,
    startDay: 26,
    endMonth: 12,
    endDay: 25,
    messages: {
      'es': 'Felices fiestas',
      'en': 'Happy holidays',
      'pt': 'Boas festas',
      'fr': 'Joyeuses fêtes',
    },
    icon: Icons.park_outlined,
    accent: Color(0xFF318568),
    highlight: Color(0xFFEBCB86),
  ),
];

SeasonalCampaign? seasonalCampaignFor(DateTime date, {
  bool enabled = const bool.fromEnvironment('TUKTUK_SEASONAL_ENABLED', defaultValue: true),
}) {
  if (!enabled) return null;
  for (final campaign in _seasonalCampaigns) {
    if (campaign.includes(date)) return campaign;
  }
  return null;
}

class MetricHero extends StatelessWidget {
  const MetricHero({
    required this.label,
    required this.value,
    this.currency,
    required this.sublabel,
    required this.icon,
    this.trailing,
    super.key,
  });

  final String label;
  final String value;
  final String? currency;
  final String sublabel;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final headline = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Label(label),
        const SizedBox(height: 6),
        _OverviewMetricValue(
          value,
          currency: currency,
          style: TextStyle(
            color: appPrimaryColor(context),
            fontSize: 36,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
    final logo = trailing ?? Icon(
      icon, size: 86,
      color: appTextColor(context).withValues(alpha: .08),
    );
    return GradientMetricCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: headline),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                height: 86,
                child: FittedBox(fit: BoxFit.contain, child: logo),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: appOutlineColor(context)),
          Row(
            children: [
              Expanded(child: Text(sublabel,
                style: TextStyle(color: appMutedColor(context)))),
              const SizedBox(width: 8),
              Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [appPrimaryColor(context), appSecondaryColor(context), kAccentPink],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MaintenanceDashboardCard extends StatelessWidget {
  const MaintenanceDashboardCard({required this.snapshot, this.visualStyle = false, super.key});

  final MaintenanceSnapshot snapshot;
  final bool visualStyle;

  @override
  Widget build(BuildContext context) {
    final last = snapshot.lastMaintenance;
    return GlassCard(
      accent: visualStyle ? snapshot.color : null,
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
                : DateFormat(
                    'd MMM yyyy, HH:mm',
                    activeLanguage,
                  ).format(last.dateTime),
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
  const DriverSystemMessages({
    required this.metrics,
    required this.maintenance,
    required this.comparison,
    super.key,
  });

  final Metrics metrics;
  final MaintenanceSnapshot maintenance;
  final MonthlyComparison comparison;

  @override
  Widget build(BuildContext context) {
    final messages = <_DriverMessage>[_maintenanceMessage()];
    if (metrics.records.isNotEmpty) messages.add(_progressMessage(context));
    if (metrics.records.any((record) => record.earnings > 0)) {
      messages.add(_bestDayMessage());
    } else {
      messages.add(
        _DriverMessage(
          Icons.add_road_outlined,
          appSecondaryColor(context),
          tr('Comienza tu recorrido'),
          tr('Agrega registros para recibir recomendaciones personalizadas.'),
        ),
      );
    }
    return GlassCard(
      child: Column(
        children: [
          for (var i = 0; i < messages.length; i++) ...[
            _DriverMessageRow(message: messages[i]),
            if (i != messages.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: appOutlineColor(context)),
              ),
          ],
        ],
      ),
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

  _DriverMessage _progressMessage(BuildContext context) {
    final percentage = comparison.percentage;
    return _DriverMessage(
      percentage >= 100
          ? Icons.emoji_events_outlined
          : Icons.trending_up_rounded,
      _themedMonthlyGaugeColor(context, percentage),
      tr(percentage >= 100 ? 'Meta mensual superada' : 'Avance del mes'),
      '${tr('Has alcanzado')} ${percentage.toStringAsFixed(1)}% ${tr('del resultado del mes anterior')}.',
    );
  }

  _DriverMessage _bestDayMessage() {
    final totals = <DateTime, double>{};
    for (final record in metrics.records.where((r) => r.earnings > 0)) {
      final day = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      totals[day] = (totals[day] ?? 0) + record.earnings;
    }
    final best = totals.entries.reduce(
      (current, entry) => entry.value > current.value ? entry : current,
    );
    return _DriverMessage(
      Icons.workspace_premium_outlined,
      kTertiary,
      tr('Mejor jornada registrada'),
      '${DateFormat('d MMM yyyy', activeLanguage).format(best.key)} · ${money(best.value)}',
    );
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
              border: Border.all(color: message.color.withValues(alpha: .28)),
            ),
            child: Icon(message.icon, color: message.color, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.title,
                  style: TextStyle(
                    color: message.color,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message.body,
                  style: TextStyle(color: appMutedColor(context), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      );
}

class DataHealthCard extends StatelessWidget {
  const DataHealthCard({required this.metrics, this.statisticsStyle = false, super.key});

  final Metrics metrics;
  final bool statisticsStyle;

  @override
  Widget build(BuildContext context) {
    final missing = metrics.earningsWithoutOdometer.length;
    final drops = metrics.odometerDrops;
    final statusColor =
        missing == 0 && drops.isEmpty ? appPrimaryColor(context) : kTertiary;
    return GlassCard(
      accent: statisticsStyle ? statusColor : null,
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
              style: TextStyle(color: appMutedColor(context)),
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

// Equal-width and equal-height cards across the dashboard. The header
// allowance grows for narrow screens and accessibility text sizes.
int _dashboardMetricHeaderLines(BuildContext context, double cardWidth) {
  // Two lines at ordinary phone widths. Preserve extra room for narrow
  // viewports and large accessibility fonts. Tooltip retains full label.
  return cardWidth >= 140 && MediaQuery.textScalerOf(context).scale(12) <= 13.2
      ? 2 : 3;
}

double _dashboardMetricHeaderHeight(BuildContext context, double cardWidth,
    Iterable<String> labels) {
  final labelWidth = max(1.0, cardWidth - 18 - 26 - 5);
  var height = 26.0;
  for (final label in labels) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: const TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700, height: 1.2)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: _dashboardMetricHeaderLines(context, cardWidth),
      ellipsis: '…',
    )..layout(maxWidth: labelWidth);
    height = max(height, painter.height.ceilToDouble());
    painter.dispose();
  }
  return height;
}

class DashboardMetricGrid extends StatelessWidget {
  const DashboardMetricGrid({required this.cards, this.columns = 2, super.key});

  final List<MetricCard> cards;
  final int columns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cardWidth = (constraints.maxWidth - (columns - 1) * 10) / columns;
      final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
      final header = _dashboardMetricHeaderHeight(
        context, cardWidth, cards.map((card) => card.label));
      final details = cards.any((card) => card.details != null);
      final notes = cards.any((card) => card.note != null);
      // Include border thickness and actual font leading; avoid clipping
      // wallet detail rows on desktop and at larger accessibility scales.
      final height = 27 + header + (details ? 57 : notes ? 57 : 28) * scale;
      return GridView.count(
        padding: EdgeInsets.zero,
        primary: false,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: columns,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: height,
        children: [
          for (final card in cards)
            MetricCard(label: card.label, value: card.value,
              currency: card.currency, icon: card.icon, color: card.color,
              note: card.note, details: card.details, headerHeight: header,
              tintedValue: card.tintedValue),
        ],
      );
    },
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    this.currency,
    required this.icon,
    this.color,
    this.note,
    this.details,
    this.headerHeight,
    this.tintedValue = false,
    super.key,
  });

  final String label;
  final String value;
  final String? currency;
  final IconData icon;
  final Color? color;
  final String? note;
  final Widget? details;
  final double? headerHeight;
  final bool tintedValue;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? appPrimaryColor(context);
    return LayoutBuilder(builder: (context, constraints) {
      final header = headerHeight ?? _dashboardMetricHeaderHeight(context, constraints.maxWidth, [label]);
      return GlassCard(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: header,
              child: Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: label,
                      child: Text(label, maxLines: _dashboardMetricHeaderLines(context, constraints.maxWidth),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: appMutedColor(context),
                          fontSize: 12, fontWeight: FontWeight.w700, height: 1.2)),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: effectiveColor.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, color: effectiveColor, size: 17),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            _OverviewMetricValue(
              value,
              currency: currency,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                color: tintedValue ? effectiveColor : null),
            ),
            if (note != null) ...[
              const SizedBox(height: 3),
              Text(note!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: appMutedColor(context), fontSize: 11)),
            ],
            if (details != null) ...[
              const SizedBox(height: 3),
              details!,
            ],
          ],
        ),
      );
    });
  }
}

class StatOverviewCard extends StatelessWidget {
  const StatOverviewCard({
    required this.width,
    required this.label,
    required this.value,
    this.currency,
    this.note,
    this.color,
    this.icon,
    super.key,
  });

  final double width;
  final String label;
  final String value;
  final String? currency;
  final String? note;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? appPrimaryColor(context);

    return Container(
      width: width,
      constraints: BoxConstraints(
        minHeight: 132 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(13),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _OverviewMetricLabel(label),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: effectiveColor.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      color: effectiveColor,
                      size: 18,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            _OverviewMetricValue(
              value,
              currency: currency,
              style: TextStyle(
                color: effectiveColor,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (note != null) ...[
              const SizedBox(height: 5),
              Text(
                note!,
                maxLines: 2,
                style: TextStyle(
                  color: appMutedColor(context),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MonthlyEarningsBars extends StatelessWidget {
  const MonthlyEarningsBars({required this.cycles, this.statisticsStyle = false, super.key});

  final List<CycleSummary> cycles;
  final bool statisticsStyle;

  @override
  Widget build(BuildContext context) {
    if (cycles.isEmpty) {
      return EmptyState(tr('Todavía no hay ingresos para graficar.'));
    }
    final visible = cycles.reversed.take(8).toList().reversed.toList();
    final maximum = visible.map((cycle) => max(cycle.earnings, cycle.expenses)).reduce(max);
    final scale = MediaQuery.textScalerOf(context);
    return GlassCard(
      accent: statisticsStyle ? appPrimaryColor(context) : null,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ChartLegendDot(color: appPrimaryColor(context)),
              const SizedBox(width: 5),
              Text(tr('Ingreso'), style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 18),
              const _ChartLegendDot(color: kDanger),
              const SizedBox(width: 5),
              Text(tr('Gasto'), style: const TextStyle(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 195 + max(0.0, scale.scale(10) - 10) * 3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final cycle in visible)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: statisticsStyle ? 2 : 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                            moneyCompact(
                              cycle.earnings,
                              includeCurrency: false,
                            ),
                            style: TextStyle(
                              color: statisticsStyle ? appPrimaryColor(context) : appMutedColor(context),
                              fontSize: 10,
                              fontWeight: statisticsStyle ? FontWeight.w700 : FontWeight.normal,
                            ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Tooltip(
                            key: ValueKey('monthly-income-bar-${cycle.start.toIso8601String()}'),
                            message:
                                '${tr('Ingreso')}: ${money(cycle.earnings)}\n${tr('Gasto')}: ${money(cycle.expenses)}',
                            child: _IncomeExpenseBar(
                              height: maximum <= 0
                                  ? 2
                                  : max(2.0, 130 * max(cycle.earnings, cycle.expenses) / maximum),
                              expenseRatio: max(cycle.earnings, cycle.expenses) <= 0
                                  ? 0
                                  : cycle.expenses / max(cycle.earnings, cycle.expenses),
                            ),
                          ),
                          const SizedBox(height: 7),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                            DateFormat(
                              'MMM',
                              activeLanguage,
                            ).format(cycle.start),
                            style: TextStyle(
                              color: appMutedColor(context),
                              fontSize: 10,
                              fontWeight: statisticsStyle ? FontWeight.w700 : FontWeight.normal,
                            ),
                            ),
                          ),
                        ],
                      ),
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

class _IncomeExpenseBar extends StatelessWidget {
  const _IncomeExpenseBar({required this.height, required this.expenseRatio});

  final double height;
  final double expenseRatio;

  @override
  Widget build(BuildContext context) {
    final ratio = expenseRatio.clamp(0.0, 1.0);
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.bottomCenter,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    appPrimaryColor(context),
                    appSecondaryColor(context),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: ratio,
                widthFactor: 1,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xFFB91C35), kDanger],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartLegendDot extends StatelessWidget {
  const _ChartLegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class EarningsTrendCard extends StatelessWidget {
  const EarningsTrendCard({required this.records, this.statisticsStyle = false, super.key});

  final Iterable<DailyRecord> records;
  final bool statisticsStyle;

  @override
  Widget build(BuildContext context) {
    final values = records.toList();
    if (values.isEmpty) {
      return EmptyState(tr('Todavía no hay ingresos para mostrar.'));
    }
    return GlassCard(
      accent: statisticsStyle ? appPrimaryColor(context) : null,
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
          Expanded(
            child: Text(label, style: TextStyle(color: appMutedColor(context))),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

Color _historyAccent(BuildContext context, String kind) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (kind) {
    'income' => dark ? const Color(0xFF56D2A1) : const Color(0xFF187653),
    'expense' => dark ? kDanger : const Color(0xFFAC3152),
    'work' => dark ? const Color(0xFF72A7FF) : const Color(0xFF245BA7),
    'maintenance' => dark ? const Color(0xFF55C9EF) : const Color(0xFF176C91),
    _ => appMutedColor(context),
  };
}

class RecordTile extends StatelessWidget {
  const RecordTile({required this.record, this.onTap, super.key});

  final DailyRecord record;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final kind = record.isMarketplaceJobIncome ? 'work'
        : record.earnings > 0 ? 'income'
        : record.expense > 0 ? 'expense' : 'neutral';
    final accent = _historyAccent(context, kind);
    final icon = switch (kind) {
      'work' => Icons.route_outlined,
      'income' => Icons.payments_outlined,
      'expense' => Icons.receipt_long_outlined,
      _ => Icons.notes_outlined,
    };
    final amount = record.earnings > 0
        ? '+${money(record.earnings)}'
        : record.expense > 0
            ? '-${money(record.expense)}'
            : record.batteryVoltage != null
                ? '${trimNum(record.batteryVoltage!)} V'
                : '0 $activeCurrency';
    final hasMoney = record.earnings > 0 || record.expense > 0;
    final details = <(IconData, String)>[
      if (record.odometer > 0)
        (Icons.speed_rounded, '${numFmt(record.odometer)} km'),
      if (record.batteryVoltage != null && hasMoney)
        (Icons.battery_charging_full_outlined, '${trimNum(record.batteryVoltage!)} V'),
      if (record.expenseCategory.isNotEmpty)
        (Icons.sell_outlined, record.expenseCategory),
    ];
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      accent: accent,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: .27)),
                  ),
                  child: Icon(icon, color: accent, size: 25),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(builder: (context, constraints) {
                        final date = Text(
                          DateFormat('d MMM yyyy', activeLanguage).format(record.date),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        );
                        final value = Text(amount,
                          style: TextStyle(fontSize: 16, color: accent,
                            fontWeight: FontWeight.w900),
                        );
                        if (constraints.maxWidth < 225 ||
                            MediaQuery.textScalerOf(context).scale(1) > 1.25) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [date, const SizedBox(height: 3), value],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: date),
                            const SizedBox(width: 6),
                            Flexible(child: Align(alignment: Alignment.centerRight,
                              child: value)),
                          ],
                        );
                      }),
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            for (final detail in details)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(detail.$1, size: 15,
                                    color: appMutedColor(context)),
                                  const SizedBox(width: 4),
                                  Flexible(child: Text(detail.$2,
                                    style: TextStyle(fontSize: 12,
                                      color: appMutedColor(context)))),
                                ],
                              ),
                          ],
                        ),
                      ],
                      if (record.note.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(record.note, style: TextStyle(fontSize: 12,
                          color: appMutedColor(context))),
                      ],
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 18,
                    color: appMutedColor(context)),
                ],
              ],
            ),
          ),
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
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(value, style: TextStyle(color: appPrimaryColor(context))),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent.clamp(0, 1),
              minHeight: 10,
              color: appPrimaryColor(context),
              backgroundColor: appSurfaceHighColor(context),
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
    this.visualStyle = false,
    super.key,
  });

  final MonthlyComparison comparison;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final bool canGoNext;
  final bool visualStyle;

  @override
  Widget build(BuildContext context) {
    final color = _themedMonthlyGaugeColor(context, comparison.percentage);
    final monthLabel = DateFormat(
      'MMMM yyyy',
      activeLanguage,
    ).format(comparison.month).toUpperCase();
    return GlassCard(
      accent: visualStyle ? color : null,
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
            style: TextStyle(color: appMutedColor(context), fontSize: 12),
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
                    final animatedColor = _themedMonthlyGaugeColor(
                      context,
                      animatedPercentage,
                    );
                    return LayoutBuilder(
                      builder: (context, constraints) {
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
                                  trackColor: appMutedColor(context).withValues(
                                    alpha: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? .10
                                        : .24,
                                  ),
                                  labelColor: appMutedColor(context),
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
                                      fontSize: (dimension * .055).clamp(
                                        19,
                                        28,
                                      ),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
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
                Container(
                  width: 1,
                  height: 42,
                  color: appOutlineColor(context),
                ),
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
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: appMutedColor(context), fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color ?? appTextColor(context),
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
    required this.trackColor,
    required this.labelColor,
  });

  final double percentage;
  final double scaleMaximum;
  final Color activeColor;
  final Color trackColor;
  final Color labelColor;

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
        ..color = trackColor,
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
        style: TextStyle(
          color: labelColor,
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

Color _themedMonthlyGaugeColor(BuildContext context, double percentage) {
  if (Theme.of(context).brightness == Brightness.dark) {
    return monthlyGaugeColor(percentage);
  }
  if (percentage > 100) return const Color(0xFF7E22CE);
  if (percentage >= 100) return const Color(0xFF1D4ED8);
  if (percentage >= 75) return const Color(0xFF3F7D10);
  if (percentage >= 50) return const Color(0xFF8A6500);
  if (percentage >= 25) return const Color(0xFFC2410C);
  return const Color(0xFFB91C1C);
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
    this.accent,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final blueAccent = isBlueAccentTheme(context);
    final tint = accent;
    final surface = dark ? const Color(0xFF142233) : const Color(0xFFF7FAFE);
    final themedTint = tint == null ? null : dark ? tint :
        Color.lerp(tint, const Color(0xFF172B40), .55)!;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: themedTint != null
              ? [Color.alphaBlend(themedTint.withValues(alpha: .11), surface),
                 Color.alphaBlend(themedTint.withValues(alpha: .025), surface)]
              : blueAccent
              ? const [Color(0xFF101B2A), Color(0xFF0B1420)]
              : dark
                  ? const [kCardGradientTop, kCardGradientBottom]
                  : const [Color(0xFFF8FBFF), Color(0xFFE8F0F8)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: themedTint != null
              ? themedTint.withValues(alpha: .38)
              : blueAccent
              ? const Color(0xFF294766)
              : dark
                  ? const Color(0xFF304055)
                  : const Color(0xFF647B95),
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
    final blueAccent = isBlueAccentTheme(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: blueAccent
              ? const [Color(0xFF102842), Color(0xFF132239), Color(0xFF111827)]
              : dark
                  ? const [
                      Color(0xFF153329),
                      Color(0xFF132239),
                      Color(0xFF191A2A)
                    ]
                  : const [
                      Color(0xFFF4F8FD),
                      Color(0xFFE4EDF7),
                      Color(0xFFD9E6F3)
                    ],
        ),
        border: Border.all(
          color: blueAccent
              ? const Color(0xFF2D5A87)
              : dark
                  ? const Color(0xFF315044)
                  : const Color(0xFF647B95),
        ),
        boxShadow: [
          BoxShadow(
            color: appPrimaryColor(context).withValues(alpha: .12),
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
            Text(
              trailing!,
              style: TextStyle(color: appMutedColor(context), fontSize: 12),
            ),
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
      style: TextStyle(
        color: appMutedColor(context),
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
      child: Text(text, style: TextStyle(color: appMutedColor(context))),
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
