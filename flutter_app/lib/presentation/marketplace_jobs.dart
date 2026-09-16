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

String _marketplaceJobStatusLabel(String status) {
  return switch (status) {
    'accepted' => 'Aceptado',
    'en_route' => 'En camino',
    'pickup' => 'En recogida',
    'in_progress' => 'En curso',
    'completed' => 'Completado · pendiente de liquidación',
    'settled' => 'Liquidado',
    'cancelled_by_customer' => 'Cancelado por cliente',
    'cancelled_by_driver' => 'Cancelado por conductor',
    'incident' => 'Incidencia',
    _ => status,
  };
}

String _marketplaceJobBillingLabel(MarketplaceJob job) {
  switch (job.billingMode) {
    case MarketplaceBillingMode.trialFree:
      return 'Periodo gratuito · sin comisión';
    case MarketplaceBillingMode.walletCommission:
      final commission = job.commissionAmountSnapshot;
      if (commission == null) return 'Comisión por billetera';
      return 'Comisión: ${_marketplaceMoneyLabel(
        commission,
        job.currency,
      )}';
    case MarketplaceBillingMode.unknown:
      return 'Facturación pendiente';
  }
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
  List<MarketplaceJob> _active = const [];
  List<MarketplaceJob> _scheduled = const [];
  List<MarketplaceJob> _history = const [];

  final Set<String> _loadingScopes = <String>{};
  final Map<String, String> _scopeErrors = <String, String>{};

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

      await Future.wait([
        _loadScope('active'),
        _loadScope('scheduled'),
        _loadScope('history'),
      ]);
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

  Future<void> _loadScope(String scope) async {
    if (!mounted) return;

    setState(() {
      _loadingScopes.add(scope);
      _scopeErrors.remove(scope);
    });

    try {
      final jobs = await _service.jobs(scope);

      if (!mounted) return;

      setState(() {
        switch (scope) {
          case 'active':
            _active = jobs;
            break;
          case 'scheduled':
            _scheduled = jobs;
            break;
          case 'history':
            _history = jobs;
            break;
        }

        _loadingScopes.remove(scope);
        _scopeErrors.remove(scope);
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingScopes.remove(scope);
        _scopeErrors[scope] =
            'No se pudieron actualizar los trabajos de esta sección.';
      });
    }
  }

  List<MarketplaceJob> _jobsForScope(String scope) {
    return switch (scope) {
      'active' => _active,
      'scheduled' => _scheduled,
      'history' => _history,
      _ => const <MarketplaceJob>[],
    };
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

      await Future.wait([
        _loadAvailable(),
        _loadScope('active'),
        _loadScope('scheduled'),
      ]);

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
                _buildAssignedTab(
                  context,
                  scope: 'active',
                  icon: Icons.route_outlined,
                  emptyTitle: 'No tienes trabajos activos',
                  emptyMessage:
                      'Cuando aceptes un servicio para ahora aparecerá aquí.',
                ),
                _buildAssignedTab(
                  context,
                  scope: 'scheduled',
                  icon: Icons.event_outlined,
                  emptyTitle: 'No tienes trabajos programados',
                  emptyMessage:
                      'Los servicios aceptados para una hora futura aparecerán aquí.',
                ),
                _buildAssignedTab(
                  context,
                  scope: 'history',
                  icon: Icons.history_rounded,
                  emptyTitle: 'Tu historial está vacío',
                  emptyMessage:
                      'Aquí aparecerán los trabajos liquidados, cancelados o resueltos.',
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

  Widget _buildAssignedTab(
    BuildContext context, {
    required String scope,
    required IconData icon,
    required String emptyTitle,
    required String emptyMessage,
  }) {
    final jobs = _jobsForScope(scope);
    final loading = _loadingScopes.contains(scope);
    final error = _scopeErrors[scope];

    return RefreshIndicator(
      onRefresh: () => _loadScope(scope),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (loading && jobs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            if (error != null) ...[
              GlassCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded),
                    const SizedBox(width: 10),
                    Expanded(child: Text(error)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (jobs.isEmpty)
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        size: 42,
                        color: appPrimaryColor(context),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        emptyTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        emptyMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: appMutedColor(context),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...jobs.map(
                (job) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AssignedJobCard(job: job),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AssignedJobCard extends StatelessWidget {
  const _AssignedJobCard({
    required this.job,
  });

  final MarketplaceJob job;

  @override
  Widget build(BuildContext context) {
    final origin =
        job.originText?.trim().isNotEmpty == true ? job.originText! : 'Origen';
    final destination = job.destinationText?.trim().isNotEmpty == true
        ? job.destinationText!
        : 'Destino';

    final lastEvent = job.completedAt ??
        job.cancelledAt ??
        job.acceptedAt ??
        job.updatedAt ??
        job.createdAt;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(width: 10),
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
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: appMutedColor(context).withValues(alpha: 0.30),
              ),
            ),
            child: Text(
              _marketplaceJobStatusLabel(job.status),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
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
          if (job.scheduledFor != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.event_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Programado: ${_marketplaceJobDateLabel(job.scheduledFor)}',
                  ),
                ),
              ],
            ),
          ],
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
          const SizedBox(height: 12),
          Text(
            _marketplaceJobBillingLabel(job),
            style: TextStyle(
              color: appMutedColor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (lastEvent != null) ...[
            const SizedBox(height: 6),
            Text(
              'Actualizado: ${_marketplaceJobDateLabel(lastEvent)}',
              style: TextStyle(
                color: appMutedColor(context),
                fontSize: 12,
              ),
            ),
          ],
          if (job.incidentReason?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: kTertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Incidencia: ${job.incidentReason}',
                  ),
                ),
              ],
            ),
          ],
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
