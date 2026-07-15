part of '../main.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [kPrimary, kSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withValues(alpha: .22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(
        Icons.electric_rickshaw,
        color: Color(0xFF06251C),
        size: 21,
      ),
    );
  }
}

class AppBackground extends StatelessWidget {
  const AppBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B1718),
            Color(0xFF080D14),
            Color(0xFF101827),
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
      setState(() => error = 'Escribe un nombre para tu vehiculo.');
      return;
    }
    if (initialOdometer < 0) {
      setState(() => error = 'El odometro no puede ser negativo.');
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
        setState(() => error = 'No se pudo guardar el vehiculo.');
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
                  const Center(child: AppLogoMark()),
                  const SizedBox(height: 18),
                  const Text(
                    'Configura tu primer Tuk Tuk',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tu espacio comienza vacio. Estos datos identifican el vehiculo al que perteneceran tus registros.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kMuted, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  GlassCard(
                    child: Column(
                      children: [
                        TextField(
                          controller: name,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del vehiculo',
                            prefixIcon: Icon(Icons.electric_rickshaw),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: registration,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Matricula o identificador (opcional)',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: odometer,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Odometro actual (opcional)',
                            suffixText: 'km',
                            prefixIcon: Icon(Icons.speed),
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
                            label: const Text('Comenzar'),
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
                      label: const Text('Entrar con Google primero'),
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
  final store = RecordStore();
  int index = 0;

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
                tooltip: 'Sincronizar',
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
                  colors: [
                    Colors.white.withValues(alpha: .13),
                    const Color(0xD9142230),
                    const Color(0xE6081019),
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
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard),
                        label: 'Inicio',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.add_circle_outline),
                        selectedIcon: Icon(Icons.add_circle),
                        label: 'Nuevo',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.history_outlined),
                        selectedIcon: Icon(Icons.history),
                        label: 'Historial',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.insights_outlined),
                        selectedIcon: Icon(Icons.insights),
                        label: 'Estads.',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.account_circle_outlined),
                        selectedIcon: Icon(Icons.account_circle),
                        label: 'Usuario',
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

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({required this.store, super.key});

  final RecordStore store;

  @override
  Widget build(BuildContext context) {
    final metrics = Metrics(store.records);
    final maintenance = MaintenanceSnapshot.from(
      records: store.maintenanceRecords,
      intervalKm: store.maintenanceIntervalKm,
      currentOdometer: metrics.latestOdometer,
    );
    final recent = store.records.take(3).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OdometerHero(value: metrics.latestOdometer),
        const SizedBox(height: 12),
        MetricHero(
          label: 'Ganancia de hoy',
          value: money(metrics.todayEarnings),
          sublabel: 'Mes actual: ${money(metrics.currentCycleEarnings)}',
          icon: Icons.payments_outlined,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'Mes',
                value: metrics.currentCycle.label,
                icon: Icons.route_outlined,
                color: kTertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: 'Distancia del mes',
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
                label: 'Total historico',
                value: money(metrics.totalEarnings),
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: 'Eficiencia',
                value: '${numFmt(metrics.efficiency)} CUP/km',
                icon: Icons.bolt_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        MaintenanceDashboardCard(snapshot: maintenance),
        const SizedBox(height: 20),
        SectionTitle(
          title: 'Actividad reciente',
          trailing: store.records.isEmpty
              ? null
              : '${store.records.length} registros',
        ),
        if (recent.isEmpty)
          const EmptyState('Aun no hay recorridos. Registra el primer dia.')
        else
          ...recent.map((record) => RecordTile(record: record)),
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

class _RegisterScreenState extends State<RegisterScreen> {
  late DateTime date;
  late final TextEditingController earnings;
  late final TextEditingController odometer;
  late final TextEditingController battery;
  late final TextEditingController note;
  late bool chargeTo80v;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    date = record?.date ?? DateTime.now();
    earnings = TextEditingController(
        text: record == null ? '' : trimNum(record.earnings));
    odometer = TextEditingController(
        text: record == null ? '' : trimNum(record.odometer));
    battery =
        TextEditingController(text: record?.batteryPercent?.toString() ?? '');
    note = TextEditingController(text: record?.note ?? '');
    chargeTo80v = record?.chargeTo80v ?? false;
  }

  @override
  void dispose() {
    earnings.dispose();
    odometer.dispose();
    battery.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.record != null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionTitle(title: editing ? 'Editar registro' : 'Registro diario'),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: pickDate,
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(DateFormat('EEEE d MMMM yyyy', 'es').format(date)),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: earnings,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Ganancia del dia (CUP, opcional)',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: odometer,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Odometro final (km, opcional)',
            prefixIcon: Icon(Icons.speed),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: battery,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Bateria o carga (%) opcional',
            prefixIcon: Icon(Icons.battery_charging_full_outlined),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: chargeTo80v,
          onChanged: (value) => setState(() {
            chargeTo80v = value;
          }),
          title: const Text('Carga hasta 80 V'),
          secondary: const Icon(Icons.ev_station_outlined),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: note,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Nota opcional',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: save,
          icon: const Icon(Icons.save_outlined),
          label: Text(editing ? 'Guardar cambios' : 'Guardar registro'),
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

  Future<void> save() async {
    final earned = _parseOptionalNumber(earnings.text) ?? 0;
    final odo = _parseOptionalNumber(odometer.text) ?? 0;
    final pct = _parseOptionalNumber(battery.text)?.round();
    if (earned < 0 || odo < 0) {
      toast(context, 'Ganancia y odometro no pueden ser negativos');
      return;
    }
    if (earned == 0 && odo == 0 && !chargeTo80v && note.text.trim().isEmpty) {
      toast(context, 'Agrega ganancia, odometro, carga o una nota');
      return;
    }
    if (pct != null && (pct < 0 || pct > 100)) {
      toast(context, 'La bateria debe estar entre 0 y 100');
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
              batteryPercent: pct,
              chargeTo80v: chargeTo80v,
              note: note.text.trim(),
            )
          : DailyRecord(
              id: base.id,
              date: date,
              earnings: earned,
              odometer: odo,
              batteryPercent: pct,
              chargeTo80v: chargeTo80v,
              note: note.text.trim(),
              createdAt: base.createdAt,
              deviceId: base.deviceId,
              schemaVersion: base.schemaVersion,
            ),
    );
    if (!mounted) return;
    toast(context, 'Registro guardado');
    if (base != null) Navigator.pop(context);
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({required this.store, super.key});

  final RecordStore store;

  @override
  Widget build(BuildContext context) {
    final records = store.records;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionTitle(
            title: 'Historial editable', trailing: '${records.length} dias'),
        if (records.isEmpty)
          const EmptyState('Cuando guardes registros, apareceran aqui.')
        else
          ...records.map((record) => Dismissible(
                key: ValueKey(record.id),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: kDanger.withValues(alpha: .25),
                  child: const Icon(Icons.delete_outline, color: kDanger),
                ),
                confirmDismiss: (_) => confirmDelete(context),
                onDismissed: (_) => store.delete(record.id),
                child: RecordTile(
                  record: record,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Editar registro')),
                        body: RegisterScreen(store: store, record: record),
                      ),
                    ),
                  ),
                ),
              )),
      ],
    );
  }

  Future<bool> confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar registro'),
            content: const Text('Esto cambiara todos los calculos derivados.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({required this.store, super.key});

  final RecordStore store;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final metrics = Metrics(widget.store.records);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionTitle(title: 'Estadisticas mensuales'),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'Promedio diario',
                value: money(metrics.averageDailyEarnings),
                icon: Icons.trending_up_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: 'Distancia total',
                value: '${numFmt(metrics.totalDistance)} km',
                icon: Icons.route_outlined,
                color: kSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        DataHealthCard(metrics: metrics),
        const SizedBox(height: 18),
        MonthlyComparisonGauge(
          comparison: metrics.comparisonFor(selectedMonth),
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
        const SizedBox(height: 18),
        const SectionTitle(title: 'Por mes'),
        if (metrics.cycleSummaries.isEmpty)
          const EmptyState(
              'Los meses se calculan del dia 1 al ultimo dia del mes.')
        else
          ...metrics.cycleSummaries.map((cycle) => GlassCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(cycle.label),
                  subtitle: Text('${numFmt(cycle.distance)} km'),
                  trailing: Text(
                    money(cycle.earnings),
                    style: const TextStyle(
                      color: kPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )),
      ],
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
        const SectionTitle(title: 'Inicio con Google'),
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
                user == null ? 'No conectado' : user.email,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                user == null
                    ? 'Conecta Google para guardar la base de datos en Google Drive y recuperarla al reinstalar.'
                    : store.syncMessage,
                style: const TextStyle(color: kMuted),
              ),
              const SizedBox(height: 8),
              Text(
                '${store.pendingSyncCount} cambios locales preparados para futura sincronizacion',
                style: const TextStyle(color: kMuted, fontSize: 12),
              ),
              if (store.lastSyncAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Ultima sincronizacion: ${DateFormat('d MMM, HH:mm', 'es').format(store.lastSyncAt!)}',
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
                label: Text(
                    user == null ? 'Entrar con Google' : 'Respaldar ahora'),
              ),
              if (user != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: store.syncing ? null : store.restoreThenSync,
                      icon: const Icon(Icons.restore_outlined),
                      label: const Text('Recuperar desde Drive'),
                    ),
                    TextButton.icon(
                      onPressed: store.signOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Cerrar sesion'),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        VehicleSettingsPanel(store: store),
        const SizedBox(height: 18),
        MaintenanceSettingsPanel(store: store),
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
        const SnackBar(content: Text('Vehiculo actualizado')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.store.activeVehicle;
    if (vehicle == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Vehiculo activo'),
        GlassCard(
          child: Column(
            children: [
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre del vehiculo',
                  prefixIcon: Icon(Icons.electric_rickshaw),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: registration,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Matricula o identificador',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
              InfoLine(
                label: 'Identificador interno',
                value: vehicle.id,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar vehiculo'),
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
        const SectionTitle(title: 'Ajustes de mantenimiento'),
        GlassCard(
          child: Column(
            children: [
              TextField(
                controller: interval,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Intervalo de mantenimiento (km)',
                  prefixIcon: Icon(Icons.settings_suggest_outlined),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: saveInterval,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar intervalo'),
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
                appBar: AppBar(title: const Text('Nuevo mantenimiento')),
                body: MaintenanceFormScreen(store: widget.store),
              ),
            ),
          ),
          icon: const Icon(Icons.add_task_outlined),
          label: const Text('Registrar mantenimiento'),
        ),
        const SizedBox(height: 12),
        if (records.isEmpty)
          const EmptyState('Sin mantenimientos registrados.')
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
                            appBar: AppBar(
                                title: const Text('Editar mantenimiento')),
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
                        '${DateFormat('d MMM yyyy, HH:mm', 'es').format(record.dateTime)} - ${numFmt(record.odometer)} km',
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
      toast(context, 'El intervalo debe ser mayor que 0');
      return;
    }
    await widget.store.setMaintenanceInterval(value);
    if (!mounted) return;
    toast(context, 'Intervalo guardado');
  }

  Future<bool> confirmDeleteMaintenance(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar mantenimiento'),
            content: const Text('El proximo mantenimiento se recalculara.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
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
          title: widget.record == null
              ? 'Registrar mantenimiento'
              : 'Editar mantenimiento',
        ),
        FilledButton.tonalIcon(
          onPressed: pickDate,
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(DateFormat('EEEE d MMMM yyyy', 'es').format(date)),
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
          decoration: const InputDecoration(
            labelText: 'Kilometraje del mantenimiento',
            prefixIcon: Icon(Icons.speed),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: type,
          decoration: const InputDecoration(
            labelText: 'Tipo de mantenimiento',
            prefixIcon: Icon(Icons.category_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: description,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Descripcion',
            prefixIcon: Icon(Icons.description_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: cost,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Costo opcional',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: notes,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Observaciones',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar mantenimiento'),
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
      toast(context, 'El kilometraje debe ser valido');
      return;
    }
    if (type.text.trim().isEmpty || description.text.trim().isEmpty) {
      toast(context, 'Faltan tipo o descripcion');
      return;
    }
    if (cost.text.trim().isNotEmpty && parsedCost == null) {
      toast(context, 'El costo no es valido');
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
    toast(context, 'Mantenimiento guardado');
    Navigator.pop(context);
  }
}
