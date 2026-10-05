part of '../main.dart';

String marketplaceAcceptErrorMessage(Object error) {
  final code = error.toString().toUpperCase();
  if (code.contains('INSUFFICIENT_MARKETPLACE_WALLET_BALANCE')) {
    return 'Saldo insuficiente para aceptar este trabajo. Recarga tu billetera y vuelve a intentarlo.';
  }
  if (code.contains('INCOMPLETE') || code.contains('PROFILE_NOT_COMPLETE')) {
    return 'Completa tu perfil de conductor y los requisitos del vehículo para aceptar trabajos.';
  }
  return 'No se pudo aceptar el trabajo. Puede que ya no esté disponible. Comprueba tu conexión y vuelve a intentarlo.';
}

final ValueNotifier<int> _marketplaceAvailableJobCount = ValueNotifier<int>(0);
final ValueNotifier<bool> _marketplaceJobsNeedAttention = ValueNotifier<bool>(
  false,
);
final ValueNotifier<bool> _marketplaceJobsVisible = ValueNotifier<bool>(false);
final ValueNotifier<bool> _marketplaceDriverProfileNeedsSetup =
    ValueNotifier<bool>(false);

bool marketplaceDriverOnboardingNeedsSetup(MarketplaceOnboarding data) =>
    !data.driverSuspended &&
    data.driverStatus != 'suspended' &&
    (!data.driverProfileExists ||
        data.displayName?.trim().isNotEmpty != true ||
        !RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(data.phone?.trim() ?? '') ||
        data.driverPhotoAssetId?.trim().isNotEmpty != true ||
        !data.vehicles.any((vehicle) => vehicle.onboardingComplete));

bool _marketplaceDriverNeedsSetup(MarketplaceOnboarding data) =>
    marketplaceDriverOnboardingNeedsSetup(data);

void _updateMarketplaceDriverProfileNeedsSetup(MarketplaceOnboarding? data) {
  _marketplaceDriverProfileNeedsSetup.value =
      data != null && _marketplaceDriverNeedsSetup(data);
}

void _setMarketplaceAvailableJobCount(int count) {
  marketplaceJobPushPending.value = false;
  final safeCount = count < 0 ? 0 : count;
  final previous = _marketplaceAvailableJobCount.value;

  _marketplaceAvailableJobCount.value = safeCount;

  if (safeCount == 0) {
    _marketplaceJobsNeedAttention.value = false;
    return;
  }

  if (safeCount > previous && !_marketplaceJobsVisible.value) {
    _marketplaceJobsNeedAttention.value = true;
  }
}

void _acknowledgeMarketplaceJobs() {
  _marketplaceJobsNeedAttention.value = false;
}

void _setMarketplaceJobsVisible(bool visible) {
  _marketplaceJobsVisible.value = visible;
  if (visible) {
    _acknowledgeMarketplaceJobs();
  }
}

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

Color _marketplaceJobStatusColor(BuildContext context, String status) {
  return switch (status) {
    'accepted' => Colors.orange,
    'en_route' => Colors.orange,
    'pickup' => Colors.orange,
    'in_progress' => Colors.orange,
    'completed' => Colors.green,
    'settled' => Colors.green,
    'cancelled_by_customer' => kDanger,
    'cancelled_by_driver' => kDanger,
    'incident' => Colors.redAccent,
    _ => appMutedColor(context),
  };
}

IconData _marketplaceJobStatusIcon(String status) {
  return switch (status) {
    'accepted' => Icons.check_circle_outline_rounded,
    'en_route' => Icons.navigation_rounded,
    'pickup' => Icons.person_pin_circle_rounded,
    'in_progress' => Icons.route_rounded,
    'completed' => Icons.task_alt_rounded,
    'settled' => Icons.task_alt_rounded,
    'cancelled_by_customer' => Icons.cancel_outlined,
    'cancelled_by_driver' => Icons.cancel_outlined,
    'incident' => Icons.warning_amber_rounded,
    _ => Icons.work_outline_rounded,
  };
}

String _marketplaceJobStatusMessage(String status) {
  return switch (status) {
    'accepted' => 'Servicio aceptado · prepárate para salir',
    'en_route' => 'Vas camino al punto de recogida',
    'pickup' => 'Estás en el punto de recogida',
    'in_progress' => 'Servicio en curso hacia el destino',
    'completed' => 'Servicio finalizado · pendiente de liquidación',
    'settled' => 'Servicio completado y liquidado',
    'cancelled_by_customer' => 'El cliente canceló este servicio',
    'cancelled_by_driver' => 'El conductor canceló este servicio',
    'incident' => 'Hay una incidencia abierta en este servicio',
    _ => 'Estado actual del servicio',
  };
}

int _marketplaceJobProgressIndex(String status) {
  return switch (status) {
    'accepted' => 0,
    'en_route' => 1,
    'pickup' => 2,
    'in_progress' => 3,
    'completed' => 4,
    'settled' => 4,
    _ => 0,
  };
}

String _marketplaceJobBillingLabel(MarketplaceJob job) {
  switch (job.billingMode) {
    case MarketplaceBillingMode.trialFree:
      return 'Promoción inicial · sin comisión';
    case MarketplaceBillingMode.walletCommission:
      final commission = job.commissionAmountSnapshot;
      if (commission == null) return 'Comisión por billetera';
      return 'Comisión: ${_marketplaceMoneyLabel(commission, job.currency)}';
    case MarketplaceBillingMode.unknown:
      return 'Facturación pendiente';
  }
}

String? _marketplaceJobActionLabel(String? action) {
  return switch (action) {
    'start_en_route' => 'Salir hacia el cliente',
    'mark_pickup' => 'Confirmar recogida',
    'start_service' => 'Iniciar servicio',
    'complete_service' => 'Completar servicio',
    _ => null,
  };
}

bool _marketplaceJobCanDriverCancel(MarketplaceJob job) {
  return job.status == 'accepted' ||
      job.status == 'en_route' ||
      job.status == 'pickup';
}

class MarketplaceOperationalLocationPolicy {
  static const availableSampleInterval = Duration(minutes: 2);
  static const availableHeartbeatInterval = Duration(minutes: 4);
  static const activeSampleInterval = Duration(seconds: 30);
  static const activeHeartbeatInterval = Duration(seconds: 75);

  static const availableDistanceMeters = 200.0;
  static const activeDistanceMeters = 50.0;

  static bool isActiveServiceStatus(String status) {
    return status == 'accepted' ||
        status == 'en_route' ||
        status == 'pickup' ||
        status == 'in_progress' ||
        status == 'incident';
  }

  static Duration sampleInterval({required bool activeService}) =>
      activeService ? activeSampleInterval : availableSampleInterval;

  static Duration heartbeatInterval({required bool activeService}) =>
      activeService ? activeHeartbeatInterval : availableHeartbeatInterval;

  static Duration failureRetryDelay({required bool activeService}) =>
      activeService ? const Duration(seconds: 60) : const Duration(minutes: 5);

  static double distanceThresholdMeters({required bool activeService}) =>
      activeService ? activeDistanceMeters : availableDistanceMeters;

  static LocationAccuracy accuracy({required bool activeService}) =>
      activeService ? LocationAccuracy.high : LocationAccuracy.medium;
}

class MarketplaceJobsScreen extends StatefulWidget {
  const MarketplaceJobsScreen({
    required this.store,
    this.service,
    this.isVisible = true,
    super.key,
  });

  final RecordStore store;
  final MarketplaceService? service;
  final bool isVisible;

  @override
  State<MarketplaceJobsScreen> createState() => _MarketplaceJobsScreenState();
}

class _MarketplaceJobsScreenState extends State<MarketplaceJobsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final MarketplaceService _service;
  late final TabController _tabController;

  MarketplaceOnboarding? _onboarding;
  String? _selectedVehicleId;
  List<MarketplaceAvailableJob> _available = const [];
  List<MarketplaceJob> _active = const [];
  List<MarketplaceJob> _scheduled = const [];
  List<MarketplaceJob> _history = const [];
  List<MarketplaceDriverRatingEntry> _ratings = const [];
  MarketplaceDriverRatingSummary? _ratingSummary;
  bool _loadingRatings = false;
  bool _ratingsLoaded = false;
  String? _ratingsError;

  final Set<String> _loadingScopes = <String>{};
  final Map<String, String> _scopeErrors = <String, String>{};

  bool _loading = true;
  String? _error;
  String? _acceptingJobId;
  String? _busyJobId;
  bool _updatingAvailability = false;
  MarketplaceWorkAccess? _workAccess;

  Timer? _operationalLocationTimer;
  bool _operationalLocationInFlight = false;
  AppLifecycleState _operationalLifecycleState = AppLifecycleState.resumed;
  Position? _lastOperationalPosition;
  DateTime? _lastOperationalSentAt;

  final Map<String, String> _acceptKeys = {};
  final Map<String, String> _operationKeys = {};
  final Map<String, MarketplaceCustomerContact> _contacts = {};
  final Map<String, MarketplaceJobCancellationDetail> _cancellationDetails = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onMarketplaceTabChanged);
    _service = widget.service ?? MarketplaceService(Supabase.instance.client);
    _operationalLifecycleState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    marketplaceJobRefreshRequests.addListener(_refreshAvailability);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  @override
  void didUpdateWidget(covariant MarketplaceJobsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.isVisible && widget.isVisible) {
      _syncOperationalLocationSampling(
        immediate: true,
        requestPermission: true,
      );
    }
  }

  @override
  void dispose() {
    _operationalLocationTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    marketplaceJobRefreshRequests.removeListener(_refreshAvailability);
    _tabController.removeListener(_onMarketplaceTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onMarketplaceTabChanged() {
    if (_tabController.index == 3 && !_tabController.indexIsChanging) {
      unawaited(_loadRatings(force: true));
    }
  }

  Future<void> _loadRatings({bool force = false}) async {
    if (_loadingRatings || (_ratingsLoaded && !force)) return;

    if (mounted) {
      setState(() {
        _loadingRatings = true;
        _ratingsError = null;
      });
    }

    try {
      final ratings = await _service.ratings();
      final summary = await _service.ratingSummary();

      if (!mounted) return;

      setState(() {
        _ratings = ratings;
        _ratingSummary = summary;
        _ratingsLoaded = true;
        _ratingsError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ratingsError =
            'No pudimos cargar tus evaluaciones. Inténtalo nuevamente.';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingRatings = false);
      }
    }
  }

  void _refreshAvailability() {
    if (marketplaceJobPushPending.value && !_marketplaceJobsVisible.value) {
      _marketplaceJobsNeedAttention.value = true;
    }
    unawaited(_load(refreshHistory: false));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _operationalLifecycleState = state;

    if (state == AppLifecycleState.resumed) {
      _refreshAvailability();
      _syncOperationalLocationSampling(
        immediate: true,
        requestPermission: widget.isVisible,
      );
    } else {
      _stopOperationalLocationSampling();
    }
  }

  // The wallet tab is recreated after activation so its totals are current.
  int _managementRevision = 0;

  void _onManagementChanged() {
    if (!mounted) return;
    setState(() => _managementRevision++);
    unawaited(_load());
  }

  MarketplaceVehicle? _vehicleById(String? id) {
    if (id == null) return null;

    for (final vehicle in _onboarding?.vehicles ?? const []) {
      if (vehicle.id == id) return vehicle;
    }

    return null;
  }

  bool _vehicleReadyForWork(MarketplaceVehicle? vehicle) {
    final access = _workAccess;

    return vehicle != null &&
        access != null &&
        access.onboardingComplete &&
        access.driverActive &&
        access.suiteActive &&
        vehicle.isActive &&
        vehicle.marketplaceStatus == 'active';
  }

  MarketplaceJob? _operationalActiveJob() {
    for (final job in _active) {
      if (MarketplaceOperationalLocationPolicy.isActiveServiceStatus(
        job.status,
      )) {
        return job;
      }
    }
    return null;
  }

  MarketplaceVehicle? _operationalLocationVehicle() {
    final activeJob = _operationalActiveJob();

    if (activeJob?.vehicleId != null) {
      final jobVehicle = _vehicleById(activeJob!.vehicleId);
      if (jobVehicle != null) return jobVehicle;
    }

    return _vehicleById(_selectedVehicleId);
  }

  bool _canPublishOperationalLocation() {
    if (widget.store.user == null ||
        _operationalLifecycleState != AppLifecycleState.resumed) {
      return false;
    }

    final onboarding = _onboarding;
    final vehicle = _operationalLocationVehicle();
    final activeJob = _operationalActiveJob();

    if (onboarding == null ||
        vehicle == null ||
        !onboarding.driverProfileExists ||
        onboarding.driverStatus != 'active' ||
        onboarding.driverSuspended ||
        !vehicle.isActive ||
        vehicle.marketplaceStatus != 'active') {
      return false;
    }

    return vehicle.acceptingJobs || activeJob != null;
  }

  void _stopOperationalLocationSampling() {
    _operationalLocationTimer?.cancel();
    _operationalLocationTimer = null;
  }

  void _scheduleNextOperationalLocationSample({Duration? overrideDelay}) {
    _stopOperationalLocationSampling();

    if (!_canPublishOperationalLocation()) return;

    final activeService = _operationalActiveJob() != null;
    final interval =
        overrideDelay ??
        MarketplaceOperationalLocationPolicy.sampleInterval(
          activeService: activeService,
        );

    _operationalLocationTimer = Timer(
      interval,
      () => unawaited(_sampleOperationalLocation()),
    );
  }

  void _syncOperationalLocationSampling({
    bool immediate = false,
    bool requestPermission = false,
  }) {
    if (!_canPublishOperationalLocation()) {
      _stopOperationalLocationSampling();
      return;
    }

    if (immediate && !_operationalLocationInFlight) {
      _stopOperationalLocationSampling();
      unawaited(
        _sampleOperationalLocation(requestPermission: requestPermission),
      );
      return;
    }

    if (_operationalLocationTimer == null) {
      _scheduleNextOperationalLocationSample();
    }
  }

  double? _safeOperationalMetric(
    double value, {
    required double min,
    required double max,
  }) {
    if (!value.isFinite || value < min || value > max) return null;
    return value;
  }

  bool _cachedPositionUsable(Position position, DateTime nowUtc) {
    final timestamp = position.timestamp.toUtc();
    final age = nowUtc.difference(timestamp);

    return !age.isNegative &&
        age <= const Duration(seconds: 90) &&
        position.accuracy.isFinite &&
        position.accuracy >= 0 &&
        position.accuracy <= 500;
  }

  Future<Position> _readOperationalPosition({
    required bool activeService,
  }) async {
    final nowUtc = DateTime.now().toUtc();

    if (!activeService) {
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null && _cachedPositionUsable(cached, nowUtc)) {
        return cached;
      }
    }

    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: MarketplaceOperationalLocationPolicy.accuracy(
          activeService: activeService,
        ),
        timeLimit: activeService
            ? const Duration(seconds: 10)
            : const Duration(seconds: 8),
      ),
    );
  }

  Future<void> _sampleOperationalLocation({
    bool requestPermission = false,
  }) async {
    if (_operationalLocationInFlight || !_canPublishOperationalLocation()) {
      return;
    }

    final vehicle = _operationalLocationVehicle();
    if (vehicle == null) return;

    final activeService = _operationalActiveJob() != null;
    var shouldReschedule = true;
    Duration? retryDelay;

    _operationalLocationInFlight = true;

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        shouldReschedule = false;
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied &&
          requestPermission &&
          widget.isVisible) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        shouldReschedule = false;
        return;
      }

      final position = await _readOperationalPosition(
        activeService: activeService,
      );

      if (!mounted || !_canPublishOperationalLocation()) return;

      final latitude = position.latitude;
      final longitude = position.longitude;

      if (!latitude.isFinite ||
          latitude < -90 ||
          latitude > 90 ||
          !longitude.isFinite ||
          longitude < -180 ||
          longitude > 180) {
        return;
      }

      final nowUtc = DateTime.now().toUtc();
      final lastPosition = _lastOperationalPosition;
      final lastSentAt = _lastOperationalSentAt;

      final distanceMeters = lastPosition == null
          ? double.infinity
          : Geolocator.distanceBetween(
              lastPosition.latitude,
              lastPosition.longitude,
              latitude,
              longitude,
            );

      final heartbeatDue =
          lastSentAt == null ||
          nowUtc.difference(lastSentAt) >=
              MarketplaceOperationalLocationPolicy.heartbeatInterval(
                activeService: activeService,
              );

      final movementDue =
          distanceMeters >=
          MarketplaceOperationalLocationPolicy.distanceThresholdMeters(
            activeService: activeService,
          );

      if (lastPosition == null || heartbeatDue || movementDue) {
        await _service.updateDriverOperationalLocation(
          vehicleId: vehicle.id,
          latitude: latitude,
          longitude: longitude,
          accuracyM: _safeOperationalMetric(
            position.accuracy,
            min: 0,
            max: 5000,
          ),
          headingDegrees: _safeOperationalMetric(
            position.heading,
            min: 0,
            max: 359.999,
          ),
          speedMps: _safeOperationalMetric(position.speed, min: 0, max: 100),
          capturedAt: position.timestamp,
        );

        _lastOperationalPosition = position;
        _lastOperationalSentAt = nowUtc;
      }
    } catch (_) {
      // Un fallo transitorio de GPS/red no debe detener el seguimiento.
      // Reintentamos con backoff para no castigar batería ni datos móviles.
      retryDelay = MarketplaceOperationalLocationPolicy.failureRetryDelay(
        activeService: activeService,
      );
    } finally {
      _operationalLocationInFlight = false;

      if (mounted && shouldReschedule && _canPublishOperationalLocation()) {
        _scheduleNextOperationalLocationSample(overrideDelay: retryDelay);
      }
    }
  }

  Future<void> _clearOperationalLocationBestEffort() async {
    _stopOperationalLocationSampling();
    _lastOperationalPosition = null;
    _lastOperationalSentAt = null;

    try {
      await _service.clearDriverOperationalLocation();
    } catch (_) {
      // La privacidad visual también está protegida por frescura en backend.
    }
  }

  Future<void> _loadWorkAccess(String? vehicleId) async {
    if (vehicleId == null) {
      if (!mounted) return;

      setState(() => _workAccess = null);
      return;
    }

    try {
      final access = await _service.access(vehicleId);

      if (!mounted || vehicleId != _selectedVehicleId) return;

      setState(() => _workAccess = access);
    } catch (_) {
      if (!mounted || vehicleId != _selectedVehicleId) return;

      setState(() => _workAccess = null);
    }
  }

  Future<void>? _loadRequest;
  bool _loadAgain = false;
  bool _reloadHistory = false;

  Future<void> _load({bool refreshHistory = true}) {
    _reloadHistory = _reloadHistory || refreshHistory;
    if (_loadRequest != null) {
      _loadAgain = true;
      return _loadRequest!;
    }
    return _loadRequest = _drainLoads().whenComplete(() {
      _loadRequest = null;
    });
  }

  Future<void> _drainLoads() async {
    do {
      _loadAgain = false;
      final refreshHistory = _reloadHistory;
      _reloadHistory = false;
      await _fetchLoad(refreshHistory: refreshHistory);
    } while (mounted && _loadAgain);
  }

  Future<void> _fetchLoad({required bool refreshHistory}) async {
    if (widget.store.user == null) {
      if (!mounted) return;

      _stopOperationalLocationSampling();
      _updateMarketplaceDriverProfileNeedsSetup(null);
      _setMarketplaceAvailableJobCount(0);

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
      final userId = widget.store.user?.id;
      final onboarding = await _service.onboarding();
      if (!mounted || widget.store.user?.id != userId) return;
      _updateMarketplaceDriverProfileNeedsSetup(onboarding);

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

      if (!mounted) return;

      setState(() {
        _onboarding = onboarding;
        _selectedVehicleId = vehicleId;
        _available = const [];
      });

      if (_marketplaceDriverNeedsSetup(onboarding)) {
        _stopOperationalLocationSampling();
        _setMarketplaceAvailableJobCount(0);
        setState(() => _loading = false);
        return;
      }
      await _loadWorkAccess(vehicleId);

      await Future.wait([
        _loadScope('active'),
        _loadScope('scheduled'),
        if (refreshHistory) _loadScope('history'),
      ]);

      if (!mounted) return;

      if (_scopeErrors.containsKey('active') ||
          _scopeErrors.containsKey('scheduled')) {
        throw StateError('Job availability could not be verified');
      }
      await _loadAvailable();

      if (mounted) {
        setState(() => _loading = false);
        _syncOperationalLocationSampling(
          immediate: true,
          requestPermission: widget.isVisible,
        );
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _available = const [];
        _error =
            'No pudimos cargar los trabajos. Comprueba tu conexión e inténtalo de nuevo.';
      });
      _setMarketplaceAvailableJobCount(0);
    }
  }

  Future<void>? _availableRequest;

  Future<void> _loadAvailable() =>
      _availableRequest ??= _fetchAvailable().whenComplete(() {
        _availableRequest = null;
      });

  Future<void> _fetchAvailable() async {
    if (_active.isNotEmpty || _scheduled.isNotEmpty) {
      if (!mounted) return;

      setState(() {
        _available = const [];
        _error = null;
      });

      _setMarketplaceAvailableJobCount(0);
      return;
    }

    final vehicleId = _selectedVehicleId;

    if (vehicleId == null) {
      if (!mounted) return;

      setState(() => _available = const []);
      _setMarketplaceAvailableJobCount(0);
      return;
    }

    final vehicle = _vehicleById(vehicleId);

    if (!_vehicleReadyForWork(vehicle) || vehicle?.isAvailable != true) {
      if (!mounted) return;

      setState(() {
        _available = const [];
        _error = null;
      });

      _setMarketplaceAvailableJobCount(0);
      return;
    }

    try {
      final jobs = await _service.available(vehicleId);

      if (!mounted || vehicleId != _selectedVehicleId) return;

      setState(() {
        _available = jobs;
        _error = null;
      });

      _setMarketplaceAvailableJobCount(jobs.length);
    } catch (_) {
      if (!mounted || vehicleId != _selectedVehicleId) return;

      setState(() {
        _available = const [];
        _error =
            'No pudimos actualizar los trabajos. Desliza hacia abajo para intentarlo de nuevo.';
      });
      _setMarketplaceAvailableJobCount(0);
    }
  }

  final Map<String, Future<void>> _scopeRequests = {};

  Future<void> _loadScope(String scope) =>
      _scopeRequests[scope] ??= _fetchScope(scope).whenComplete(() {
        _scopeRequests.remove(scope);
      });

  Future<void> _fetchScope(String scope) async {
    if (!mounted) return;

    setState(() {
      _loadingScopes.add(scope);
      _scopeErrors.remove(scope);
    });

    try {
      final jobs = await _service.jobs(scope);

      List<MarketplaceJobCancellationDetail> cancellationDetails = const [];

      if (scope == 'history') {
        final cancelledIds = jobs
            .where(
              (job) =>
                  job.status == 'cancelled_by_driver' ||
                  job.status == 'cancelled_by_customer',
            )
            .map((job) => job.id)
            .toList();

        if (cancelledIds.isNotEmpty) {
          try {
            cancellationDetails = await _service.cancellationDetails(
              cancelledIds,
            );
          } catch (_) {
            cancellationDetails = const [];
          }
        }
      }

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
            _cancellationDetails
              ..clear()
              ..addEntries(
                cancellationDetails.map(
                  (detail) => MapEntry(detail.jobId, detail),
                ),
              );
            break;
        }

        _loadingScopes.remove(scope);
        _scopeErrors.remove(scope);
      });

      if (scope == 'active') {
        _syncOperationalLocationSampling(
          immediate: true,
          requestPermission: widget.isVisible,
        );

        if (jobs.isEmpty && mounted && !_loading) {
          await _loadAvailable();
        }
      }
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
      _workAccess = null;
    });

    _setMarketplaceAvailableJobCount(0);

    await _loadWorkAccess(vehicleId);
    await _loadAvailable();

    _syncOperationalLocationSampling(
      immediate: true,
      requestPermission: widget.isVisible,
    );
  }

  Future<void> _setAcceptingJobs(bool acceptingJobs) async {
    final vehicle = _vehicleById(_selectedVehicleId);

    if (vehicle == null ||
        !_vehicleReadyForWork(vehicle) ||
        _updatingAvailability) {
      return;
    }

    setState(() => _updatingAvailability = true);

    try {
      final updated = await _service.setAcceptingJobs(
        vehicle.id,
        acceptingJobs,
      );

      if (!mounted) return;

      setState(() {
        _onboarding = updated;
        _error = null;

        if (!acceptingJobs) {
          _available = const [];
        }
      });

      await _loadWorkAccess(vehicle.id);

      if (!mounted) return;

      if (acceptingJobs) {
        _syncOperationalLocationSampling(
          immediate: true,
          requestPermission: true,
        );
        toast(
          context,
          'Estás trabajando. Ya puedes recibir nuevas solicitudes.',
        );

        await _loadAvailable();
      } else {
        _setMarketplaceAvailableJobCount(0);

        if (_operationalActiveJob() == null) {
          unawaited(_clearOperationalLocationBestEffort());
        } else {
          _syncOperationalLocationSampling(
            immediate: true,
            requestPermission: widget.isVisible,
          );
        }

        toast(context, 'Estás descansando. No recibirás nuevas solicitudes.');
      }
    } catch (_) {
      if (mounted) {
        toast(
          context,
          acceptingJobs
              ? 'No pudimos activar Trabajando. Inténtalo de nuevo.'
              : 'No pudimos activar Descansando. Inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingAvailability = false);
      }
    }
  }

  Future<void> _openActivation() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => Scaffold(
          appBar: AppBar(title: const Text('Activación de Trabajos')),
          body: MarketplaceOnboardingScreen(
            store: widget.store,
            managementSection: MarketplaceManagementSection.activation,
            initialVehicleId: _selectedVehicleId,
            onManagementChanged: _onManagementChanged,
          ),
        ),
      ),
    );

    if (!mounted) return;

    await _load();
  }

  Future<void> _acceptJob(MarketplaceAvailableJob job) async {
    final vehicleId = _selectedVehicleId;

    if (vehicleId == null || _acceptingJobId != null) return;

    setState(() => _acceptingJobId = job.id);

    final key = _acceptKeys[job.id] ?? _marketplaceUuidV4();
    _acceptKeys[job.id] = key;

    try {
      await _service.accept(job.id, vehicleId, key);

      _acceptKeys.remove(job.id);

      if (!mounted) return;

      setState(() {
        _available = const [];
        _error = null;
      });

      _setMarketplaceAvailableJobCount(0);

      await Future.wait([
        _loadScope('active'),
        _loadScope('scheduled'),
        _loadScope('history'),
      ]);

      if (!mounted) return;

      if (_scheduled.any((item) => item.id == job.id)) {
        _tabController.animateTo(1);
      }
    } catch (error) {
      if (mounted) {
        toast(context, marketplaceAcceptErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _acceptingJobId = null);
      }
    }
  }

  String _operationKey(String jobId, String action) {
    final mapKey = '$jobId:$action';
    final existing = _operationKeys[mapKey];
    if (existing != null) return existing;

    final created = _marketplaceUuidV4();
    _operationKeys[mapKey] = created;
    return created;
  }

  Future<void> _refreshAfterJobMutation() async {
    await _load();
  }

  Future<void> _showCustomerRatingSurvey(String jobId) async {
    final noteController = TextEditingController();
    final idempotencyKey = _marketplaceUuidV4();

    var stars = 0;
    var sending = false;
    String? error;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: .72),
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> submit() async {
                if (stars < 1 || stars > 5) {
                  setSheetState(
                    () => error = 'Selecciona entre 1 y 5 estrellas.',
                  );
                  return;
                }

                setSheetState(() {
                  sending = true;
                  error = null;
                });

                try {
                  final note = noteController.text.trim();

                  await _service.rateCustomer(
                    jobId: jobId,
                    stars: stars,
                    internalNote: note.isEmpty ? null : note,
                    idempotencyKey: idempotencyKey,
                  );

                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                } catch (_) {
                  if (!sheetContext.mounted) return;

                  setSheetState(() {
                    sending = false;
                    error =
                        'No pudimos guardar la evaluación. Inténtalo nuevamente.';
                  });
                }
              }

              return SafeArea(
                top: false,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    14,
                    20,
                    20 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                      bottom: Radius.circular(22),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Evalúa al cliente',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '¿Cómo fue tu experiencia durante este servicio?',
                          style: TextStyle(color: appMutedColor(context)),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            final value = index + 1;

                            return IconButton(
                              tooltip: '$value estrellas',
                              onPressed: sending
                                  ? null
                                  : () {
                                      setSheetState(() {
                                        stars = value;
                                        error = null;
                                      });
                                    },
                              iconSize: 38,
                              icon: Icon(
                                value <= stars
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: kTertiary,
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: noteController,
                          enabled: !sending,
                          maxLength: 1000,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Nota interna (opcional)',
                            helperText:
                                'Solo será visible para la gestión de TUKTUK.',
                            alignLabelWithHint: true,
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            error!,
                            style: const TextStyle(
                              color: kDanger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: sending ? null : submit,
                          icon: sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.star_rounded),
                          label: const Text('Enviar evaluación'),
                        ),
                        TextButton(
                          onPressed: sending
                              ? null
                              : () => Navigator.of(sheetContext).pop(),
                          child: const Text('Ahora no'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      noteController.dispose();
    }
  }

  Future<void> _advanceJob(MarketplaceJob job) async {
    final action = job.nextAction;
    final label = _marketplaceJobActionLabel(action);

    if (action == null || label == null || _busyJobId != null) return;

    var confirmed = true;

    if (action == 'complete_service') {
      confirmed =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Completar servicio'),
              content: const Text(
                'Confirma únicamente cuando el servicio haya terminado.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Volver'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Completar'),
                ),
              ],
            ),
          ) ??
          false;
    }

    if (!confirmed || !mounted) return;

    setState(() => _busyJobId = job.id);

    final keyName = '${job.id}:$action';
    final key = _operationKey(job.id, action);

    try {
      final updatedJob = await _service.advance(job.id, action, key);

      if (action == 'complete_service') {
        await widget.store.ensureMarketplaceJobIncome(
          jobId: updatedJob.id,
          amount: updatedJob.finalPrice,
          distanceKm: job.distanceKm,
          completedAt: updatedJob.completedAt ?? DateTime.now(),
        );

        if (mounted) {
          await _showCustomerRatingSurvey(updatedJob.id);
          _ratingsLoaded = false;
        }
      }

      _operationKeys.remove(keyName);

      if (!mounted) return;

      await _refreshAfterJobMutation();
    } catch (_) {
      if (!mounted) return;

      toast(
        context,
        'No se pudo actualizar el trabajo. Actualiza la sección '
        'y vuelve a intentarlo.',
      );
    } finally {
      if (mounted) {
        setState(() => _busyJobId = null);
      }
    }
  }

  Future<void> _cancelJob(MarketplaceJob job) async {
    if (_busyJobId != null || !_marketplaceJobCanDriverCancel(job)) return;

    const reasons = [
      'Cliente no se presentó',
      'Problema con el vehículo',
      'No puedo realizar el servicio',
      'Dirección o punto de recogida incorrecto',
      'Acuerdo con el cliente',
      'Otro',
    ];

    final otherController = TextEditingController();
    String? selectedReason;
    String? validationMessage;

    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .72),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isOther = selectedReason == 'Otro';

            return SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: EdgeInsets.fromLTRB(
                  20,
                  14,
                  20,
                  20 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                    bottom: Radius.circular(22),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Cancelar viaje',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Selecciona el motivo. Quedará registrado '
                        'en el historial del servicio.',
                        style: TextStyle(color: appMutedColor(context)),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Motivo de cancelación',
                        ),
                        items: reasons
                            .map(
                              (reason) => DropdownMenuItem(
                                value: reason,
                                child: Text(reason),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setSheetState(() {
                            selectedReason = value;
                            validationMessage = null;
                          });
                        },
                      ),
                      if (isOther) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: otherController,
                          maxLines: 3,
                          maxLength: 180,
                          decoration: const InputDecoration(
                            labelText: 'Explica el motivo',
                            alignLabelWithHint: true,
                          ),
                          onChanged: (_) {
                            if (validationMessage != null) {
                              setSheetState(() {
                                validationMessage = null;
                              });
                            }
                          },
                        ),
                      ],
                      if (validationMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          validationMessage!,
                          style: const TextStyle(
                            color: kDanger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              child: const Text('Volver'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: kDanger,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                final selected = selectedReason;

                                if (selected == null) {
                                  setSheetState(() {
                                    validationMessage = 'Selecciona el motivo.';
                                  });
                                  return;
                                }

                                final resolved = selected == 'Otro'
                                    ? otherController.text.trim()
                                    : selected;

                                if (resolved.isEmpty) {
                                  setSheetState(() {
                                    validationMessage =
                                        'Escribe el motivo de cancelación.';
                                  });
                                  return;
                                }

                                Navigator.of(sheetContext).pop(resolved);
                              },
                              child: const Text('Cancelar viaje'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    otherController.dispose();

    if (reason == null || reason.trim().isEmpty || !mounted) return;

    setState(() => _busyJobId = job.id);

    final keyName = '${job.id}:cancel';
    final key = _operationKey(job.id, 'cancel');

    try {
      await _service.cancel(job.id, reason.trim(), key);

      _operationKeys.remove(keyName);

      if (!mounted) return;

      await _refreshAfterJobMutation();
    } catch (_) {
      if (!mounted) return;

      toast(
        context,
        'No se pudo cancelar el trabajo. Actualiza la sección '
        'y vuelve a intentarlo.',
      );
    } finally {
      if (mounted) {
        setState(() => _busyJobId = null);
      }
    }
  }

  Future<void> _contactJob(MarketplaceJob job) async {
    if (_busyJobId != null) return;

    setState(() => _busyJobId = job.id);

    try {
      final contact = _contacts[job.id] ?? await _service.contact(job.id);

      _contacts[job.id] = contact;

      if (!mounted) return;

      setState(() => _busyJobId = null);

      await _showContactSheet(contact);
    } catch (_) {
      if (!mounted) return;

      toast(context, 'No se pudo consultar el contacto del cliente.');
    } finally {
      if (mounted && _busyJobId == job.id) {
        setState(() => _busyJobId = null);
      }
    }
  }

  Future<void> _showContactSheet(MarketplaceCustomerContact contact) {
    final name = contact.name?.trim().isNotEmpty == true
        ? contact.name!
        : 'Cliente';
    final phone = contact.phone?.trim();
    final initial = name.isEmpty ? 'C' : name.substring(0, 1).toUpperCase();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;

        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
                bottom: Radius.circular(22),
              ),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.60),
              ),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 28,
                  offset: Offset(0, -6),
                  color: Color(0x55000000),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: appPrimaryColor(
                          sheetContext,
                        ).withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: appPrimaryColor(
                            sheetContext,
                          ).withValues(alpha: 0.45),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: appPrimaryColor(sheetContext),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Cliente del servicio',
                            style: TextStyle(
                              color: appMutedColor(sheetContext),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            phone?.isNotEmpty == true
                                ? phone!
                                : 'Teléfono no disponible',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (phone?.isNotEmpty == true) ...[
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              unawaited(_openWhatsApp(phone!));
                            },
                            icon: const FaIcon(
                              FontAwesomeIcons.whatsapp,
                              size: 22,
                            ),
                            label: const Text(
                              'WhatsApp',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.primaryContainer,
                              foregroundColor: colors.onPrimaryContainer,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              unawaited(_callPhone(phone!));
                            },
                            icon: const Icon(Icons.call_rounded),
                            label: const Text(
                              'Llamar',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      unawaited(Clipboard.setData(ClipboardData(text: phone!)));
                      toast(context, 'Número copiado.');
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copiar número'),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: 0.42,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 17,
                        color: appMutedColor(sheetContext),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'El contacto se muestra únicamente mientras '
                          'el servicio está asignado a tu cuenta.',
                          style: TextStyle(
                            color: appMutedColor(sheetContext),
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openWhatsApp(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      toast(context, 'El número del cliente no es válido.');
      return;
    }

    final opened = await launchUrl(
      Uri.parse('https://wa.me/$digits'),
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      toast(context, 'No se pudo abrir WhatsApp.');
    }
  }

  Future<void> _callPhone(String phone) async {
    final number = phone.replaceAll(RegExp(r'[^0-9+]'), '');

    if (number.isEmpty) {
      toast(context, 'El número del cliente no es válido.');
      return;
    }

    final opened = await launchUrl(
      Uri(scheme: 'tel', path: number),
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      toast(context, 'No se pudo abrir el marcador.');
    }
  }

  Widget _buildVehicleAvailabilityCard(BuildContext context) {
    final onboarding = _onboarding;

    if (onboarding == null || onboarding.vehicles.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedVehicle = _vehicleById(_selectedVehicleId);

    if (selectedVehicle == null) {
      return const SizedBox.shrink();
    }

    final vehicleReady = _vehicleReadyForWork(selectedVehicle);
    final acceptingJobs = selectedVehicle.acceptingJobs;

    final vehicleName = selectedVehicle.name?.trim().isNotEmpty == true
        ? selectedVehicle.name!.trim()
        : selectedVehicle.id;

    final restingColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF95A4B8)
        : const Color(0xFF56677C);
    final statusColor = acceptingJobs ? appPrimaryColor(context) : restingColor;
    final statusTitle = acceptingJobs ? 'En servicio' : 'Descansando';
    final statusMessage = acceptingJobs
        ? 'Recibiendo nuevas solicitudes'
        : 'No recibirás nuevos trabajos';
    final statusIcon = acceptingJobs
        ? Icons.wifi_tethering_rounded
        : Icons.pause_rounded;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: appPrimaryColor(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.directions_car_filled_rounded,
                  color: appPrimaryColor(context),
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehículo activo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: appMutedColor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vehicleName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (vehicleReady) ...[
                const SizedBox(width: 10),
                Semantics(
                  label: acceptingJobs
                      ? 'Desactivar disponibilidad'
                      : 'Activar disponibilidad',
                  child: Container(
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Switch.adaptive(
                      key: const ValueKey('marketplace-availability-switch'),
                      value: acceptingJobs,
                      onChanged: _updatingAvailability
                          ? null
                          : (value) {
                              unawaited(_setAcceptingJobs(value));
                            },
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          if (vehicleReady)
            AnimatedContainer(
              key: const ValueKey('marketplace-availability-status'),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withValues(alpha: 0.26)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, size: 18, color: statusColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Text(
                            statusTitle,
                            key: ValueKey(statusTitle),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusMessage,
                          style: TextStyle(
                            color: appMutedColor(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _openActivation,
                icon: const Icon(Icons.verified_user_outlined, size: 17),
                label: const Text('Activar'),
              ),
            ),
          if (onboarding.vehicles.length > 1) ...[
            const SizedBox(height: 12),
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
              onChanged: _acceptingJobId == null && !_updatingAvailability
                  ? _changeVehicle
                  : null,
              decoration: InputDecoration(
                labelText: 'Cambiar vehículo',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
          if (!vehicleReady) ...[
            const SizedBox(height: 8),
            Text(
              'Completa la activación para poder recibir solicitudes.',
              style: TextStyle(color: appMutedColor(context), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingStars(int? stars, {double size = 20}) {
    if (stars == null) {
      return Text(
        'Pendiente',
        style: TextStyle(
          color: appMutedColor(context),
          fontWeight: FontWeight.w700,
        ),
      );
    }

    final safeStars = stars.clamp(1, 5);

    return Semantics(
      label: '$safeStars de 5 estrellas',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          5,
          (index) => Icon(
            index < safeStars ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: kTertiary,
          ),
        ),
      ),
    );
  }

  Widget _buildRatingsTab(BuildContext context) {
    if (!_ratingsLoaded && _loadingRatings) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_ratingsLoaded && _ratingsError == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final summary = _ratingSummary;
    final averageStars = summary?.averageStars;
    final rankText = summary == null
        ? 'Ranking no disponible'
        : summary.rankingEligible && summary.rankPosition != null
        ? 'Ranking #${summary.rankPosition} de ${summary.rankedDriverCount}'
        : 'Ranking disponible desde ${summary.minimumRatings} evaluaciones';

    return RefreshIndicator(
      onRefresh: () => _loadRatings(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_ratingsError != null)
            GlassCard(
              child: Column(
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 40),
                  const SizedBox(height: 10),
                  Text(_ratingsError!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _loadRatings(force: true),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          else ...[
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mi valoración',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  if (averageStars != null) ...[
                    Row(
                      children: [
                        Text(
                          averageStars.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildRatingStars(averageStars.round(), size: 25),
                      ],
                    ),
                  ] else
                    Text(
                      'Aún no tienes evaluaciones',
                      style: TextStyle(
                        color: appMutedColor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    '${summary?.ratingCount ?? 0} evaluaciones',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rankText,
                    style: TextStyle(
                      color: appMutedColor(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_ratings.isEmpty)
              const GlassCard(
                child: Column(
                  children: [
                    Icon(Icons.star_outline_rounded, size: 42),
                    SizedBox(height: 12),
                    Text(
                      'Todavía no tienes evaluaciones por carrera',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._ratings.map(
                (rating) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _marketplaceJobServiceLabel(rating.serviceCode),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (rating.isTest)
                              const Text(
                                'Prueba',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                          ],
                        ),
                        if (rating.serviceDate != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _marketplaceJobDateLabel(rating.serviceDate),
                            style: TextStyle(
                              color: appMutedColor(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Cliente → Tú',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            _buildRatingStars(rating.receivedStars),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Tú → Cliente',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            _buildRatingStars(rating.givenStars),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceTab(BuildContext context) {
    final Widget content;

    if (_active.isNotEmpty) {
      content = _buildAssignedTab(
        context,
        scope: 'active',
        icon: Icons.route_outlined,
        emptyTitle: 'No tienes servicios activos',
        emptyMessage: 'Las nuevas solicitudes aparecerán aquí.',
      );
    } else if (_scheduled.isNotEmpty) {
      content = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Column(
              children: [
                const Icon(
                  Icons.event_available_outlined,
                  size: 42,
                  color: Colors.blue,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tienes un servicio programado',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'Consulta los detalles en Agenda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: appMutedColor(context)),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      content = _buildAvailableTab(context);
    }

    final onboarding = _onboarding;
    final showVehicleControl =
        !_loading &&
        _active.isEmpty &&
        onboarding != null &&
        onboarding.vehicles.isNotEmpty;

    return Column(
      children: [
        if (showVehicleControl)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _buildVehicleAvailabilityCard(context),
          ),
        Expanded(child: content),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // La UI de Trabajos permanece viva al cambiar de sección. Si el conductor
    // ya autorizó ubicación, el muestreo operativo puede continuar únicamente
    // mientras la app esté en primer plano; nunca se solicita permiso oculto.
    if (!widget.isVisible) return const SizedBox.shrink();
    if (_loading && _onboarding == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final onboarding = _onboarding;
    if (onboarding == null) return _buildAvailableTab(context);
    if (_marketplaceDriverNeedsSetup(onboarding)) {
      return MarketplaceOnboardingScreen(
        store: widget.store,
        onManagementChanged: _onManagementChanged,
      );
    }
    return Column(
      children: [
        const SizedBox(height: 8),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.route_outlined), text: 'Servicio'),
            Tab(icon: Icon(Icons.event_outlined), text: 'Agenda'),
            Tab(icon: Icon(Icons.history), text: 'Hist.'),
            Tab(icon: Icon(Icons.star_outline_rounded), text: 'Evaluaciones'),
            Tab(
              icon: Icon(Icons.account_balance_wallet_outlined),
              text: 'Saldo',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildServiceTab(context),
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
              _buildRatingsTab(context),
              MarketplaceOnboardingScreen(
                key: ValueKey(
                  'wallet-$_selectedVehicleId-$_managementRevision',
                ),
                store: widget.store,
                managementSection: MarketplaceManagementSection.wallet,
                initialVehicleId: _selectedVehicleId,
              ),
            ],
          ),
        ),
      ],
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

    final vehicleReady = _vehicleReadyForWork(selectedVehicle);
    final acceptingJobs = selectedVehicle?.acceptingJobs == true;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (vehicleReady && !acceptingJobs) ...[
            const SizedBox(height: 12),
            GlassCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: appMutedColor(context).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.bedtime_outlined,
                      color: appMutedColor(context),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Estás descansando. Activa Trabajando cuando quieras '
                        'recibir nuevas solicitudes.',
                        style: TextStyle(
                          color: appMutedColor(context),
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_error != null) ...[
            const SizedBox(height: 12),
            GlassCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (vehicleReady &&
              acceptingJobs &&
              _error == null &&
              _available.isEmpty)
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 8,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.work_outline_rounded,
                      size: 38,
                      color: appPrimaryColor(context),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No hay trabajos disponibles',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Cuando aparezca una nueva solicitud, la verás aquí.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: appMutedColor(context),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (vehicleReady && acceptingJobs && _available.isNotEmpty)
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
              child: Center(child: CircularProgressIndicator()),
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
                      Icon(icon, size: 42, color: appPrimaryColor(context)),
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
                  child: _AssignedJobCard(
                    job: job,
                    scope: scope,
                    cancellationDetail: _cancellationDetails[job.id],
                    busy: _busyJobId == job.id,
                    showMap: scope == 'active',
                    onContact: scope == 'history'
                        ? null
                        : () => _contactJob(job),
                    onAdvance:
                        scope == 'active' &&
                            _marketplaceJobActionLabel(job.nextAction) != null
                        ? () => _advanceJob(job)
                        : null,
                    onCancel:
                        scope != 'history' &&
                            _marketplaceJobCanDriverCancel(job)
                        ? () => _cancelJob(job)
                        : null,
                  ),
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
    required this.scope,
    required this.busy,
    required this.showMap,
    this.cancellationDetail,
    this.onContact,
    this.onAdvance,
    this.onCancel,
  });

  final MarketplaceJob job;
  final String scope;
  final bool busy;
  final bool showMap;
  final MarketplaceJobCancellationDetail? cancellationDetail;
  final VoidCallback? onContact;
  final VoidCallback? onAdvance;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final origin = job.originText?.trim().isNotEmpty == true
        ? job.originText!
        : 'Origen';

    final destination = job.destinationText?.trim().isNotEmpty == true
        ? job.destinationText!
        : 'Destino';

    final cancelled =
        job.status == 'cancelled_by_driver' ||
        job.status == 'cancelled_by_customer';

    final completed = job.status == 'completed' || job.status == 'settled';

    final executing =
        job.status == 'accepted' ||
        job.status == 'en_route' ||
        job.status == 'pickup' ||
        job.status == 'in_progress';

    final statusColor = scope == 'scheduled'
        ? Colors.blue
        : cancelled
        ? kDanger
        : completed
        ? Colors.green
        : executing
        ? Colors.orange
        : _marketplaceJobStatusColor(context, job.status);

    final statusLabel = cancelled
        ? cancellationDetail?.cancelledBy == 'customer'
              ? 'Cancelado por el cliente'
              : cancellationDetail?.cancelledBy == 'driver'
              ? 'Cancelado por el conductor'
              : _marketplaceJobStatusLabel(job.status)
        : _marketplaceJobStatusLabel(job.status);

    final lastEvent =
        cancellationDetail?.cancelledAt ??
        job.completedAt ??
        job.cancelledAt ??
        job.acceptedAt ??
        job.updatedAt ??
        job.createdAt;

    final progressIndex = _marketplaceJobProgressIndex(job.status);

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
                _marketplaceMoneyLabel(job.finalPrice, job.currency),
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
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: statusColor.withValues(alpha: .60),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _marketplaceJobStatusIcon(job.status),
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _marketplaceJobStatusMessage(job.status),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (onAdvance != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : onAdvance,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_marketplaceJobStatusIcon(job.status)),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    _marketplaceJobActionLabel(job.nextAction) ?? 'Continuar',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ],
          if (onContact != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onContact,
                icon: const Icon(Icons.contact_phone_rounded),
                label: const Text(
                  'Contactar cliente',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
          if (scope != 'history' && job.status != 'incident') ...[
            const SizedBox(height: 14),
            Row(
              children: List.generate(4, (index) {
                const labels = [
                  'Aceptado',
                  'En camino',
                  'Recogida',
                  'Servicio',
                ];

                final active = progressIndex >= index;

                return Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: active
                              ? statusColor
                              : appMutedColor(context).withValues(alpha: .15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          active ? Icons.check_rounded : Icons.circle_outlined,
                          size: 14,
                          color: active ? Colors.white : appMutedColor(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labels[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: active
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: active ? statusColor : appMutedColor(context),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
          const SizedBox(height: 14),
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
          if (showMap &&
              job.status != 'completed' &&
              job.originPoint != null &&
              job.destinationPoint != null) ...[
            const SizedBox(height: 14),
            SizedBox(height: 265, child: MarketplaceDriverMap(job: job)),
          ],
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
            Text('Carga: ${job.cargoWeightKg!.toStringAsFixed(0)} kg'),
          ],
          const SizedBox(height: 12),
          Text(
            _marketplaceJobBillingLabel(job),
            style: TextStyle(
              color: appMutedColor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (cancelled) ...[
            const SizedBox(height: 10),
            Text(
              cancellationDetail?.cancellationReason?.trim().isNotEmpty == true
                  ? 'Motivo: ${cancellationDetail!.cancellationReason}'
                  : 'Motivo no disponible',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (cancellationDetail?.cancelledAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Fecha: ${_marketplaceJobDateLabel(cancellationDetail!.cancelledAt)}',
                style: TextStyle(color: appMutedColor(context), fontSize: 12),
              ),
            ],
          ] else if (lastEvent != null) ...[
            const SizedBox(height: 6),
            Text(
              'Actualizado: ${_marketplaceJobDateLabel(lastEvent)}',
              style: TextStyle(color: appMutedColor(context), fontSize: 12),
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
                Expanded(child: Text('Incidencia: ${job.incidentReason}')),
              ],
            ),
          ],
          if (onCancel != null) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : onCancel,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancelar'),
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
    final origin = job.originText?.trim().isNotEmpty == true
        ? job.originText!
        : 'Origen';
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
                _marketplaceMoneyLabel(job.finalPrice, job.currency),
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
            Text('Carga: ${job.cargoWeightKg!.toStringAsFixed(0)} kg'),
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(accepting ? 'Aceptando...' : 'Aceptar trabajo'),
            ),
          ),
        ],
      ),
    );
  }
}
