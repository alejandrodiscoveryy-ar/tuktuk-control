part of '../main.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.store, super.key});

  final RecordStore store;

  @override
  State<AppShell> createState() => _AppShellState();
}

class AppLogoMark extends StatelessWidget {
  const AppLogoMark({this.size = 34, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .24),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withValues(alpha: .28),
            blurRadius: size * .35,
            offset: Offset(0, size * .12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .24),
        child: Image.asset(
          'assets/branding/tuktuk_logo.png',
          fit: BoxFit.cover,
          semanticLabel: 'TukTuk Control',
        ),
      ),
    );
  }
}

class AppBackground extends StatelessWidget {
  const AppBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [
                  Color(0xFF0B1718),
                  Color(0xFF080D14),
                  Color(0xFF101827),
                ]
              : const [
                  Color(0xFFE7F8F3),
                  Color(0xFFF7FAFE),
                  Color(0xFFEAF1FC),
                ],
        ),
      ),
      child: child,
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.store, super.key});

  final RecordStore store;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final name = TextEditingController(text: 'Mi Tuk Tuk');
  final registration = TextEditingController();
  final odometer = TextEditingController();
  bool saving = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    registration.dispose();
    odometer.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final cleanName = name.text.trim();
    final initialOdometer = double.tryParse(odometer.text.trim()) ?? 0;
    if (cleanName.isEmpty) {
      setState(() => error = tr('Escribe un nombre para tu vehiculo.'));
      return;
    }
    if (initialOdometer < 0) {
      setState(() => error = tr('El odometro no puede ser negativo.'));
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.store.configureFirstVehicle(
        name: cleanName,
        registration: registration.text,
        initialOdometer: initialOdometer,
      );
    } catch (_) {
      if (mounted) {
        setState(() => error = tr('No se pudo guardar el vehiculo.'));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(24),
                children: [
                  const Center(child: AppLogoMark(size: 92)),
                  const SizedBox(height: 18),
                  Text(
                    tr('Configura tu primer Tuk Tuk'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('Tu espacio comienza vacio. Estos datos identifican el vehiculo al que perteneceran tus registros.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: kMuted, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  GlassCard(
                    child: Column(
                      children: [
                        TextField(
                          controller: name,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: tr('Nombre del vehiculo'),
                            prefixIcon: const Icon(Icons.electric_rickshaw),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: registration,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText:
                                tr('Matricula o identificador (opcional)'),
                            prefixIcon: const Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: odometer,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: tr('Odometro actual (opcional)'),
                            suffixText: 'km',
                            prefixIcon: const Icon(Icons.speed),
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          Text(error!, style: const TextStyle(color: kDanger)),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: saving ? null : submit,
                            icon: saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward),
                            label: Text(tr('Comenzar')),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (widget.store.user == null)
                    TextButton.icon(
                      onPressed: saving ? null : widget.store.signIn,
                      icon: const Icon(Icons.login),
                      label: Text(tr('Entrar con Google primero')),
                    )
                  else
                    Text(
                      'Cuenta: ${widget.store.user!.email}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: kMuted),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  RecordStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        if (!store.initialized) {
          return const Scaffold(
            body: AppBackground(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (store.needsOnboarding) {
          return OnboardingScreen(store: store);
        }
        final screens = [
          DashboardScreen(store: store),
          RegisterScreen(store: store),
          HistoryScreen(store: store),
          StatsScreen(store: store),
          const StoreScreen(),
          LoginScreen(store: store),
        ];
        return Scaffold(
          extendBody: true,
          appBar: AppBar(
            title: const Row(
              children: [
                AppLogoMark(),
                SizedBox(width: 8),
                Text('TukTuk Control'),
              ],
            ),
            actions: [
              IconButton(
                tooltip: tr('Sincronizar'),
                onPressed:
                    store.user == null || store.syncing ? null : store.syncNow,
                icon: store.syncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_sync_outlined),
              ),
            ],
          ),
          body: AppBackground(
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: screens[index],
                ),
              ),
            ),
          ),
          floatingActionButton: index == 0
              ? Semantics(
                  button: true,
                  label: tr('Agregar nuevo registro'),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [kPrimary, kSecondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: kPrimary.withValues(alpha: .3),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: FloatingActionButton(
                      tooltip: tr('Agregar nuevo'),
                      heroTag: 'home-new-record',
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      foregroundColor: kBg,
                      onPressed: () => setState(() => index = 1),
                      child: const Icon(Icons.add_rounded, size: 32),
                    ),
                  ),
                )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: _LiquidGlassNavigation(
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
          ),
        );
      },
    );
  }
}

class _LiquidGlassNavigation extends StatelessWidget {
  const _LiquidGlassNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 34,
              offset: Offset(0, 16),
            ),
            BoxShadow(
              color: Color(0x182DD4A3),
              blurRadius: 24,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: .13)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? [
                          Colors.white.withValues(alpha: .13),
                          const Color(0xD9142230),
                          const Color(0xE6081019),
                        ]
                      : [
                          Colors.white.withValues(alpha: .92),
                          const Color(0xDDE7F1FA),
                          const Color(0xEED8E7F3),
                        ],
                  stops: const [0, .42, 1],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 26,
                    right: 26,
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: .5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  NavigationBar(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onDestinationSelected,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    destinations: [
                      NavigationDestination(
                        icon: const Icon(Icons.dashboard_outlined),
                        selectedIcon: const Icon(Icons.dashboard),
                        label: tr('Inicio'),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.add_circle_outline),
                        selectedIcon: const Icon(Icons.add_circle),
                        label: tr('Nuevo'),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.history_outlined),
                        selectedIcon: const Icon(Icons.history),
                        label: tr('Historial'),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.insights_outlined),
                        selectedIcon: const Icon(Icons.insights),
                        label: tr('Estads.'),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.storefront_outlined),
                        selectedIcon: const Icon(Icons.storefront),
                        label: tr('Tienda'),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.account_circle_outlined),
                        selectedIcon: const Icon(Icons.account_circle),
                        label: tr('Usuario'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({required this.store, super.key});

  final RecordStore store;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final metrics = Metrics(widget.store.records);
    final maintenance = MaintenanceSnapshot.from(
      records: widget.store.maintenanceRecords,
      intervalKm: widget.store.maintenanceIntervalKm,
      currentOdometer: metrics.latestOdometer,
    );
    final comparison = metrics.comparisonFor(selectedMonth);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        MetricHero(
          label: tr('Ingreso de hoy'),
          value: money(metrics.todayEarnings),
          sublabel:
              '${tr('Mes actual')}: ${money(metrics.currentCycleEarnings)}',
          icon: Icons.payments_outlined,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: tr('Mes'),
                value: metrics.currentCycle.label,
                icon: Icons.route_outlined,
                color: kTertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: tr('Distancia del mes'),
                value: '${numFmt(metrics.currentCycleDistance)} km',
                icon: Icons.route_outlined,
                color: kSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: tr('Ingresos históricos'),
                value: money(metrics.totalEarnings),
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: tr('Eficiencia'),
                value: '${numFmt(metrics.efficiency)} $activeCurrency/km',
                icon: Icons.bolt_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: tr('Gastos del mes'),
                value: money(metrics.currentCycleExpenses),
                icon: Icons.receipt_long_outlined,
                color: kDanger,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: tr('Ganancia neta del mes'),
                value: money(metrics.currentCycleNet),
                icon: Icons.account_balance_outlined,
                color: metrics.currentCycleNet >= 0 ? kPrimary : kDanger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        MonthlyComparisonGauge(
          comparison: comparison,
          onPreviousMonth: () => setState(
            () => selectedMonth =
                DateTime(selectedMonth.year, selectedMonth.month - 1),
          ),
          onNextMonth: () => setState(
            () => selectedMonth =
                DateTime(selectedMonth.year, selectedMonth.month + 1),
          ),
          canGoNext: selectedMonth.isBefore(
            DateTime(DateTime.now().year, DateTime.now().month),
          ),
        ),
        const SizedBox(height: 14),
        MaintenanceDashboardCard(snapshot: maintenance),
        const SizedBox(height: 20),
        SectionTitle(title: tr('Hitos y mensajes del sistema')),
        DriverSystemMessages(
          metrics: metrics,
          maintenance: maintenance,
          comparison: comparison,
        ),
      ],
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({required this.store, super.key, this.record});

  final RecordStore store;
  final DailyRecord? record;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

enum _NewRecordType { earnings, expense, charge, maintenance }

class _RegisterScreenState extends State<RegisterScreen> {
  late DateTime date;
  late final TextEditingController earnings;
  late final TextEditingController expense;
  late final TextEditingController expenseCategory;
  late final TextEditingController odometer;
  late final TextEditingController battery;
  late final TextEditingController note;
  late bool chargeTo80v;
  _NewRecordType recordType = _NewRecordType.earnings;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    date = record?.date ?? DateTime.now();
    earnings = TextEditingController(
        text: record == null ? '' : trimNum(record.earnings));
    expense = TextEditingController(
        text: record == null ? '' : trimNum(record.expense));
    expenseCategory =
        TextEditingController(text: record?.expenseCategory ?? '');
    odometer = TextEditingController(
        text: record == null ? '' : trimNum(record.odometer));
    battery =
        TextEditingController(text: record?.batteryPercent?.toString() ?? '');
    note = TextEditingController(text: record?.note ?? '');
    chargeTo80v = record?.chargeTo80v ?? false;
    if ((record?.expense ?? 0) > 0) recordType = _NewRecordType.expense;
  }

  @override
  void dispose() {
    earnings.dispose();
    expense.dispose();
    expenseCategory.dispose();
    odometer.dispose();
    battery.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.record != null;
    final editingExpense = editing && widget.record!.expense > 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionTitle(
          title: tr(editing ? 'Editar registro' : 'Nuevo registro'),
        ),
        if (!editing) ...[
          const SizedBox(height: 8),
          Text(
            tr('Selecciona qué dato vas a guardar.'),
            style: const TextStyle(color: kMuted),
          ),
          const SizedBox(height: 14),
          SegmentedButton<_NewRecordType>(
            segments: [
              ButtonSegment(
                value: _NewRecordType.earnings,
                icon: const Icon(Icons.payments_outlined),
                label: Text(tr('Ingreso')),
              ),
              ButtonSegment(
                value: _NewRecordType.expense,
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text(tr('Gasto')),
              ),
              ButtonSegment(
                value: _NewRecordType.charge,
                icon: const Icon(Icons.ev_station_outlined),
                label: Text(tr('Carga')),
              ),
              ButtonSegment(
                value: _NewRecordType.maintenance,
                icon: const Icon(Icons.build_outlined),
                label: Text(tr('Mant.')),
              ),
            ],
            selected: {recordType},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => setState(() {
              recordType = selection.first;
              if (recordType == _NewRecordType.charge) chargeTo80v = true;
            }),
          ),
          const SizedBox(height: 18),
        ],
        if (!editing && recordType == _NewRecordType.maintenance) ...[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Label(tr('Registrar mantenimiento')),
                const SizedBox(height: 8),
                Text(
                  tr('Guarda kilometraje, trabajo realizado, fecha, hora y costo.'),
                  style: const TextStyle(color: kMuted),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar:
                              AppBar(title: Text(tr('Nuevo mantenimiento'))),
                          body: MaintenanceFormScreen(store: widget.store),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.add_task_outlined),
                    label: Text(tr('Completar mantenimiento')),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: pickDate,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
                DateFormat('EEEE d MMMM yyyy', activeLanguage).format(date)),
          ),
          const SizedBox(height: 14),
          if ((editing && !editingExpense) ||
              recordType == _NewRecordType.earnings) ...[
            TextField(
              controller: earnings,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr('Ingreso del día'),
                suffixText: activeCurrency,
                prefixIcon: const Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: odometer,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr('Odómetro final (km, opcional)'),
                prefixIcon: const Icon(Icons.speed),
              ),
            ),
          ],
          if (editingExpense ||
              (!editing && recordType == _NewRecordType.expense)) ...[
            TextField(
              controller: expense,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr('Importe del gasto'),
                suffixText: activeCurrency,
                prefixIcon: const Icon(Icons.receipt_long_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: expenseCategory,
              decoration: InputDecoration(
                labelText: tr('Categoría del gasto'),
                prefixIcon: const Icon(Icons.sell_outlined),
              ),
            ),
          ],
          if ((editing && !editingExpense) ||
              recordType == _NewRecordType.charge) ...[
            if (editing) const SizedBox(height: 12),
            TextField(
              controller: battery,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr('Batería o carga (%)'),
                prefixIcon: const Icon(Icons.battery_charging_full_outlined),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: chargeTo80v,
              onChanged: (value) => setState(() => chargeTo80v = value),
              title: Text(tr('Carga completada hasta 80 V')),
              secondary: const Icon(Icons.ev_station_outlined),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: note,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: tr('Nota opcional'),
              prefixIcon: const Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              editing
                  ? tr('Guardar cambios')
                  : recordType == _NewRecordType.charge
                      ? tr('Guardar carga')
                      : recordType == _NewRecordType.expense
                          ? tr('Guardar gasto')
                          : tr('Guardar ingreso'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted) return;
    if (picked != null) setState(() => date = picked);
  }

  Future<void> save() async {
    final isCharge = !editingRecord && recordType == _NewRecordType.charge;
    final isExpense = (editingRecord && widget.record!.expense > 0) ||
        (!editingRecord && recordType == _NewRecordType.expense);
    final earned = (isCharge || isExpense)
        ? 0.0
        : _parseOptionalNumber(earnings.text) ?? 0.0;
    final spent = isExpense ? _parseOptionalNumber(expense.text) ?? 0.0 : 0.0;
    final odo = (isCharge || isExpense)
        ? 0.0
        : _parseOptionalNumber(odometer.text) ?? 0.0;
    final pct = _parseOptionalNumber(battery.text)?.round();
    if (earned < 0 || spent < 0 || odo < 0) {
      toast(context, tr('Ingreso, gasto y odometro no pueden ser negativos'));
      return;
    }
    if (earned == 0 &&
        spent == 0 &&
        odo == 0 &&
        !chargeTo80v &&
        note.text.trim().isEmpty) {
      toast(context, tr('Agrega ingreso, gasto, odometro, carga o una nota'));
      return;
    }
    if (pct != null && (pct < 0 || pct > 100)) {
      toast(context, tr('La bateria debe estar entre 0 y 100'));
      return;
    }
    final base = widget.record;
    await widget.store.save(
      base == null
          ? DailyRecord(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              date: date,
              earnings: earned,
              odometer: odo,
              expense: spent,
              expenseCategory: expenseCategory.text.trim(),
              batteryPercent: pct,
              chargeTo80v: chargeTo80v,
              note: note.text.trim(),
            )
          : DailyRecord(
              id: base.id,
              date: date,
              earnings: earned,
              odometer: odo,
              expense: spent,
              expenseCategory: expenseCategory.text.trim(),
              batteryPercent: pct,
              chargeTo80v: chargeTo80v,
              note: note.text.trim(),
              createdAt: base.createdAt,
              deviceId: base.deviceId,
              schemaVersion: base.schemaVersion,
            ),
    );
    if (!mounted) return;
    toast(context, tr('Registro guardado'));
    if (base != null) Navigator.pop(context);
  }

  bool get editingRecord => widget.record != null;
}

enum _HistoryFilter { all, earnings, expense, odometer, charge, maintenance }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({required this.store, super.key});

  final RecordStore store;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final search = TextEditingController();
  _HistoryFilter filter = _HistoryFilter.all;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final term = search.text.trim().toLowerCase();
    final records = widget.store.records.where((record) {
      final matchesType = filter == _HistoryFilter.all ||
          (filter == _HistoryFilter.earnings && record.earnings > 0) ||
          (filter == _HistoryFilter.expense && record.expense > 0) ||
          (filter == _HistoryFilter.odometer && record.odometer > 0) ||
          (filter == _HistoryFilter.charge && record.chargeTo80v);
      final haystack = '${record.note} ${numFmt(record.odometer)} '
              '${DateFormat('d MMM yyyy', activeLanguage).format(record.date)}'
          .toLowerCase();
      return matchesType && (term.isEmpty || haystack.contains(term));
    }).toList();
    final showMaintenance =
        filter == _HistoryFilter.all || filter == _HistoryFilter.maintenance;
    final maintenances = showMaintenance
        ? widget.store.maintenanceRecords.where((record) {
            final haystack = '${record.type} ${record.description} '
                    '${record.notes} ${numFmt(record.odometer)}'
                .toLowerCase();
            return term.isEmpty || haystack.contains(term);
          }).toList()
        : <MaintenanceRecord>[];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionTitle(title: tr('Historial editable')),
        Text(
          tr('Cada cambio recalcula el inicio y las estadísticas.'),
          style: const TextStyle(color: kMuted),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<_HistoryFilter>(
            segments: [
              ButtonSegment(
                value: _HistoryFilter.all,
                icon: const Icon(Icons.view_list_rounded),
                label: Text(tr('Todos')),
              ),
              ButtonSegment(
                value: _HistoryFilter.earnings,
                icon: const Icon(Icons.payments_outlined),
                label: Text(tr('Ingreso')),
              ),
              ButtonSegment(
                value: _HistoryFilter.expense,
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text(tr('Gasto')),
              ),
              ButtonSegment(
                value: _HistoryFilter.odometer,
                icon: const Icon(Icons.speed_rounded),
                label: Text(tr('Odómetro')),
              ),
              ButtonSegment(
                value: _HistoryFilter.charge,
                icon: const Icon(Icons.ev_station_outlined),
                label: Text(tr('Carga')),
              ),
              ButtonSegment(
                value: _HistoryFilter.maintenance,
                icon: const Icon(Icons.build_outlined),
                label: Text(tr('Mant.')),
              ),
            ],
            selected: {filter},
            showSelectedIcon: false,
            onSelectionChanged: (value) => setState(() => filter = value.first),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: tr('Buscar por fecha, nota o km'),
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 16),
        if (records.isEmpty && maintenances.isEmpty)
          EmptyState(tr('Cuando guardes registros, apareceran aqui.'))
        else ...[
          ...records.map((record) => Dismissible(
                key: ValueKey(record.id),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: kDanger.withValues(alpha: .25),
                  child: const Icon(Icons.delete_outline, color: kDanger),
                ),
                confirmDismiss: (_) => confirmDelete(context),
                onDismissed: (_) => widget.store.delete(record.id),
                child: RecordTile(
                  record: record,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: Text(tr('Editar registro'))),
                        body:
                            RegisterScreen(store: widget.store, record: record),
                      ),
                    ),
                  ),
                ),
              )),
          ...maintenances.map((record) => GlassCard(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.build_outlined, color: kPrimary),
                  title: Text(record.type),
                  subtitle: Text(
                    '${DateFormat('d MMM yyyy, HH:mm', activeLanguage).format(record.dateTime)} · ${numFmt(record.odometer)} km\n${record.description}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: Text(tr('Editar mantenimiento'))),
                        body: MaintenanceFormScreen(
                          store: widget.store,
                          record: record,
                        ),
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ],
    );
  }

  Future<bool> confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(tr('Eliminar registro')),
            content: Text(tr('Esto cambiara todos los calculos derivados.')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(tr('Cancelar')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(tr('Eliminar')),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({required this.store, super.key});

  final RecordStore store;

  @override
  Widget build(BuildContext context) {
    final metrics = Metrics(store.records);
    final earningRecords = store.records
        .where((record) => record.earnings > 0)
        .toList()
      ..sort((a, b) => b.earnings.compareTo(a.earnings));
    final cycles = metrics.cycleSummaries;
    final bestCycle = cycles.isEmpty
        ? null
        : cycles.reduce((a, b) => a.earnings >= b.earnings ? a : b);
    final maintenance = MaintenanceSnapshot.from(
      records: store.maintenanceRecords,
      intervalKm: store.maintenanceIntervalKm,
      currentOdometer: metrics.latestOdometer,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionTitle(title: tr('Estadísticas')),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 700
                ? (constraints.maxWidth - 24) / 3
                : (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                StatOverviewCard(
                    width: width,
                    label: tr('Ingresos totales'),
                    value: money(metrics.totalEarnings)),
                StatOverviewCard(
                    width: width,
                    label: tr('Gastos totales'),
                    value: money(metrics.totalExpenses),
                    color: kDanger),
                StatOverviewCard(
                    width: width,
                    label: tr('Ganancia neta'),
                    value: money(metrics.netEarnings),
                    color: metrics.netEarnings >= 0 ? kPrimary : kDanger),
                StatOverviewCard(
                    width: width,
                    label: tr('Ingreso promedio por día trabajado'),
                    value: money(metrics.averageDailyEarnings)),
                StatOverviewCard(
                    width: width,
                    label: tr('Eficiencia'),
                    value: '${numFmt(metrics.efficiency)} $activeCurrency/km'),
                StatOverviewCard(
                  width: width,
                  label: tr('Mejor día'),
                  value: earningRecords.isEmpty
                      ? '-'
                      : money(earningRecords.first.earnings),
                  note: earningRecords.isEmpty
                      ? tr('Sin datos')
                      : DateFormat('d MMM yyyy', activeLanguage)
                          .format(earningRecords.first.date),
                ),
                StatOverviewCard(
                  width: width,
                  label: tr('Mejor mes'),
                  value: bestCycle == null ? '-' : money(bestCycle.earnings),
                  note: bestCycle?.label ?? tr('Sin datos mensuales'),
                ),
                StatOverviewCard(
                  width: width,
                  label: tr('Mantenimiento'),
                  value: tr(maintenance.status),
                  note: maintenance.remainingKm < 0
                      ? '${tr('Vencido por')} ${numFmt(maintenance.remainingKm.abs())} km'
                      : '${tr('Próximo en')} ${numFmt(maintenance.remainingKm)} km',
                  color: maintenance.color,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        SectionTitle(title: tr('Ingresos por mes')),
        MonthlyEarningsBars(cycles: cycles),
        const SizedBox(height: 18),
        SectionTitle(title: tr('Tendencia de días trabajados')),
        EarningsTrendCard(records: earningRecords.take(10).toList().reversed),
        const SizedBox(height: 18),
        SectionTitle(title: tr('Información relevante')),
        DataHealthCard(metrics: metrics),
      ],
    );
  }
}

Uri buildRevolicoSearchUri(String term) => Uri.https(
      'www.revolico.com',
      '/search',
      {'q': term.trim(), 'order': 'relevance'},
    );

Uri buildWhatsAppSupportUri() => Uri.https(
      'wa.me',
      '/5355592873',
      {'text': 'Hola, necesito ayuda con TukTuk Control.'},
    );

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final search = TextEditingController();

  static const categories = <_StoreCategory>[
    _StoreCategory('Baterías', 'batería 72V', Icons.battery_charging_full),
    _StoreCategory('Cargadores', 'cargador 72V', Icons.electrical_services),
    _StoreCategory('Neumáticos', 'neumático triciclo', Icons.tire_repair),
    _StoreCategory('Motores', 'motor eléctrico', Icons.electric_bolt),
    _StoreCategory(
      'Controladores',
      'controlador moto eléctrica',
      Icons.memory,
    ),
    _StoreCategory(
      'Piezas eléctricas',
      'piezas eléctricas triciclo',
      Icons.cable,
    ),
    _StoreCategory(
      'Repuestos mecánicos',
      'repuestos triciclo',
      Icons.settings,
    ),
    _StoreCategory(
      'Luces y accesorios',
      'luces accesorios triciclo',
      Icons.lightbulb_outline,
    ),
    _StoreCategory('Herramientas', 'herramientas taller moto', Icons.handyman),
    _StoreCategory(
      'Triciclos eléctricos',
      'triciclo eléctrico',
      Icons.electric_rickshaw,
    ),
    _StoreCategory(
      'Talleres y reparación',
      'taller moto eléctrica',
      Icons.home_repair_service,
    ),
  ];

  static const quickSearches = <String>[
    'batería 72V',
    'batería litio triciclo',
    'batería gel',
    'cargador 72V',
    'neumático triciclo',
    'motor eléctrico',
    'controlador moto eléctrica',
    'repuestos triciclo',
    'taller moto eléctrica',
  ];

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionTitle(title: tr('Tienda')),
        Text(
          tr('Encuentra piezas, accesorios y servicios para tu vehículo.'),
          style: const TextStyle(color: kMuted, height: 1.4),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.open_in_new_rounded, color: kTertiary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr('Las búsquedas se abren externamente en Revolico. TukTuk Control no copia ni almacena anuncios.'),
                  style: const TextStyle(color: kMuted, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionTitle(title: tr('Buscar en Revolico')),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: search,
                textInputAction: TextInputAction.search,
                onSubmitted: openSearch,
                decoration: InputDecoration(
                  hintText: tr('¿Qué necesitas para tu vehículo?'),
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: () => openSearch(search.text),
              style: FilledButton.styleFrom(
                minimumSize: const Size(54, 54),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Icon(Icons.open_in_new_rounded),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SectionTitle(title: tr('Categorías')),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720 ? 3 : 2;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final category in categories)
                  SizedBox(
                    width: width,
                    child: _StoreCategoryCard(
                      category: category,
                      onTap: () => openSearch(category.query),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        SectionTitle(title: tr('Búsquedas rápidas')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final term in quickSearches)
              ActionChip(
                avatar: const Icon(Icons.north_east_rounded, size: 16),
                label: Text(term),
                onPressed: () => openSearch(term),
              ),
          ],
        ),
        const SizedBox(height: 110),
      ],
    );
  }

  Future<void> openSearch(String value) async {
    final term = value.trim();
    if (term.isEmpty) {
      toast(context, tr('Escribe lo que deseas buscar'));
      return;
    }
    final opened = await launchUrl(
      buildRevolicoSearchUri(term),
      mode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened && mounted) {
      toast(context, tr('No se pudo abrir el navegador'));
    }
  }
}

class _StoreCategory {
  const _StoreCategory(this.label, this.query, this.icon);

  final String label;
  final String query;
  final IconData icon;
}

class _StoreCategoryCard extends StatelessWidget {
  const _StoreCategoryCard({required this.category, required this.onTap});

  final _StoreCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(category.icon, color: kPrimary, size: 25),
              const SizedBox(height: 12),
              Text(
                tr(category.label),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                tr('Abrir búsqueda'),
                style: const TextStyle(color: kMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({required this.store, super.key});

  final RecordStore store;

  @override
  Widget build(BuildContext context) {
    final user = store.user;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: kPrimary.withValues(alpha: .16),
                backgroundImage: user?.photoUrl == null
                    ? null
                    : NetworkImage(user!.photoUrl!),
                child: user?.photoUrl == null
                    ? Icon(
                        user == null ? Icons.person_outline : Icons.person,
                        color: kPrimary,
                        size: 34,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Label(tr('Cuenta de usuario')),
                    const SizedBox(height: 5),
                    Text(
                      store.profileDisplayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user == null
                          ? tr('Sin cuenta Google vinculada · Guardado local')
                          : user.email,
                      style: TextStyle(
                        color: user == null ? kMuted : kPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: tr('Personalizar perfil'),
                onPressed: () => _editProfileName(context),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionTitle(title: tr('Atención al cliente')),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.support_agent_rounded,
                color: Color(0xFF25D366),
                size: 38,
              ),
              const SizedBox(height: 10),
              Text(
                tr('¿Necesitas ayuda con TukTuk Control? Escríbenos por WhatsApp.'),
                style: const TextStyle(color: kMuted, height: 1.4),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openWhatsApp(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: const Color(0xFF06170D),
                  ),
                  icon: const Icon(Icons.chat_rounded),
                  label: Text(tr('Contactar por WhatsApp')),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionTitle(title: tr('Google y respaldo')),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                user == null
                    ? Icons.cloud_off_outlined
                    : Icons.cloud_done_outlined,
                color: user == null ? kMuted : kPrimary,
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                user == null ? tr('No conectado') : user.email,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                user == null
                    ? tr(
                        'Conecta Google para guardar la base de datos en Google Drive y recuperarla al reinstalar.')
                    : tr(store.syncMessage),
                style: const TextStyle(color: kMuted),
              ),
              const SizedBox(height: 8),
              Text(
                '${store.pendingSyncCount} ${tr('cambios locales preparados para futura sincronizacion')}',
                style: const TextStyle(color: kMuted, fontSize: 12),
              ),
              if (store.lastSyncAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${tr('Ultima sincronizacion')}: ${DateFormat('d MMM, HH:mm', activeLanguage).format(store.lastSyncAt!)}',
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: store.syncing
                    ? null
                    : user == null
                        ? store.signIn
                        : store.syncNow,
                icon: Icon(
                    user == null ? Icons.login : Icons.cloud_sync_outlined),
                label: Text(user == null
                    ? tr('Entrar con Google')
                    : tr('Respaldar ahora')),
              ),
              if (user != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: store.syncing ? null : store.restoreThenSync,
                      icon: const Icon(Icons.restore_outlined),
                      label: Text(tr('Recuperar desde Drive')),
                    ),
                    TextButton.icon(
                      onPressed: store.signOut,
                      icon: const Icon(Icons.logout),
                      label: Text(tr('Cerrar sesion')),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              const Divider(color: kOutline),
              const SizedBox(height: 8),
              Label(tr('Respaldo local')),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _copyBackup(context, csv: false),
                    icon: const Icon(Icons.data_object_outlined),
                    label: Text(tr('Exportar JSON')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _copyBackup(context, csv: true),
                    icon: const Icon(Icons.table_view_outlined),
                    label: Text(tr('Exportar CSV')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _restoreBackup(context),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(tr('Restaurar JSON')),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AppPreferencesPanel(store: store),
        const SizedBox(height: 18),
        VehicleSettingsPanel(store: store),
        const SizedBox(height: 18),
        MaintenanceSettingsPanel(store: store),
      ],
    );
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final opened = await launchUrl(
      buildWhatsAppSupportUri(),
      mode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened && context.mounted) {
      toast(context, tr('No se pudo abrir WhatsApp'));
    }
  }

  Future<void> _editProfileName(BuildContext context) async {
    final controller = TextEditingController(text: store.profileDisplayName);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Personalizar perfil')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(
            labelText: tr('Nombre de usuario'),
            prefixIcon: const Icon(Icons.person_outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(tr('Guardar')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) await store.setProfileDisplayName(value);
  }

  Future<void> _copyBackup(BuildContext context, {required bool csv}) async {
    final value = csv ? store.exportBackupCsv() : store.exportBackupJson();
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      toast(context, tr(csv ? 'CSV copiado al portapapeles' : 'JSON copiado'));
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Restaurar respaldo JSON')),
        content: TextField(
          controller: controller,
          minLines: 6,
          maxLines: 12,
          decoration: InputDecoration(
            hintText: tr('Pega aquí el contenido del respaldo JSON'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(tr('Restaurar')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty) return;
    try {
      await store.restoreBackupJson(value);
      if (context.mounted) toast(context, tr('Respaldo restaurado'));
    } catch (_) {
      if (context.mounted) toast(context, tr('El respaldo JSON no es válido'));
    }
  }
}

class AppPreferencesPanel extends StatefulWidget {
  const AppPreferencesPanel({required this.store, super.key});

  final RecordStore store;

  @override
  State<AppPreferencesPanel> createState() => _AppPreferencesPanelState();
}

class _AppPreferencesPanelState extends State<AppPreferencesPanel> {
  late String currency = widget.store.preferredCurrency;
  late String language = widget.store.preferredLanguage;
  late String theme = widget.store.preferredTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: tr('Ajustes')),
        GlassCard(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: currency,
                decoration: InputDecoration(
                  labelText: tr('Moneda de trabajo'),
                  prefixIcon: const Icon(Icons.currency_exchange),
                ),
                items: [
                  DropdownMenuItem(
                      value: 'CUP', child: Text('CUP · ${tr('Peso cubano')}')),
                  DropdownMenuItem(
                      value: 'USD',
                      child: Text('USD · ${tr('Dólar estadounidense')}')),
                  DropdownMenuItem(
                      value: 'EUR', child: Text('EUR · ${tr('Euro')}')),
                  DropdownMenuItem(
                      value: 'MXN',
                      child: Text('MXN · ${tr('Peso mexicano')}')),
                ],
                onChanged: (value) => setState(() => currency = value ?? 'CUP'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: language,
                decoration: InputDecoration(
                  labelText: tr('Idioma'),
                  prefixIcon: const Icon(Icons.language_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'es', child: Text('Español')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'pt', child: Text('Português')),
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                ],
                onChanged: (value) => setState(() => language = value ?? 'es'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: theme,
                decoration: InputDecoration(
                  labelText: tr('Modo visual'),
                  prefixIcon: const Icon(Icons.contrast_outlined),
                ),
                items: [
                  DropdownMenuItem(
                      value: 'system', child: Text(tr('Predeterminado'))),
                  DropdownMenuItem(value: 'dark', child: Text(tr('Oscuro'))),
                  DropdownMenuItem(value: 'light', child: Text(tr('Claro'))),
                ],
                onChanged: (value) => setState(() => theme = value ?? 'system'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    await widget.store.savePreferences(
                      currency: currency,
                      language: language,
                      theme: theme,
                    );
                    if (context.mounted) {
                      toast(context, tr('Ajustes guardados'));
                    }
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: Text(tr('Guardar ajustes')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class VehicleSettingsPanel extends StatefulWidget {
  const VehicleSettingsPanel({required this.store, super.key});

  final RecordStore store;

  @override
  State<VehicleSettingsPanel> createState() => _VehicleSettingsPanelState();
}

class _VehicleSettingsPanelState extends State<VehicleSettingsPanel> {
  late final TextEditingController name;
  late final TextEditingController registration;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final vehicle = widget.store.activeVehicle;
    name = TextEditingController(text: vehicle?.name ?? '');
    registration = TextEditingController(text: vehicle?.registration ?? '');
  }

  @override
  void didUpdateWidget(covariant VehicleSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final vehicle = widget.store.activeVehicle;
    if (vehicle != null && name.text.isEmpty) name.text = vehicle.name;
  }

  @override
  void dispose() {
    name.dispose();
    registration.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) return;
    setState(() => saving = true);
    await widget.store.updateActiveVehicle(
      name: name.text,
      registration: registration.text,
    );
    if (mounted) {
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Vehiculo actualizado'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.store.activeVehicle;
    if (vehicle == null) return const SizedBox.shrink();
    final shortId = vehicle.id.length <= 18
        ? vehicle.id
        : '${vehicle.id.substring(0, 8)}…${vehicle.id.substring(vehicle.id.length - 6)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: tr('Vehiculo activo')),
        GlassCard(
          child: Column(
            children: [
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: tr('Nombre del vehiculo'),
                  prefixIcon: const Icon(Icons.electric_rickshaw),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: registration,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: tr('Matricula o identificador'),
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('ID interno'),
                      style: const TextStyle(color: kMuted, fontSize: 12),
                    ),
                  ),
                  Tooltip(
                    message: vehicle.id,
                    child: Text(
                      shortId,
                      style: const TextStyle(
                        color: kMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [ui.FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(tr('Guardar vehiculo')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MaintenanceSettingsPanel extends StatefulWidget {
  const MaintenanceSettingsPanel({required this.store, super.key});

  final RecordStore store;

  @override
  State<MaintenanceSettingsPanel> createState() =>
      _MaintenanceSettingsPanelState();
}

class _MaintenanceSettingsPanelState extends State<MaintenanceSettingsPanel> {
  late final TextEditingController interval;

  @override
  void initState() {
    super.initState();
    interval = TextEditingController(
      text: trimNum(widget.store.maintenanceIntervalKm),
    );
  }

  @override
  void didUpdateWidget(covariant MaintenanceSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = trimNum(widget.store.maintenanceIntervalKm);
    if (interval.text != current) interval.text = current;
  }

  @override
  void dispose() {
    interval.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final records = widget.store.maintenanceRecords;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: tr('Ajustes de mantenimiento')),
        GlassCard(
          child: Column(
            children: [
              TextField(
                controller: interval,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr('Intervalo de mantenimiento (km)'),
                  prefixIcon: const Icon(Icons.settings_suggest_outlined),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: saveInterval,
                icon: const Icon(Icons.save_outlined),
                label: Text(tr('Guardar intervalo')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: Text(tr('Nuevo mantenimiento'))),
                body: MaintenanceFormScreen(store: widget.store),
              ),
            ),
          ),
          icon: const Icon(Icons.add_task_outlined),
          label: Text(tr('Registrar mantenimiento')),
        ),
        const SizedBox(height: 12),
        if (records.isEmpty)
          EmptyState(tr('Sin mantenimientos registrados.'))
        else
          ...records.take(8).map(
                (record) => Dismissible(
                  key: ValueKey(record.id),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: kDanger.withValues(alpha: .25),
                    child: const Icon(Icons.delete_outline, color: kDanger),
                  ),
                  confirmDismiss: (_) => confirmDeleteMaintenance(context),
                  onDismissed: (_) => widget.store.deleteMaintenance(record.id),
                  child: GlassCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar:
                                AppBar(title: Text(tr('Editar mantenimiento'))),
                            body: MaintenanceFormScreen(
                              store: widget.store,
                              record: record,
                            ),
                          ),
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      leading:
                          const Icon(Icons.build_outlined, color: kPrimary),
                      title: Text(record.type),
                      subtitle: Text(
                        '${DateFormat('d MMM yyyy, HH:mm', activeLanguage).format(record.dateTime)} - ${numFmt(record.odometer)} km',
                      ),
                      trailing: record.cost == null
                          ? null
                          : Text(money(record.cost!)),
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  Future<void> saveInterval() async {
    final value = _parseOptionalNumber(interval.text);
    if (value == null || value <= 0) {
      toast(context, tr('El intervalo debe ser mayor que 0'));
      return;
    }
    await widget.store.setMaintenanceInterval(value);
    if (!mounted) return;
    toast(context, tr('Intervalo guardado'));
  }

  Future<bool> confirmDeleteMaintenance(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(tr('Eliminar mantenimiento')),
            content: Text(tr('El proximo mantenimiento se recalculara.')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(tr('Cancelar')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(tr('Eliminar')),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class MaintenanceFormScreen extends StatefulWidget {
  const MaintenanceFormScreen({required this.store, super.key, this.record});

  final RecordStore store;
  final MaintenanceRecord? record;

  @override
  State<MaintenanceFormScreen> createState() => _MaintenanceFormScreenState();
}

class _MaintenanceFormScreenState extends State<MaintenanceFormScreen> {
  DateTime date = DateTime.now();
  TimeOfDay time = TimeOfDay.now();
  late final TextEditingController odometer;
  late final TextEditingController type;
  late final TextEditingController description;
  late final TextEditingController cost;
  late final TextEditingController notes;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    if (record != null) {
      date = record.dateTime;
      time = TimeOfDay.fromDateTime(record.dateTime);
    }
    odometer = TextEditingController(
      text: record == null ? '' : trimNum(record.odometer),
    );
    type = TextEditingController(text: record?.type ?? 'General');
    description = TextEditingController(text: record?.description ?? '');
    final initialCost = record?.cost;
    cost = TextEditingController(
      text: initialCost == null ? '' : trimNum(initialCost),
    );
    notes = TextEditingController(text: record?.notes ?? '');
  }

  @override
  void dispose() {
    odometer.dispose();
    type.dispose();
    description.dispose();
    cost.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionTitle(
          title: tr(widget.record == null
              ? 'Registrar mantenimiento'
              : 'Editar mantenimiento'),
        ),
        FilledButton.tonalIcon(
          onPressed: pickDate,
          icon: const Icon(Icons.calendar_month_outlined),
          label:
              Text(DateFormat('EEEE d MMMM yyyy', activeLanguage).format(date)),
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: pickTime,
          icon: const Icon(Icons.schedule_outlined),
          label: Text(time.format(context)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: odometer,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: tr('Kilometraje del mantenimiento'),
            prefixIcon: const Icon(Icons.speed),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: type,
          decoration: InputDecoration(
            labelText: tr('Tipo de mantenimiento'),
            prefixIcon: const Icon(Icons.category_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: description,
          minLines: 2,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: tr('Descripcion'),
            prefixIcon: const Icon(Icons.description_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: cost,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: tr('Costo opcional'),
            prefixIcon: const Icon(Icons.payments_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: notes,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: tr('Observaciones'),
            prefixIcon: const Icon(Icons.notes_outlined),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: save,
          icon: const Icon(Icons.save_outlined),
          label: Text(tr('Guardar mantenimiento')),
        ),
      ],
    );
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted) return;
    if (picked != null) setState(() => date = picked);
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: time,
    );
    if (!mounted) return;
    if (picked != null) setState(() => time = picked);
  }

  Future<void> save() async {
    final odo = double.tryParse(odometer.text.replaceAll(',', '.'));
    final parsedCost = _parseOptionalNumber(cost.text);
    if (odo == null || odo <= 0) {
      toast(context, tr('El kilometraje debe ser valido'));
      return;
    }
    if (type.text.trim().isEmpty || description.text.trim().isEmpty) {
      toast(context, tr('Faltan tipo o descripcion'));
      return;
    }
    if (cost.text.trim().isNotEmpty && parsedCost == null) {
      toast(context, tr('El costo no es valido'));
      return;
    }
    await widget.store.saveMaintenance(
      MaintenanceRecord(
        id: widget.record?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        dateTime:
            DateTime(date.year, date.month, date.day, time.hour, time.minute),
        odometer: odo,
        type: type.text.trim(),
        description: description.text.trim(),
        cost: parsedCost,
        notes: notes.text.trim(),
        createdAt: widget.record?.createdAt,
        deviceId: widget.record?.deviceId ?? '',
        schemaVersion: widget.record?.schemaVersion ?? _databaseSchemaVersion,
      ),
    );
    if (!mounted) return;
    toast(context, tr('Mantenimiento guardado'));
    Navigator.pop(context);
  }
}
