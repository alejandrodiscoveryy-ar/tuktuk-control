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

const _marketplaceFloatingSettingKey =
    'marketplace_floating_button_enabled_v1';

final ValueNotifier<bool> _marketplaceDriverWorking =
    ValueNotifier<bool>(false);

bool get _marketplaceFloatingPreference =>
    AndroidFloatingButtonBridge.supported &&
    Hive.isBoxOpen(_metaBox) &&
    Hive.box(_metaBox).get(_marketplaceFloatingSettingKey) == true;

Future<void> _syncMarketplaceFloatingShortcut() async {
  if (!AndroidFloatingButtonBridge.supported) return;

  final show = _marketplaceFloatingPreference &&
      _marketplaceDriverWorking.value;

  final count = marketplaceJobPushPending.value
      ? max(1, _marketplaceAvailableJobCount.value)
      : _marketplaceAvailableJobCount.value;

  await AndroidFloatingButtonBridge.setVisible(
    visible: show,
    count: count,
    attention: marketplaceJobPushPending.value ||
        _marketplaceJobsNeedAttention.value,
  );
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

bool _marketplaceJobStartsNow(MarketplaceAvailableJob job) =>
    job.scheduledFor?.isAfter(DateTime.now()) != true;

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
  // Visual progress uses two milestones; legacy backend states remain valid.
  return switch (status) {
    'accepted' => -1,
    'en_route' => 0,
    'pickup' => 0,
    'in_progress' => 0,
    'completed' => 1,
    'settled' => 1,
    _ => -1,
  };
}

String _marketplaceJobBillingLabel(MarketplaceJob job) {
  switch (job.billingMode) {
    case MarketplaceBillingMode.trialFree:
      return 'Promoción inicial · sin comisión';
    case MarketplaceBillingMode.platformFree:
      return 'Plataforma sin comisiones · 0 CUP';
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

bool _marketplaceJobCanFinish(MarketplaceJob job) =>
    job.status == 'en_route' ||
    job.status == 'pickup' ||
    job.status == 'in_progress';

bool _marketplaceJobCanDriverCancel(MarketplaceJob job) {
  return job.status == 'accepted' ||
      job.status == 'en_route' ||
      job.status == 'pickup';
}

class MarketplaceOperationalLocationPolicy {
  static const availableSampleInterval = Duration(minutes: 2);
  static const availableHeartbeatInterval = Duration(minutes: 4);
  static const activeSampleInterval = Duration(seconds: 15);
  static const activeHeartbeatInterval = Duration(seconds: 30);

  static const availableDistanceMeters = 200.0;
  static const activeDistanceMeters = 15.0;

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
      activeService ? const Duration(seconds: 30) : const Duration(minutes: 5);

  static double distanceThresholdMeters({required bool activeService}) =>
      activeService ? activeDistanceMeters : availableDistanceMeters;

  static bool shouldReadLastKnownPosition({
    required bool activeService,
    required bool isWeb,
  }) => !activeService && !isWeb;

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
  int _workPanelIndex = -1;
  bool _workDrawerOpen = false;
  bool _workRideDetailsExpanded = false;
  MarketplaceMapVisualConfiguration? _workMapVisual;
  LatLng? _workMapPosition;
  double _workMapZoom = 13.5;
  bool _workMapFallback = false;

  MarketplaceOnboarding? _onboarding;
  String? _selectedVehicleId;
  List<MarketplaceAvailableJob> _available = const [];
  List<MarketplaceJob> _active = const [];
  List<MarketplaceJob> _scheduled = const [];
  List<MarketplaceJob> _history = const [];
  bool _historyHasMore = false;
  bool _loadingMoreHistory = false;
  String? _historyMoreError;
  List<MarketplaceDriverRatingEntry> _ratings = const [];
  MarketplaceDriverRatingSummary? _ratingSummary;
  bool _loadingRatings = false;
  bool _ratingsLoaded = false;
  String? _ratingsError;

  final Set<String> _loadingScopes = <String>{};
  final Map<String, String> _scopeErrors = <String, String>{};

  bool _loading = true;
  String? _error;
  String? _incomeError;
  String? _acceptingJobId;
  String? _busyJobId;
  bool _updatingAvailability = false;
  bool _floatingOptedIn = false;
  bool _requestingFloatingPermission = false;
  bool _webAlertVerified = false;
  MarketplaceWorkAccess? _workAccess;

  Timer? _operationalLocationTimer;
  StreamSubscription<Position>? _activeOperationalLocationSubscription;
  bool _activeOperationalLocationPublishInFlight = false;
  bool _operationalLocationInFlight = false;
  AppLifecycleState _operationalLifecycleState = AppLifecycleState.resumed;
  Position? _lastOperationalPosition;
  DateTime? _lastOperationalSentAt;

  final Map<String, String> _acceptKeys = {};
  final Map<String, String> _operationKeys = {};
  final Set<String> _ratedHistoryJobs = {};
  final Map<String, MarketplaceCustomerContact> _contacts = {};
  final Map<String, MarketplaceJobCancellationDetail> _cancellationDetails = {};

  @override
  void initState() {
    super.initState();
    _floatingOptedIn = _marketplaceFloatingPreference;
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onMarketplaceTabChanged);
    _service = widget.service ?? MarketplaceService(Supabase.instance.client);
    unawaited(_prepareWorkMap());
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
    _activeOperationalLocationSubscription?.cancel();
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
    if (marketplaceJobPushPending.value) {
      if (!_marketplaceJobsVisible.value) {
        _marketplaceJobsNeedAttention.value = true;
      }
      if (mounted && (_workPanelIndex != -1 || _workDrawerOpen)) {
        setState(() {
          _workPanelIndex = -1;
          _workDrawerOpen = false;
        });
      }
    }
    unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _operationalLifecycleState = state;

    if (state == AppLifecycleState.resumed) {
      if (_requestingFloatingPermission) {
        _requestingFloatingPermission = false;
        unawaited(_completeFloatingPermissionRequest());
      } else {
        unawaited(_syncMarketplaceFloatingShortcut());
      }
    }

    if (state == AppLifecycleState.resumed) {
      _refreshAvailability();
      _syncOperationalLocationSampling(
        immediate: true,
        requestPermission: widget.isVisible,
      );
    } else if (_operationalActiveJob() == null) {
      _stopOperationalLocationSampling();
    } else {
      _operationalLocationTimer?.cancel();
      _operationalLocationTimer = null;
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
    if (widget.store.user == null) return false;

    final onboarding = _onboarding;
    final vehicle = _operationalLocationVehicle();
    final activeJob = _operationalActiveJob();

    if (_operationalLifecycleState != AppLifecycleState.resumed &&
        activeJob == null) {
      return false;
    }

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
    _activeOperationalLocationSubscription?.cancel();
    _activeOperationalLocationSubscription = null;
  }

  LocationSettings _activeOperationalLocationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 15),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'TUKTUK · servicio activo',
          notificationText:
              'Compartiendo tu ubicación durante el servicio en curso.',
          notificationChannelName: 'Servicio activo TUKTUK',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
  }

  Future<void> _publishActiveOperationalPosition(Position position) async {
    if (_activeOperationalLocationPublishInFlight ||
        !_canPublishOperationalLocation() ||
        _operationalActiveJob() == null) {
      return;
    }

    final vehicle = _operationalLocationVehicle();
    if (vehicle == null) return;

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

    _activeOperationalLocationPublishInFlight = true;
    try {
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
                activeService: true,
              );
      final movementDue =
          distanceMeters >=
          MarketplaceOperationalLocationPolicy.distanceThresholdMeters(
            activeService: true,
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
      // El stream permanece vivo y vuelve a intentar con la siguiente posición.
    } finally {
      _activeOperationalLocationPublishInFlight = false;
    }
  }

  Future<void> _ensureActiveOperationalLocationStream({
    bool requestPermission = false,
  }) async {
    if (_activeOperationalLocationSubscription != null ||
        !_canPublishOperationalLocation() ||
        _operationalActiveJob() == null) {
      return;
    }

    if (!await Geolocator.isLocationServiceEnabled()) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied &&
        requestPermission &&
        widget.isVisible) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    if (!_canPublishOperationalLocation() || _operationalActiveJob() == null) {
      return;
    }

    final stream = Geolocator.getPositionStream(
      locationSettings: _activeOperationalLocationSettings(),
    );

    _activeOperationalLocationSubscription = stream.listen(
      (position) => unawaited(_publishActiveOperationalPosition(position)),
      onError: (_) {
        final subscription = _activeOperationalLocationSubscription;
        _activeOperationalLocationSubscription = null;
        subscription?.cancel();

        if (mounted &&
            _operationalActiveJob() != null &&
            _canPublishOperationalLocation()) {
          _operationalLocationTimer?.cancel();
          _operationalLocationTimer = Timer(
            MarketplaceOperationalLocationPolicy.failureRetryDelay(
              activeService: true,
            ),
            () {
              _operationalLocationTimer = null;
              _syncOperationalLocationSampling();
            },
          );
        }
      },
      onDone: () {
        _activeOperationalLocationSubscription = null;
      },
    );
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

    if (_operationalActiveJob() != null) {
      _operationalLocationTimer?.cancel();
      _operationalLocationTimer = null;
      unawaited(
        _ensureActiveOperationalLocationStream(
          requestPermission: requestPermission,
        ),
      );
      return;
    }

    if (_activeOperationalLocationSubscription != null) {
      _activeOperationalLocationSubscription?.cancel();
      _activeOperationalLocationSubscription = null;
    }

    if (immediate && !_operationalLocationInFlight) {
      _operationalLocationTimer?.cancel();
      _operationalLocationTimer = null;
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

    if (MarketplaceOperationalLocationPolicy.shouldReadLastKnownPosition(
      activeService: activeService,
      isWeb: kIsWeb,
    )) {
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

        // Una consulta iniciada antes del nuevo GPS puede devolver cero
        // ofertas. Al publicar correctamente la ubicacion, reconsultar
        // tras la peticion anterior sin cambiar las reglas del backend.
        if (!activeService) {
          final previousAvailableRequest = _availableRequest;
          if (previousAvailableRequest != null) {
            await previousAvailableRequest;
          }
          if (mounted &&
              _selectedVehicleId == vehicle.id &&
              _canPublishOperationalLocation()) {
            await _loadAvailable();
          }
        }
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
      configureMarketplaceWebJobAlerts(false);
      _marketplaceDriverWorking.value = false;

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

      // Dar prioridad al vehiculo verdaderamente habilitado para carreras.
      // No seleccionar un borrador si ya hay otro vehiculo operativo.
      final vehicleId = marketplaceSingleOperationalVehicle(
        onboarding.vehicles,
        preferredId: _selectedVehicleId ?? widget.store.activeVehicle?.id,
      )?.id;

      if (!mounted) return;

      setState(() {
        _onboarding = onboarding;
        _selectedVehicleId = vehicleId;
        _available = const [];
      });

      if (_marketplaceDriverNeedsSetup(onboarding)) {
        _marketplaceDriverWorking.value = false;
        _stopOperationalLocationSampling();
        _setMarketplaceAvailableJobCount(0);
        setState(() => _loading = false);
        return;
      }
      await _loadWorkAccess(vehicleId);

      final workingVehicle = _vehicleById(vehicleId);
      _marketplaceDriverWorking.value =
          _vehicleReadyForWork(workingVehicle) &&
          workingVehicle?.acceptingJobs == true;

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
      unawaited(_refreshIncome());

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
      configureMarketplaceWebJobAlerts(false);
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
      configureMarketplaceWebJobAlerts(false);

      setState(() => _available = const []);
      _setMarketplaceAvailableJobCount(0);
      return;
    }

    final vehicle = _vehicleById(vehicleId);
    configureMarketplaceWebJobAlerts(
      _vehicleReadyForWork(vehicle) &&
          vehicle?.isAvailable == true &&
          vehicle?.acceptingJobs == true,
    );

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
    final requestUserId = widget.store.user?.id;

    setState(() {
      _loadingScopes.add(scope);
      _scopeErrors.remove(scope);
    });

    try {
      final jobs = await _service.jobs(scope);
      if (widget.store.user?.id != requestUserId) return;

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
            _historyHasMore = jobs.length == 50;
            _historyMoreError = null;
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

  Future<void> _loadMoreHistory() async {
    if (_loadingMoreHistory || !_historyHasMore || _history.isEmpty) return;
    final cursor = _history.last;
    final ownerId = widget.store.user?.id;
    setState(() {
      _loadingMoreHistory = true;
      _historyMoreError = null;
    });
    try {
      if (cursor.createdAt == null) throw StateError('INVALID_HISTORY_CURSOR');
      final page = await _service.jobsPage('history', before: cursor);
      if (!mounted ||
          widget.store.user?.id != ownerId ||
          _history.isEmpty ||
          _history.last.id != cursor.id) {
        return;
      }
      if (page.isNotEmpty && page.last.id == cursor.id) {
        throw StateError('INVALID_HISTORY_CURSOR');
      }
      final cancelledIds = page
          .where(
            (job) =>
                job.status == 'cancelled_by_driver' ||
                job.status == 'cancelled_by_customer',
          )
          .map((job) => job.id);
      if (cancelledIds.isNotEmpty) {
        try {
          final details = await _service.cancellationDetails(cancelledIds);
          if (!mounted || widget.store.user?.id != ownerId) return;
          _cancellationDetails.addEntries(
            details.map((detail) => MapEntry(detail.jobId, detail)),
          );
        } catch (_) {
          /* Cancellation details do not block history. */
        }
      }
      if (!mounted || widget.store.user?.id != ownerId) return;
      final ids = _history.map((job) => job.id).toSet();
      setState(() {
        _history = [..._history, ...page.where((job) => ids.add(job.id))];
        _historyHasMore = page.length == 50;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _historyMoreError =
              'No se pudo cargar más historial. Inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMoreHistory = false);
    }
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

  Future<MarketplaceWebAlertReadiness> _checkWebJobAlerts() async {
    final userId = widget.store.user?.id;
    if (userId == null) {
      return MarketplaceWebAlertReadiness.registrationFailed;
    }

    final result = await verifyMarketplaceWebAlertReadiness(
      checkPermission: () async =>
          (await FirebaseMessaging.instance.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          )).authorizationStatus,
      requestToken: () => getPushTokenSafely(
        isWeb: true,
        getToken: ({vapidKey, serviceWorkerScriptPath}) =>
            FirebaseMessaging.instance.getToken(
          vapidKey: vapidKey,
          serviceWorkerScriptPath: serviceWorkerScriptPath,
        ),
      ),
      registerToken: (token) => SupabasePushDeviceTokenRepository(
        Supabase.instance.client,
      ).register(
        userId: userId,
        token: token,
        platform: 'web',
        now: DateTime.now().toUtc(),
      ),
    );

    if (mounted) {
      setState(() {
        _webAlertVerified = result == MarketplaceWebAlertReadiness.ready;
      });
    }
    return result;
  }

  Future<bool> _verifyWebJobAlerts() async {
    if (!kIsWeb) return true;
    final result = await _checkWebJobAlerts();
    if (!mounted) return false;
    if (result == MarketplaceWebAlertReadiness.ready) return true;

    final recovered = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => MarketplaceWebAlertSetupDialog(
        initialStatus: result,
        recheck: _checkWebJobAlerts,
        playSound: playMarketplaceWebJobSoundTest,
      ),
    );
    return mounted && recovered == true;
  }

  Future<bool> _checkAndroidJobAlerts() async {
    // Native Android only. Never activates Working until the device can
    // present audible alerts and Firebase has an active registered token.
    try {
      final permission = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus != AuthorizationStatus.authorized) {
        return false;
      }
      final status = await AndroidDriverAlertBridge.inspect();
      if (status?.ready != true) return false;
      final userId = widget.store.user?.id;
      if (userId == null) return false;
      final token = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 12),
      );
      if (token == null || token.isEmpty) return false;
      await SupabasePushDeviceTokenRepository(Supabase.instance.client).register(
        userId: userId,
        token: token,
        platform: 'android',
        now: DateTime.now().toUtc(),
      ).timeout(const Duration(seconds: 12));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _verifyAndroidJobAlerts() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    if (await _checkAndroidJobAlerts()) return true;
    if (!mounted) return false;
    final initialStatus = await AndroidDriverAlertBridge.inspect();
    if (!mounted) return false;
    final recovered = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MarketplaceAndroidAlertSetupDialog(
        initialStatus: initialStatus,
        recheck: _checkAndroidJobAlerts,
        openSettings: AndroidDriverAlertBridge.openSettings,
      ),
    );
    return mounted && recovered == true;
  }

  Future<void> _enableFloatingShortcut() async {
    await Hive.box(_metaBox).put(_marketplaceFloatingSettingKey, true);

    if (!mounted) return;

    setState(() => _floatingOptedIn = true);
    await _syncMarketplaceFloatingShortcut();
  }

  Future<void> _completeFloatingPermissionRequest() async {
    if (!mounted) return;

    if (await AndroidFloatingButtonBridge.canDraw()) {
      await _enableFloatingShortcut();
    } else if (mounted) {
      toast(
        context,
        'El botón flotante sigue desactivado. '
        'Puedes habilitarlo desde Trabajo.',
      );
    }
  }

  Future<void> _toggleFloatingShortcut() async {
    if (!AndroidFloatingButtonBridge.supported) return;

    if (_floatingOptedIn) {
      await Hive.box(_metaBox).put(_marketplaceFloatingSettingKey, false);

      if (!mounted) return;

      setState(() => _floatingOptedIn = false);
      await _syncMarketplaceFloatingShortcut();
      return;
    }

    if (!await AndroidFloatingButtonBridge.canDraw()) {
      if (!mounted) return;

      _requestingFloatingPermission = true;

      final opened =
          await AndroidFloatingButtonBridge.openPermission();

      if (!opened && mounted) {
        _requestingFloatingPermission = false;

        toast(
          context,
          'No se pudieron abrir los permisos del botón flotante.',
        );
      }
      return;
    }

    await _enableFloatingShortcut();
  }
  Future<void> _setAcceptingJobs(bool acceptingJobs) async {
    final vehicle = _vehicleById(_selectedVehicleId);

    if (vehicle == null ||
        !_vehicleReadyForWork(vehicle) ||
        _updatingAvailability) {
      return;
    }

    // Debe ejecutarse dentro del toque del usuario: navegador permite audio.
    if (acceptingJobs) prepareMarketplaceWebJobAlertActivation();
    setState(() => _updatingAvailability = true);

    try {
      // WebApp: no declarar Trabajando sin permiso y token push registrado.
      // Android se verificara en su APK despues de aprobar las pruebas web.
      if (acceptingJobs && kIsWeb && !(await _verifyWebJobAlerts())) return;
      if (acceptingJobs && !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          !(await _verifyAndroidJobAlerts())) {
        return;
      }
      if (!mounted) return;

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
          _webAlertVerified = false;
        }
      });

      configureMarketplaceWebJobAlerts(acceptingJobs);
      _marketplaceDriverWorking.value = acceptingJobs;
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
      if (_marketplaceJobStartsNow(job)) {
        await _service.acceptAndStart(job.id, vehicleId, key);
      } else {
        await _service.accept(job.id, vehicleId, key);
      }

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

      _syncOperationalLocationSampling(
        immediate: true,
        requestPermission: widget.isVisible,
      );

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

  Future<void> _rateHistoryJob(MarketplaceJob job) async {
    if (_busyJobId != null) return;
    final userId = widget.store.user?.id;
    setState(() => _busyJobId = job.id);
    try {
      final existing = await _service.customerRating(job.id);
      if (!mounted || widget.store.user?.id != userId) return;
      if (existing != null) {
        setState(() => _ratedHistoryJobs.add(job.id));
        toast(context, 'Ya has valorado esta carrera.');
        return;
      }
      await _showCustomerRatingSurvey(job.id);
      _ratingsLoaded = false;
      await _refreshAfterJobMutation();
    } catch (_) {
      if (mounted) {
        toast(context, 'No pudimos consultar la valoración. Reintenta.');
      }
    } finally {
      if (mounted) setState(() => _busyJobId = null);
    }
  }

  Future<void> _showCustomerRatingSurvey(String jobId, {bool forFinishing = false}) async {
    final noteController = TextEditingController();
    final requestUserId = widget.store.user?.id;
    ModalRoute<void>? ratingRoute;

    var stars = 0;
    var sending = false;
    String? error;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: .48),
        builder: (sheetContext) {
          ratingRoute = ModalRoute.of<void>(sheetContext);
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
                  if (widget.store.user?.id != requestUserId) return;
                  final note = noteController.text.trim();
                  final ratingAction = 'rating:${jsonEncode([stars, note])}';
                  final idempotencyKey = _operationKey(jobId, ratingAction);

                  await _service.rateCustomer(
                    jobId: jobId,
                    stars: stars,
                    internalNote: note.isEmpty ? null : note,
                    idempotencyKey: idempotencyKey,
                  );

                  if (mounted && widget.store.user?.id == requestUserId) {
                    setState(() => _ratedHistoryJobs.add(jobId));
                  }

                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop(true);
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
                child: _WorkMapGlassPanel(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    14,
                    20,
                    20 + MediaQuery.viewInsetsOf(context).bottom,
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
                        if (forFinishing)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'La carrera se cierra al enviar tu evaluación.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF98F7DE)),
                            ),
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
                          minLines: 2,
                          maxLines: 3,
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
                          child: Text(forFinishing ? 'Volver a carrera' : 'Ahora no'),
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
      // The pop future resolves before the sheet's exit animation finishes.
      // Keep its controller alive until the route removes the TextField.
      await ratingRoute?.completed;
      noteController.dispose();
    }
  }

  Future<void> _refreshIncome() async {
    await widget.store.reconcileMarketplaceIncomes(_service);
    if (mounted) {
      setState(
        () => _incomeError = widget.store.marketplaceIncomeReconciliationError,
      );
    }
  }

  Future<void> _advanceJob(MarketplaceJob job) async {
    final finishing = _marketplaceJobCanFinish(job);
    final action = finishing ? 'finish_service' : job.nextAction;

    if (_busyJobId != null ||
        action == null ||
        (!finishing && action != 'start_en_route')) {
      return;
    }

    setState(() => _busyJobId = job.id);

    final keyName = '${job.id}:$action';
    final key = _operationKey(job.id, action);
    final requestUserId = widget.store.user?.id;

    try {
      if (finishing) {
        await _showCustomerRatingSurvey(job.id, forFinishing: true);
        _ratingsLoaded = false;
        if (mounted && widget.store.user?.id == requestUserId) {
          await _refreshAfterJobMutation();
          // Si se ha cerrado desde una pantalla anterior, vuelve al mapa.
          // Si el backend mantiene la carrera activa, no ocultar el servicio.
          if (mounted && _active.isEmpty && _workPanelIndex == 0) {
            setState(() => _workPanelIndex = -1);
          }
          await _refreshIncome();
        }
        return;
      }
      await _service.advance(job.id, action, key);
      if (widget.store.user?.id != requestUserId) return;
      _operationKeys.remove(keyName);
      if (!mounted) return;
      await _refreshAfterJobMutation();
    } catch (error) {
      if (!mounted) return;

      if (finishing) {
        toast(
          context,
          'No pudimos confirmar el cierre. '
          'Actualiza los trabajos para comprobar su estado '
          'antes de volver a intentarlo.',
        );
        await _refreshAfterJobMutation();
      } else {
        toast(
          context,
          'No se pudo actualizar el trabajo. '
          'Actualiza la sección y vuelve a intentarlo.',
        );
      }
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
      barrierColor: Colors.black.withValues(alpha: .48),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isOther = selectedReason == 'Otro';

            return SafeArea(
              top: false,
              child: _WorkMapGlassPanel(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: EdgeInsets.fromLTRB(
                  20,
                  14,
                  20,
                  20 + MediaQuery.viewInsetsOf(context).bottom,
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
      barrierColor: Colors.black.withValues(alpha: .48),
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;

        return SafeArea(
          top: false,
          child: _WorkMapGlassPanel(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
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
        ? const Color(0xFFFF6B3D)
        : const Color(0xFFD94A24);
    final statusColor = acceptingJobs ? appPrimaryColor(context) : restingColor;
    final statusTitle = acceptingJobs ? 'En servicio' : 'Descansando';
    final statusMessage = acceptingJobs
        ? 'Recibiendo nuevas solicitudes'
        : 'No estás recibiendo solicitudes';
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
                      ? 'Descansar: dejar de recibir solicitudes'
                      : 'Trabajar: empezar a recibir solicitudes',
                  toggled: acceptingJobs,
                  enabled: !_updatingAvailability,
                  onTap: _updatingAvailability
                      ? null
                      : () => unawaited(_setAcceptingJobs(!acceptingJobs)),
                  child: ExcludeSemantics(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: const ValueKey('marketplace-availability-switch'),
                        borderRadius: BorderRadius.circular(32),
                        onTap: _updatingAvailability
                            ? null
                            : () =>
                                  unawaited(_setAcceptingJobs(!acceptingJobs)),
                        child: Container(
                          width: 112,
                          height: 58,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(
                              alpha: acceptingJobs ? 0.12 : 0.18,
                            ),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: statusColor.withValues(
                                alpha: acceptingJobs ? 0.36 : 0.58,
                              ),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withValues(
                                  alpha: acceptingJobs ? 0.12 : 0.24,
                                ),
                                blurRadius: acceptingJobs ? 10 : 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Transform.scale(
                            scale: 1.24,
                            child: IgnorePointer(
                              child: Switch.adaptive(
                                value: acceptingJobs,
                                // Todo el toque lo gestiona el InkWell exterior.
                                onChanged: _updatingAvailability
                                    ? null
                                    : (_) {},
                              ),
                            ),
                          ),
                        ),
                      ),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: statusColor.withValues(
                  alpha: acceptingJobs ? 0.11 : 0.16,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: statusColor.withValues(
                    alpha: acceptingJobs ? 0.32 : 0.52,
                  ),
                  width: acceptingJobs ? 1 : 1.5,
                ),
                boxShadow: acceptingJobs
                    ? null
                    : [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.12),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(
                        alpha: acceptingJobs ? 0.15 : 0.22,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, size: 22, color: statusColor),
                  ),
                  const SizedBox(width: 12),
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
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusMessage,
                          style: TextStyle(
                            color: acceptingJobs
                                ? appMutedColor(context)
                                : statusColor.withValues(alpha: 0.92),
                            fontSize: 12,
                            fontWeight: acceptingJobs
                                ? FontWeight.w600
                                : FontWeight.w700,
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

  Future<void> _prepareWorkMap() async {
    try {
      final config = await MarketplaceMapService(
        Supabase.instance.client,
      ).runtimeVisualConfiguration();
      if (mounted && config != null && config.token.startsWith('pk.')) {
        mbx.MapboxOptions.setAccessToken(config.token);
        setState(() {
          _workMapVisual = config;
          _workMapFallback = false;
        });
      }
    } catch (_) {
      // La falta del mapa nunca debe bloquear la operación ni los servicios.
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }
      final position = await Geolocator.getLastKnownPosition();
      if (!mounted || position == null) return;
      setState(
        () => _workMapPosition = LatLng(position.latitude, position.longitude),
      );
    } catch (_) {
      // No se pide permiso al cargar el mapa; el conductor decide cuando ubicarlo.
    }
  }

  Future<void> _centerWorkMap() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) toast(context, 'Activa la ubicación del teléfono.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          toast(context, 'Autoriza la ubicación para centrar el mapa.');
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      final center = LatLng(position.latitude, position.longitude);
      setState(() => _workMapPosition = center);
      setState(() {
        _workMapZoom = 15;
      });
    } catch (_) {
      if (mounted) toast(context, 'No se pudo obtener tu ubicación.');
    }
  }

  void _openWorkPanel(int panel) {
    setState(() {
      _workDrawerOpen = false;
      _workPanelIndex = panel;
    });
    if (panel == 3) unawaited(_loadRatings(force: true));
  }

  void _backToWorkMap() {
    setState(() => _workPanelIndex = -1);
    unawaited(_load());
  }

  Widget _workMenuItem(IconData icon, String name, int panel) => ListTile(
    leading: Icon(icon, color: kPrimary),
    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => _openWorkPanel(panel),
  );

  Widget _workDrawerDriverHeader() {
    final googleUser = widget.store.user;
    final photo = _googleProfilePhotoUrl(googleUser);
    final googleName =
        googleUser?.userMetadata?['full_name']?.toString() ??
        googleUser?.userMetadata?['name']?.toString();
    final driverName = marketplaceDriverHeaderName(
      registeredName: _onboarding?.displayName,
      googleName: googleName,
    );
    final phone = _onboarding?.phone?.trim();
    final email = googleUser?.email?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: kSurfaceHigh,
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: photo == null
                ? const Icon(Icons.person_outline_rounded, color: kPrimary)
                : Image.network(
                    photo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.person_outline_rounded,
                      color: kPrimary,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driverName,
                  key: const ValueKey('work-drawer-driver-name'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  phone == null || phone.isEmpty
                      ? 'Teléfono no registrado'
                      : phone,
                  key: const ValueKey('work-drawer-driver-phone'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: kMuted),
                ),
                Text(
                  email == null || email.isEmpty
                      ? 'Correo de Google no disponible'
                      : email,
                  key: const ValueKey('work-drawer-google-email'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: kMuted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar menú de Trabajo',
            onPressed: () => setState(() => _workDrawerOpen = false),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  void _openWorkDrawerPage(BuildContext context, String title, Widget child) {
    setState(() => _workDrawerOpen = false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: AppBackground(child: SafeArea(child: child)),
        ),
      ),
    );
  }

  void _openWorkReferrals(BuildContext context) {
    if (widget.store.user != null) {
      unawaited(widget.store.loadReferrals());
    }
    _openWorkDrawerPage(
      context,
      'Mis referidos',
      AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [_ReferralCard(store: widget.store)],
        ),
      ),
    );
  }

  Widget _buildWorkDrawer(BuildContext context) => Positioned.fill(
    child: Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const ValueKey('work-map-dismiss-menu'),
            onTap: () => setState(() => _workDrawerOpen = false),
            child: Container(color: Colors.black.withValues(alpha: .63)),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: .85,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Material(
                color: kSurface,
                elevation: 18,
                child: SafeArea(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      0,
                      15,
                      0,
                      MediaQuery.sizeOf(context).width < 1100
                          ? MediaQuery.paddingOf(context).bottom + 140
                          : 15,
                    ),
                    children: [
                      _workDrawerDriverHeader(),

                      const Divider(),
                      if (_incomeError != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            _incomeError ?? '',
                            key: const ValueKey('marketplace-income-error'),
                            style: const TextStyle(color: kDanger),
                          ),
                        ),
                      // Las carreras se gestionan desde el mapa principal.
                      _workMenuItem(Icons.event_outlined, 'Programados', 1),
                      _workMenuItem(Icons.history_rounded, 'Historial', 2),
                      _workMenuItem(
                        Icons.star_outline_rounded,
                        'Evaluaciones',
                        3,
                      ),
                      _workMenuItem(
                        Icons.account_balance_wallet_outlined,
                        'Billetera',
                        4,
                      ),
                      _workMenuItem(
                        Icons.badge_outlined,
                        'Conductor y vehículo',
                        5,
                      ),
                      _workMenuItem(Icons.insights_outlined, 'Mi actividad', 6),
                      ListTile(
                        key: const ValueKey('work-drawer-referrals'),
                        leading: const Icon(
                          Icons.people_alt_outlined,
                          color: kPrimary,
                        ),
                        title: const Text(
                          'Mis referidos',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _openWorkReferrals(context),
                      ),
                      ListTile(
                        key: const ValueKey('work-drawer-permissions'),
                        leading: const Icon(
                          Icons.verified_user_outlined,
                          color: kPrimary,
                        ),
                        title: const Text(
                          'Permisos de la aplicación',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _openWorkDrawerPage(
                          context,
                          'Permisos de la aplicación',
                          const MarketplaceDriverPermissionsScreen(),
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.refresh_rounded),
                        title: const Text('Actualizar trabajos'),
                        onTap: () {
                          setState(() => _workDrawerOpen = false);
                          unawaited(_load());
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _workMapSurface(BuildContext context) {
    final center = _workMapPosition ?? const LatLng(23.1136, -82.3666);
    final active = _active.isNotEmpty ? _active.first : null;
    final config = _workMapVisual;
    if (config == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'No pudimos configurar el mapa. Puedes seguir recibiendo solicitudes.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => unawaited(_prepareWorkMap()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar mapa'),
            ),
          ],
        ),
      );
    }
    // Conserva el mismo Mapbox al aceptar, avanzar o finalizar una carrera.
    final style = _workMapFallback ? 'mapbox/dark-v11' : config.stylePath;
    return MarketplaceDriverMap(
      job: active,
      showLegend: false,
      fullBleed: true,
      idleCenter: center,
      idleZoom: _workMapZoom,
      showIdleLocation: _workMapPosition != null,
      configuration: config,
      stylePath: style,
    );
  }

  // TUKTUK Trabajo V3: avatar y estado premium sobre la cartografia.
  Widget _workPremiumAvatar(String? photo) {
    return Tooltip(
      message: 'Abrir menú de Trabajo',
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .32),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: const Color(0xF219303C),
          shape: CircleBorder(
            side: BorderSide(
              color: const Color(0xFF51E0C1).withValues(alpha: .70),
              width: 1.5,
            ),
          ),
          child: InkWell(
            key: const ValueKey('work-map-open-menu'),
            customBorder: const CircleBorder(),
            onTap: () => setState(() => _workDrawerOpen = true),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: kSurfaceHigh,
                backgroundImage: photo == null ? null : NetworkImage(photo),
                child: photo == null
                    ? const Icon(Icons.directions_car_rounded, color: kTertiary)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _workPremiumAvailability({
    required bool available,
    required bool valid,
    required bool onRide,
  }) {
    final accent = onRide
        ? const Color(0xFF8CB9FF)
        : !valid || !available
        ? const Color(0xFFE6BD81)
        : const Color(0xFF43E4BB);
    final label = onRide
        ? 'EN CARRERA'
        : !valid
        ? 'ACTIVAR'
        : available
        ? 'TRABAJANDO'
        : 'DESCANSANDO';
    final subtitle = _updatingAvailability
        ? 'Actualizando estado...'
        : onRide
        ? 'Servicio en curso'
        : !valid
        ? 'Completa la activación'
        : available
        ? 'Toca para descansar'
        : 'Toca para trabajar';
    final interactive = !onRide && !_updatingAvailability;
    return Semantics(
      button: true,
      toggled: available,
      enabled: interactive,
      label: onRide
          ? 'En carrera. Estado bloqueado durante el servicio'
          : !valid
          ? 'Completar activación para trabajar'
          : available
          ? 'Trabajando. Toca para descansar'
          : 'Descansando. Toca para trabajar',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xF51A2F3B), Color(0xF313222D)],
          ),
          border: Border.all(color: accent.withValues(alpha: .58), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .28),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('work-map-availability-toggle'),
            borderRadius: BorderRadius.circular(20),
            excludeFromSemantics: true,
            onTap: !interactive
                ? null
                : valid
                ? () => unawaited(_setAcceptingJobs(!available))
                : _openActivation,
            child: SizedBox(
              height: MediaQuery.sizeOf(context).width < 375 ? 64 : 70,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 6, 7, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .3,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: .78),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: .26),
                            blurRadius: 9,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: _updatingAvailability
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Color(0xFF142733),
                              ),
                            )
                          : Icon(
                              onRide
                                  ? Icons.route_rounded
                                  : !valid
                                  ? Icons.settings_rounded
                                  : available
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 31,
                              color: const Color(0xFF142733),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _workPremiumMapAction({
    required String actionKey,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey(actionKey),
            borderRadius: BorderRadius.circular(15),
            onTap: onPressed,
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(icon, color: const Color(0xFFE1FFF5), size: 23),
            ),
          ),
        ),
      ),
    );
  }

  Widget _workPremiumMapTools() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xF51A303D), Color(0xF3112530)],
        ),
        border: Border.all(
          color: const Color(0xFF61CDB5).withValues(alpha: .40),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _workPremiumMapAction(
              actionKey: 'work-map-locate',
              label: 'Centrar en mi ubicación',
              icon: Icons.my_location_rounded,
              onPressed: () => unawaited(_centerWorkMap()),
            ),
            Container(
              width: 22,
              height: 1,
              color: Colors.white.withValues(alpha: .13),
            ),
            _workPremiumMapAction(
              actionKey: 'work-map-zoom-in',
              label: 'Acercar mapa',
              icon: Icons.add_rounded,
              onPressed: () => setState(() {
                _workMapZoom = (_workMapZoom + 1).clamp(3, 19).toDouble();
              }),
            ),
            Container(
              width: 22,
              height: 1,
              color: Colors.white.withValues(alpha: .13),
            ),
            _workPremiumMapAction(
              actionKey: 'work-map-zoom-out',
              label: 'Alejar mapa',
              icon: Icons.remove_rounded,
              onPressed: () => setState(() {
                _workMapZoom = (_workMapZoom - 1).clamp(3, 19).toDouble();
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkMapHome(BuildContext context) {
    final vehicle = _vehicleById(_selectedVehicleId);
    final valid = _vehicleReadyForWork(vehicle);
    final available = vehicle?.acceptingJobs == true;
    final active = _active.isNotEmpty ? _active.first : null;
    final onRide = active != null;
    final canFinish = active != null && _marketplaceJobCanFinish(active);
    final canStart =
        active != null &&
        active.status == 'accepted' &&
        active.nextAction == 'start_en_route';
    final canCancel = active != null && _marketplaceJobCanDriverCancel(active);
    final busy = active != null && _busyJobId == active.id;
    final photo = _googleProfilePhotoUrl(widget.store.user);
    final bottomNavInset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      key: const ValueKey('tuktuk-work-map-home'),
      fit: StackFit.expand,
      children: [
        _workMapSurface(context),
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: Row(
            children: [
              _workPremiumAvatar(photo),
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 238),
                    child: _workPremiumAvailability(
                      available: available,
                      valid: valid,
                      onRide: onRide,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (AndroidFloatingButtonBridge.supported)
          Positioned(
            left: 12,
            top: 88,
            child: Material(
              color: const Color(0xE8122630),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                key: const ValueKey('tuktuk-floating-shortcut-toggle'),
                borderRadius: BorderRadius.circular(18),
                onTap: () => unawaited(_toggleFloatingShortcut()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _floatingOptedIn
                            ? Icons.touch_app_rounded
                            : Icons.touch_app_outlined,
                        color: _floatingOptedIn
                            ? kPrimary
                            : Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        _floatingOptedIn
                            ? 'Botón flotante: sí'
                            : 'Botón flotante: no',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),        if (kIsWeb && available && !onRide && !_webAlertVerified)
          Positioned(
            left: 12,
            right: 12,
            top: 96,
            child: Material(
              color: const Color(0xF03E2D20),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                key: const ValueKey('work-web-alert-check'),
                borderRadius: BorderRadius.circular(14),
                onTap: _updatingAvailability
                    ? null
                    : () => unawaited(_verifyWebJobAlerts()),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.notification_important_outlined,
                          color: Color(0xFFFFC47B)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Alertas de trabajo sin verificar. Toca para comprobar.',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (!onRide && _workMapVisual != null)
          Positioned(
            right: 12,
            bottom:
                bottomNavInset +
                (_available.isNotEmpty
                    ? 288
                    : (_scheduled.isNotEmpty || _error != null ? 128 : 16)),
            child: _workPremiumMapTools(),
          ),
        // Sin solicitudes ni incidencias, el mapa permanece despejado.
        // Las ofertas reales tienen prioridad sobre el recordatorio de agenda.
        if (onRide ||
            _available.isNotEmpty ||
            _scheduled.isNotEmpty ||
            _error != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: bottomNavInset + 12,
            child: onRide
                ? ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: (MediaQuery.sizeOf(context).height * .48).clamp(
                        300.0,
                        410.0,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 13, sigmaY: 13),
                        child: Container(
                          key: const ValueKey('work-map-glass-active-card'),
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xC00A2833), Color(0xD20B1925)],
                            ),
                            border: Border.all(
                              color: const Color(0x804AE5D1),
                              width: 1.1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.navigation_rounded,
                                    color: Color(0xFF77E9DF),
                                    size: 21,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      active.status == 'en_route'
                                          ? 'En camino a recoger'
                                          : _marketplaceJobStatusLabel(
                                              active.status,
                                            ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        _marketplaceMoneyLabel(
                                          active.finalPrice,
                                          active.currency,
                                        ),
                                        key: const ValueKey(
                                          'work-active-price',
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 21,
                                          color: Color(0xFF58E6B3),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              Flexible(
                                fit: FlexFit.loose,
                                child: SingleChildScrollView(
                                  primary: false,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _WorkMapLocationRow(
                                        pickup: true,
                                        address:
                                            active.originText ??
                                            'Sin dirección',
                                        expanded: _workRideDetailsExpanded,
                                      ),
                                      const SizedBox(height: 6),
                                      _WorkMapLocationRow(
                                        pickup: false,
                                        address:
                                            active.destinationText ??
                                            'Sin dirección',
                                        expanded: _workRideDetailsExpanded,
                                      ),
                                      TextButton.icon(
                                        key: const ValueKey(
                                          'work-map-toggle-details',
                                        ),
                                        onPressed: () => setState(
                                          () => _workRideDetailsExpanded =
                                              !_workRideDetailsExpanded,
                                        ),
                                        icon: Icon(
                                          _workRideDetailsExpanded
                                              ? Icons.expand_less_rounded
                                              : Icons.expand_more_rounded,
                                        ),
                                        label: Text(
                                          _workRideDetailsExpanded
                                              ? 'Ocultar detalles'
                                              : 'Ver detalles de la ruta',
                                        ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: const Color(
                                            0xFF98F7DE,
                                          ),
                                          alignment: Alignment.centerLeft,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                      if (_workRideDetailsExpanded && canCancel)
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton.icon(
                                            key: const ValueKey(
                                              'work-map-cancel-job',
                                            ),
                                            onPressed: busy
                                                ? null
                                                : () => unawaited(
                                                    _cancelJob(active),
                                                  ),
                                            icon: const Icon(
                                              Icons.cancel_outlined,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'Cancelar servicio',
                                            ),
                                            style: TextButton.styleFrom(
                                              foregroundColor: const Color(
                                                0xFFCFDEE6,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              if (canFinish || canStart) ...[
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: FilledButton.icon(
                                    key: const ValueKey('work-map-advance-job'),
                                    onPressed: busy
                                        ? null
                                        : () => unawaited(_advanceJob(active)),
                                    icon: busy
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Icon(
                                            canFinish
                                                ? Icons
                                                      .check_circle_outline_rounded
                                                : Icons.navigation_rounded,
                                          ),
                                    label: Text(
                                      canFinish
                                          ? 'Finalizar carrera'
                                          : 'Salir hacia el cliente',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton.icon(
                                  key: const ValueKey(
                                    'work-map-contact-customer',
                                  ),
                                  onPressed: busy
                                      ? null
                                      : () => unawaited(_contactJob(active)),
                                  icon: const Icon(Icons.contact_phone_rounded),
                                  label: const Text(
                                    'Contactar cliente',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF98F7DE),
                                    side: const BorderSide(
                                      color: Color(0xFF58E6B3),
                                      width: 1.6,
                                    ),
                                  ),
                                ),
                              ),
                              if (!canFinish && !canStart && !canCancel)
                                TextButton(
                                  onPressed: () => _openWorkPanel(0),
                                  child: const Text(
                                    'Ver opciones del servicio',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : _available.isNotEmpty
                ? SizedBox(
                    // Una oferta por pagina: precio y aceptar permanecen
                    // dentro de la misma ficha, incluso en pantallas pequenas.
                    height: (MediaQuery.sizeOf(context).height * .56).clamp(
                      308.0,
                      410.0,
                    ),
                    child: PageView.builder(
                      key: const ValueKey('work-map-offers-pager'),
                      itemCount: _available.length,
                      itemBuilder: (context, index) {
                        final job = _available[index];
                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: _AvailableJobCard(
                          key: ValueKey('work-map-offer-${job.id}'),
                          job: job,
                          accepting: _acceptingJobId == job.id,
                          acceptanceLocked: _acceptingJobId != null,
                          onAccept: () => _acceptJob(job),
                          position: index + 1,
                          total: _available.length,
                          ),
                        );
                      },
                    ),
                  )
                : _scheduled.isNotEmpty
                ? GlassCard(
                    child: ListTile(
                      leading: const Icon(Icons.event_available_outlined),
                      title: const Text('Tienes trabajos programados'),
                      subtitle: const Text('Consulta tu agenda'),
                      onTap: () => _openWorkPanel(1),
                    ),
                  )
                : GlassCard(
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber_rounded),
                      title: const Text('No pudimos actualizar las carreras'),
                      subtitle: Text(_error ?? ''),
                      trailing: IconButton(
                        tooltip: 'Reintentar actualización',
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: () => unawaited(_load()),
                      ),
                      onTap: () => unawaited(_load()),
                    ),
                  ),
          ),
        if (_workDrawerOpen) _buildWorkDrawer(context),
      ],
    );
  }

  Widget _buildWorkPanel(BuildContext context) {
    final names = <String>[
      'Trabajos y servicio',
      'Programados',
      'Historial',
      'Evaluaciones',
      'Billetera',
      'Conductor y vehículo',
      'Mi actividad',
    ];
    final panel = _workPanelIndex;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('work-map-back'),
                tooltip: 'Volver al mapa de Trabajo',
                onPressed: _backToWorkMap,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Text(
                  names[panel],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: () => unawaited(_load()),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (panel) {
            0 => _buildServiceTab(context),
            1 => _buildAssignedTab(
              context,
              scope: 'scheduled',
              icon: Icons.event_outlined,
              emptyTitle: 'No tienes trabajos programados',
              emptyMessage: 'Los servicios futuros aparecerán aquí.',
            ),
            2 => _buildAssignedTab(
              context,
              scope: 'history',
              icon: Icons.history_rounded,
              emptyTitle: 'Tu historial está vacío',
              emptyMessage: 'Aquí aparecen las carreras finalizadas.',
            ),
            3 => _buildRatingsTab(context),
            4 => MarketplaceOnboardingScreen(
              key: ValueKey('wallet-$_selectedVehicleId-$_managementRevision'),
              store: widget.store,
              managementSection: MarketplaceManagementSection.wallet,
              initialVehicleId: _selectedVehicleId,
            ),
            5 => MarketplaceOnboardingScreen(
              store: widget.store,
              onManagementChanged: _onManagementChanged,
            ),
            6 => StatsScreen(store: widget.store),
            _ => const SizedBox.shrink(),
          },
        ),
      ],
    );
  }

  // Los paneles y formularios mantienen la zona segura; el mapa es la excepcion.
  Widget _workNonMapSafeArea(Widget content) =>
      SafeArea(top: false, left: false, right: false, child: content);

  @override
  Widget build(BuildContext context) {
    // La pestaña Trabajo mantiene su estado y su muestreo previo de GPS.
    if (!widget.isVisible) return const SizedBox.shrink();
    if (_loading && _onboarding == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final onboarding = _onboarding;
    if (onboarding == null) {
      return _workNonMapSafeArea(_buildAvailableTab(context));
    }
    if (_marketplaceDriverNeedsSetup(onboarding)) {
      return _workNonMapSafeArea(
        MarketplaceOnboardingScreen(
          store: widget.store,
          onManagementChanged: _onManagementChanged,
        ),
      );
    }
    if (_workPanelIndex >= 0) {
      return _workNonMapSafeArea(_buildWorkPanel(context));
    }
    return _buildWorkMapHome(context);
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
                  position: 1,
                  total: 1,
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
                            (_marketplaceJobCanFinish(job) ||
                                (job.status == 'accepted' &&
                                    job.nextAction == 'start_en_route'))
                        ? () => _advanceJob(job)
                        : null,
                    onCancel:
                        scope != 'history' &&
                            _marketplaceJobCanDriverCancel(job)
                        ? () => _cancelJob(job)
                        : null,
                    onRating:
                        scope == 'history' &&
                            job.status == 'settled' &&
                            !_ratedHistoryJobs.contains(job.id) &&
                            !_ratings.any(
                              (r) => r.jobId == job.id && r.givenStars != null,
                            )
                        ? () => _rateHistoryJob(job)
                        : null,
                  ),
                ),
              ),
            if (scope == 'history' && _historyMoreError != null)
              Text(_historyMoreError!),
            if (scope == 'history' && _historyHasMore)
              TextButton(
                key: const ValueKey('marketplace-history-more'),
                onPressed: _loadingMoreHistory ? null : _loadMoreHistory,
                child: Text(
                  _loadingMoreHistory ? 'Cargando…' : 'Cargar más historial',
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
    this.onRating,
  });

  final MarketplaceJob job;
  final String scope;
  final bool busy;
  final bool showMap;
  final MarketplaceJobCancellationDetail? cancellationDetail;
  final VoidCallback? onContact;
  final VoidCallback? onAdvance;
  final VoidCallback? onCancel;
  final VoidCallback? onRating;

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
                    _marketplaceJobCanFinish(job)
                        ? 'Finalizar carrera'
                        : (_marketplaceJobActionLabel(job.nextAction) ??
                              'Continuar'),
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
              children: List.generate(2, (index) {
                const labels = ['En camino', 'Finalizado'];

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
          if (onRating != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : onRating,
              icon: const Icon(Icons.star_outline_rounded),
              label: const Text('Valorar cliente'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Superficie de cristal comun para todas las tarjetas del mapa de Trabajo.
/// El contenido conserva su contraste y los botones mantienen sus colores.
class _WorkMapGlassPanel extends StatelessWidget {
  const _WorkMapGlassPanel({
    required this.child,
    this.margin = EdgeInsets.zero,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 13, sigmaY: 13),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xC00A2833), Color(0xD20B1925)],
              ),
              border: Border.all(color: const Color(0x804AE5D1), width: 1.1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// El marcador de la ficha utiliza el mismo recurso grafico que el mapa.
/// Su etiqueta y direccion se mantienen independientes de la cartografia.
class _WorkMapLocationRow extends StatelessWidget {
  const _WorkMapLocationRow({
    required this.pickup,
    required this.address,
    this.expanded = false,
  });

  final bool pickup;
  final String address;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final color = pickup ? const Color(0xFF58E6B3) : const Color(0xFFFF707C);
    final label = pickup ? 'Recogida' : 'Destino';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 36,
          height: 42,
          child: Image.asset(
            pickup
                ? 'assets/map_markers/pickup_green.png'
                : 'assets/map_markers/destination_red.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              pickup ? Icons.person_pin_circle_rounded : Icons.flag_rounded,
              size: 30,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                maxLines: expanded ? null : 2,
                overflow: expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvailableJobCard extends StatefulWidget {
  const _AvailableJobCard({
    required this.job,
    required this.accepting,
    required this.acceptanceLocked,
    required this.onAccept,
    required this.position,
    required this.total,
    super.key,
  });

  final MarketplaceAvailableJob job;
  final bool accepting;
  final bool acceptanceLocked;
  final VoidCallback onAccept;
  final int position;
  final int total;

  @override
  State<_AvailableJobCard> createState() => _AvailableJobCardState();
}

class _AvailableJobCardState extends State<_AvailableJobCard> {
  bool _detailsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final origin = job.originText?.trim().isNotEmpty == true
        ? job.originText!
        : 'Origen no disponible';
    final destination = job.destinationText?.trim().isNotEmpty == true
        ? job.destinationText!
        : 'Destino no disponible';

    return _WorkMapGlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_taxi_rounded,
                color: Color(0xFF68B4FF),
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _marketplaceJobServiceLabel(job.serviceCode),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                    if (widget.total > 1)
                      Text(
                        'Solicitud ${widget.position} de ${widget.total} · desliza para ver otras',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFFADC8D2),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    _marketplaceMoneyLabel(job.finalPrice, job.currency),
                    key: ValueKey('work-map-offer-price-${job.id}'),
                    style: const TextStyle(
                      color: Color(0xFF58E6B3),
                      fontWeight: FontWeight.w900,
                      fontSize: 21,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              primary: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WorkMapLocationRow(
                    pickup: true,
                    address: origin,
                    expanded: _detailsExpanded,
                  ),
                  const SizedBox(height: 6),
                  _WorkMapLocationRow(
                    pickup: false,
                    address: destination,
                    expanded: _detailsExpanded,
                  ),
                  if (_detailsExpanded) ...[
                    const Divider(height: 12),
                    Text(
                      job.scheduledFor == null
                          ? 'Solicitud para ahora'
                          : 'Programado: ${_marketplaceJobDateLabel(job.scheduledFor)}',
                    ),
                    if (job.passengerCount != null) ...[
                      const SizedBox(height: 6),
                      Text('${job.passengerCount} pasajero(s)'),
                    ],
                    if (job.cargoWeightKg != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Carga: ${job.cargoWeightKg!.toStringAsFixed(0)} kg',
                      ),
                    ],
                    if (job.requiredBodyType?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text('Carrocería requerida: ${job.requiredBodyType}'),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              key: ValueKey('work-map-offer-accept-${job.id}'),
              onPressed: widget.acceptanceLocked && !widget.accepting
                  ? null
                  : widget.onAccept,
              icon: widget.accepting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                widget.accepting
                    ? 'Aceptando...'
                    : _marketplaceJobStartsNow(job)
                    ? 'Aceptar e ir a buscar'
                    : 'Aceptar trabajo',
              ),
            ),
          ),
          TextButton.icon(
            key: ValueKey('work-map-offer-toggle-${job.id}'),
            onPressed: () =>
                setState(() => _detailsExpanded = !_detailsExpanded),
            icon: Icon(
              _detailsExpanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 18,
            ),
            label: Text(
              _detailsExpanded ? 'Ocultar detalles' : 'Más detalles',
            ),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              alignment: Alignment.center,
              foregroundColor: const Color(0xFF66B7FF),
            ),
          ),
        ],
      ),
    );
  }
}
