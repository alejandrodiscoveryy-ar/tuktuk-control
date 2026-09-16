part of '../main.dart';

String _marketplaceJobServiceLabel(String? code) {
  return switch (code) {
    'passenger' => 'Pasajeros',
    'cargo' => 'Carga',
    'courier' => 'Mensajería',
    'tourism' => 'Turismo',
    _ => code?.trim().isNotEmpty == true ? code! : 'Servicio',
  };
}

String _marketplaceJobDateLabel(DateTime? value) {
  if (value == null) return 'Ahora';
  return DateFormat('dd/MM/yyyy · HH:mm').format(value.toLocal());
}

class MarketplaceJobsScreen extends StatefulWidget {
  const MarketplaceJobsScreen({
    required this.store,
    super.key,
  });

  final RecordStore store;

  @override
  State<MarketplaceJobsScreen> createState() => _MarketplaceJobsScreenState();
}

class _MarketplaceJobsScreenState extends State<MarketplaceJobsScreen> {
  late final MarketplaceService _service;

  MarketplaceOnboarding? _onboarding;
  String? _selectedVehicleId;
  List<MarketplaceAvailableJob> _available = const [];

  bool _loading = true;
  String? _error;
  String? _acceptingJobId;

  final Map<String, String> _acceptKeys = {};

  @override
  void initState() {
    super.initState();
    _service = MarketplaceService(Supabase.instance.client);
    unawaited(_load());
  }

  MarketplaceVehicle? _vehicleById(String? id) {
    if (id == null) return null;

    for (final vehicle in _onboarding?.vehicles ?? const []) {
      if (vehicle.id == id) return vehicle;
    }

    return null;
  }

  Future<void> _load() async {
    if (widget.store.user == null) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Inicia sesión con Google para ver Trabajos.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final onboarding = await _service.onboarding();

      String? vehicleId = _selectedVehicleId;

      if (vehicleId == null ||
          !onboarding.vehicles.any((vehicle) => vehicle.id == vehicleId)) {
        final preferredId = widget.store.activeVehicle?.id;

        if (preferredId != null &&
            onboarding.vehicles.any((vehicle) => vehicle.id == preferredId)) {
          vehicleId = preferredId;
        } else if (onboarding.vehicles.isNotEmpty) {
          vehicleId = onboarding.vehicles.first.id;
        } else {
          vehicleId = null;
        }
      }

      final jobs = vehicleId == null
          ? const <MarketplaceAvailableJob>[]
          : await _service.available(vehicleId);

      if (!mounted) return;

      setState(() {
        _onboarding = onboarding;
        _selectedVehicleId = vehicleId;
        _available = jobs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'No se pudieron cargar los trabajos disponibles.';
      });
    }
  }

  Future<void> _loadAvailable() async {
    final vehicleId = _selectedVehicleId;

    if (vehicleId == null) {
      if (!mounted) return;
      setState(() => _available = const []);
      return;
    }

    try {
      final jobs = await _service.available(vehicleId);

      if (!mounted || vehicleId != _selectedVehicleId) return;

      setState(() {
        _available = jobs;
        _error = null;
      });
    } catch (_) {
      if (!mounted || vehicleId != _selectedVehicleId) return;

      setState(() {
        _error = 'No se pudieron actualizar los trabajos disponibles.';
      });
    }
  }

  Future<void> _changeVehicle(String? vehicleId) async {
    if (vehicleId == null || vehicleId == _selectedVehicleId) return;

    setState(() {
      _selectedVehicleId = vehicleId;
      _available = const [];
      _error = null;
    });

    await _loadAvailable();
  }

  Future<void> _acceptJob(MarketplaceAvailableJob job) async {
    final vehicleId = _selectedVehicleId;

    if (vehicleId == null || _acceptingJobId != null) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Aceptar trabajo'),
            content: Text(
              '¿Quieres aceptar este trabajo por '
              '${_marketplaceMoneyLabel(job.finalPrice, job.currency)}?\n\n'
              'TUKTUK verificará nuevamente tu elegibilidad y asignará '
              'el trabajo únicamente si sigue disponible.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() => _acceptingJobId = job.id);

    final key = _acceptKeys[job.id] ?? _marketplaceUuidV4();
    _acceptKeys[job.id] = key;

    try {
      await _service.accept(
        job.id,
        vehicleId,
        key,
      );

      _acceptKeys.remove(job.id);

      if (!mounted) return;

      await _loadAvailable();

      if (!mounted) return;

      toast(
        context,
        'Trabajo aceptado. Ya aparece en tus trabajos activos.',
      );
    } catch (_) {
      if (mounted) {
        toast(
          context,
          'No se pudo aceptar. Puede que el trabajo ya no esté disponible '
          'o que tu cuenta necesite completar un requisito.',
        );
      }
    } finally {
      if (mounted) setState(() => _acceptingJobId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const SizedBox(height: 8),
          TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: tr('Disponibles')),
              Tab(text: tr('Activos')),
              Tab(text: tr('Programados')),
              Tab(text: tr('Historial')),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: TabBarView(
              children: [
                _buildAvailableTab(context),
                _MarketplaceJobsPlaceholder(
                  icon: Icons.route_outlined,
                  title: tr('Trabajos activos'),
                  message: tr(
                    'Aquí podrás seguir los servicios que ya aceptaste.',
                  ),
                ),
                _MarketplaceJobsPlaceholder(
                  icon: Icons.event_outlined,
                  title: tr('Trabajos programados'),
                  message: tr(
                    'Aquí aparecerán los servicios aceptados para más adelante.',
                  ),
                ),
                _MarketplaceJobsPlaceholder(
                  icon: Icons.history_rounded,
                  title: tr('Historial de trabajos'),
                  message: tr(
                    'Aquí podrás consultar los servicios ya finalizados.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableTab(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final onboarding = _onboarding;

    if (onboarding == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Column(
              children: [
                const Icon(Icons.cloud_off_outlined, size: 42),
                const SizedBox(height: 12),
                Text(
                  _error ?? 'No se pudieron cargar Trabajos.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (onboarding.vehicles.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          GlassCard(
            child: Text(
              'Necesitas un vehículo configurado para recibir trabajos.',
            ),
          ),
        ],
      );
    }

    final selectedVehicle = _vehicleById(_selectedVehicleId);

    return RefreshIndicator(
      onRefresh: _loadAvailable,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vehículo para recibir solicitudes',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedVehicleId,
                  isExpanded: true,
                  items: onboarding.vehicles
                      .map(
                        (vehicle) => DropdownMenuItem<String>(
                          value: vehicle.id,
                          child: Text(
                            vehicle.name?.trim().isNotEmpty == true
                                ? vehicle.name!
                                : vehicle.id,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _acceptingJobId == null ? _changeVehicle : null,
                  decoration: const InputDecoration(
                    labelText: 'Vehículo',
                  ),
                ),
                if (selectedVehicle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    selectedVehicle.onboardingComplete
                        ? 'Configuración Marketplace completa.'
                        : 'Este vehículo todavía tiene requisitos pendientes.',
                    style: TextStyle(
                      color: appMutedColor(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            GlassCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (_available.isEmpty)
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Column(
                  children: [
                    Icon(
                      Icons.work_outline_rounded,
                      size: 42,
                      color: appPrimaryColor(context),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No hay trabajos disponibles ahora',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Desliza hacia abajo para actualizar.',
                      style: TextStyle(
                        color: appMutedColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._available.map(
              (job) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AvailableJobCard(
                  job: job,
                  accepting: _acceptingJobId == job.id,
                  acceptanceLocked: _acceptingJobId != null,
                  onAccept: () => _acceptJob(job),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvailableJobCard extends StatelessWidget {
  const _AvailableJobCard({
    required this.job,
    required this.accepting,
    required this.acceptanceLocked,
    required this.onAccept,
  });

  final MarketplaceAvailableJob job;
  final bool accepting;
  final bool acceptanceLocked;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final origin =
        job.originText?.trim().isNotEmpty == true ? job.originText! : 'Origen';
    final destination = job.destinationText?.trim().isNotEmpty == true
        ? job.destinationText!
        : 'Destino';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _marketplaceJobServiceLabel(job.serviceCode),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                _marketplaceMoneyLabel(
                  job.finalPrice,
                  job.currency,
                ),
                style: TextStyle(
                  color: appPrimaryColor(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.trip_origin_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(origin)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(destination)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  job.scheduledFor == null
                      ? 'Solicitud para ahora'
                      : 'Programado: ${_marketplaceJobDateLabel(job.scheduledFor)}',
                ),
              ),
            ],
          ),
          if (job.passengerCount != null) ...[
            const SizedBox(height: 8),
            Text('${job.passengerCount} pasajero(s)'),
          ],
          if (job.cargoWeightKg != null) ...[
            const SizedBox(height: 8),
            Text(
              'Carga: ${job.cargoWeightKg!.toStringAsFixed(0)} kg',
            ),
          ],
          if (job.requiredBodyType?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text('Carrocería requerida: ${job.requiredBodyType}'),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: acceptanceLocked && !accepting ? null : onAccept,
              icon: accepting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                accepting ? 'Aceptando...' : 'Aceptar trabajo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketplaceJobsPlaceholder extends StatelessWidget {
  const _MarketplaceJobsPlaceholder({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 44,
                  color: appPrimaryColor(context),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: appMutedColor(context),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
