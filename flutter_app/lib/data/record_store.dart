part of '../main.dart';

class RecordStore extends ChangeNotifier {
  static const _licenseValidationInterval = Duration(minutes: 15);
  static const _licenseRetryInterval = Duration(minutes: 2);
  static const _resumeRefreshMinInterval = Duration(minutes: 5);
  static const _automaticSyncInterval = Duration(minutes: 15);

  RecordStore({
    PushTokenRegistrationCoordinator? pushTokenCoordinator,
    AppLinks? referralAppLinks,
  }) : _pushTokenCoordinator = pushTokenCoordinator {
    _licenseService = SupabaseLicenseService(
      client: _supabase,
      cache: _meta,
    );
    _whatsAppSettingsService = WhatsAppSettingsService(
      projectId: _projectId,
      cache: HiveWhatsAppSettingsCache(_meta),
      loadRemote: (projectId) => _supabase.rpc(
        'get_public_whatsapp_settings',
        params: {'target_project_id': projectId},
      ),
    );
    _referralRemoteService = ReferralRemoteService(_supabase);
    _pendingReferralClaims = PendingReferralClaimController(
      HivePendingReferralCodeStore(_meta),
    );
    _initialReferralCapture = kIsWeb
        ? _pendingReferralClaims.capture(Uri.base)
        : Future<bool>.value(false);
    if (!kIsWeb && referralAppLinks != null) {
      _referralLinkListener = ReferralLinkListener(
        appLinks: referralAppLinks,
        onUri: _captureReferralUri,
      )..start();
    }
    whatsAppSettings = _whatsAppSettingsService.cachedSettings();
    _supabaseGateway = SupabaseSyncGateway(
      client: _supabase,
      payloadFor: _payloadForOperation,
    );
    _syncCoordinator = SyncCoordinator(
      queue: _syncQueue,
      gateway: _supabaseGateway,
    );
    _restoreCachedIdentityAndLicense();
    _restoreCachedExchangeRate();
    _authSubscription = _supabase.auth.onAuthStateChange.listen((state) {
      final nextUser = state.session?.user;
      if (!initialized) {
        _hasPendingAuthState = true;
        _pendingAuthUser = nextUser;
        return;
      }
      final currentUser = user;

      // Una renovacion normal del token conserva el mismo usuario.
      // No debe reiniciar perfil, push, Realtime, licencia y sync.
      if (currentUser != null && nextUser?.id == currentUser.id) {
        user = nextUser;
        return;
      }

      unawaited(_handleAuthState(nextUser));
    }, onError: _handleAuthStreamError);
    _load();
    unawaited(_initialize());
  }

  final Box _box = Hive.box(_recordsBox);
  final Box _maintenanceBox = Hive.box(_maintenanceRecordsBox);
  final Box _meta = Hive.box(_metaBox);
  final SyncQueueStore _syncQueue = SyncQueueStore();
  final SupabaseClient _supabase = Supabase.instance.client;
  late final SupabaseSyncGateway _supabaseGateway;
  late final SyncCoordinator _syncCoordinator;
  late final SupabaseLicenseService _licenseService;
  late final WhatsAppSettingsService _whatsAppSettingsService;
  late final ReferralRemoteService _referralRemoteService;
  late final PendingReferralClaimController _pendingReferralClaims;
  late final Future<bool> _initialReferralCapture;
  ReferralLinkListener? _referralLinkListener;
  Future<void>? _pendingReferralClaimFuture;
  bool _installReferrerAttemptedThisSession = false;
  static const _installReferrerCheckedKey = 'referral:installReferrerChecked';
  final PushTokenRegistrationCoordinator? _pushTokenCoordinator;
  StreamSubscription<AuthState>? _authSubscription;
  bool _hasPendingAuthState = false;
  User? _pendingAuthUser;
  RealtimeChannel? _realtimeChannel;
  Timer? _automaticSyncTimer;
  Timer? _syncDebounceTimer;
  Timer? _retrySyncTimer;
  int _consecutiveSyncFailures = 0;
  bool _syncRequestedWhileRunning = false;
  String? _ensuredProfileFingerprint;
  DateTime? _lastBackgroundRefreshAt;
  DateTime? _lastLicenseRefreshAttemptAt;
  Future<LicenseSnapshot>? _licenseRefreshFuture;
  String? _licenseRefreshUserId;
  final List<DailyRecord> _records = [];
  final List<MaintenanceRecord> _maintenanceRecords = [];
  User? user;
  bool initialized = false;
  bool syncing = false;
  String syncMessage = 'Base local pendiente de respaldo';
  LicenseSnapshot license = LicenseSnapshot.local;
  late WhatsAppSettings whatsAppSettings;
  ReferralProgram? referralProgram;
  List<ReferralEntry> referrals = const [];
  ReferralLoadState referralLoadState = ReferralLoadState.idle;
  String? referralError;
  bool referralClaimNeedsRetry = false;
  String? _referralLoadUserId;
  Future<void>? _referralLoadFuture;

  double? exchangeRate;
  String exchangeRateBaseCurrency = 'USD';
  String exchangeRateChargeCurrency = 'CUP';
  String exchangeRateSource = 'elTOQUE';
  DateTime? exchangeRateUpdatedAt;

  bool get canWrite => license.canWrite;
  bool get isReadOnly => !canWrite;

  void _restoreCachedIdentityAndLicense() {
    final restoredUser = _supabase.auth.currentUser;
    if (restoredUser != null) {
      user = restoredUser;
      license = _licenseService.cachedLicense(restoredUser.id);
      return;
    }

    // Sin una sesión Google activa, el dispositivo vuelve a su espacio local.
    // Nunca mostramos ni reutilizamos la licencia de la cuenta anterior.
    license = LicenseSnapshot.local;
  }

  void _restoreCachedExchangeRate() {
    final cachedRate = _meta.get('exchangeRate:value');
    exchangeRate = cachedRate is num
        ? cachedRate.toDouble()
        : double.tryParse('${cachedRate ?? ''}');

    final base = _meta.get('exchangeRate:base')?.toString().trim();
    final charge = _meta.get('exchangeRate:charge')?.toString().trim();
    final source = _meta.get('exchangeRate:source')?.toString().trim();
    final updated = _meta.get('exchangeRate:updatedAt')?.toString();

    if (base != null && base.isNotEmpty) {
      exchangeRateBaseCurrency = base;
    }
    if (charge != null && charge.isNotEmpty) {
      exchangeRateChargeCurrency = charge;
    }
    if (source != null && source.isNotEmpty) {
      exchangeRateSource = source;
    }
    exchangeRateUpdatedAt =
        updated == null ? null : DateTime.tryParse(updated);
  }

  Future<void> refreshExchangeRate() async {
    if (user == null) return;

    try {
      final response = await _supabase.rpc(
        'get_my_project_exchange_rate',
        params: {'target_project_id': _projectId},
      );

      dynamic rawRow;
      if (response is List && response.isNotEmpty) {
        rawRow = response.first;
      } else if (response is Map) {
        rawRow = response;
      }

      if (rawRow is! Map) return;

      final row = Map<String, dynamic>.from(rawRow);
      final rawRate = row['rate'];

      final rate = rawRate is num
          ? rawRate.toDouble()
          : double.tryParse('${rawRate ?? ''}');

      if (rate == null || rate <= 0) return;

      final base =
          row['base_currency']?.toString().trim();
      final charge =
          row['charge_currency']?.toString().trim();
      final source =
          row['rate_source']?.toString().trim();
      final updated =
          DateTime.tryParse('${row['rate_updated_at'] ?? ''}');

      exchangeRate = rate;

      if (base != null && base.isNotEmpty) {
        exchangeRateBaseCurrency = base;
      }
      if (charge != null && charge.isNotEmpty) {
        exchangeRateChargeCurrency = charge;
      }
      if (source != null && source.isNotEmpty) {
        exchangeRateSource = source;
      }

      exchangeRateUpdatedAt = updated;

      await _meta.putAll({
        'exchangeRate:value': exchangeRate,
        'exchangeRate:base': exchangeRateBaseCurrency,
        'exchangeRate:charge': exchangeRateChargeCurrency,
        'exchangeRate:source': exchangeRateSource,
        'exchangeRate:updatedAt':
            exchangeRateUpdatedAt?.toIso8601String(),
      });

      notifyListeners();
    } catch (_) {
      // La última tasa cacheada permanece visible si no hay conexión.
    }
  }

  void _handleAuthStreamError(Object error, StackTrace stackTrace) {
    syncMessage = 'Sin conexion. La sesion y los datos locales siguen activos';
    notifyListeners();
    _scheduleSyncRetry();
  }

  void handleAppResumed() {
    final now = DateTime.now().toUtc();
    final lastRefresh = _lastBackgroundRefreshAt;
    final forceExpiredLicenseValidation = user != null &&
        LicenseResumeRefreshPolicy.requiresImmediateValidation(license);

    if (forceExpiredLicenseValidation) {
      unawaited(_refreshLicenseIfNeeded(force: true));
    }

    if (lastRefresh != null &&
        now.difference(lastRefresh).compareTo(_resumeRefreshMinInterval) < 0) {
      return;
    }

    _lastBackgroundRefreshAt = now;
    unawaited(refreshWhatsAppSettings());

    if (user == null) return;

    unawaited(_pushTokenCoordinator?.retryForAuthenticatedUser(user!.id));
    if (!forceExpiredLicenseValidation) {
      unawaited(_refreshLicenseIfNeeded());
    }
    unawaited(refreshExchangeRate());
    unawaited(syncNow());
  }

  Future<WhatsAppSettings> refreshWhatsAppSettings() async {
    whatsAppSettings = await _whatsAppSettingsService.refresh();
    notifyListeners();
    return whatsAppSettings;
  }

  Future<void> loadReferrals({bool force = false}) {
    final currentUser = user;
    if (currentUser == null) {
      referralProgram = null;
      referrals = const [];
      referralLoadState = ReferralLoadState.idle;
      referralError = null;
      notifyListeners();
      return Future<void>.value();
    }

    final inFlight = _referralLoadFuture;
    if (inFlight != null && _referralLoadUserId == currentUser.id) {
      return inFlight;
    }
    if (!force && referralLoadState == ReferralLoadState.loaded) {
      return Future<void>.value();
    }

    final future = _loadReferralsForUser(currentUser.id);
    _referralLoadFuture = future;
    _referralLoadUserId = currentUser.id;
    return future.whenComplete(() {
      if (identical(_referralLoadFuture, future)) {
        _referralLoadFuture = null;
        _referralLoadUserId = null;
      }
    });
  }

  Future<void> refreshReferralsAndLicense() async {
    final currentUserId = user?.id;
    if (currentUserId == null) {
      await loadReferrals(force: true);
      return;
    }

    final coordinator = ReferralLicenseRefreshCoordinator(
      refreshReferrals: loadReferrals,
      refreshLicense: ({required bool force}) {
        if (user?.id != currentUserId) return Future.value(license);
        return _refreshLicenseIfNeeded(force: force);
      },
    );
    await coordinator.refresh();
    if (user?.id == currentUserId) notifyListeners();
  }

  Future<void> _loadReferralsForUser(String userId) async {
    referralLoadState = ReferralLoadState.loading;
    referralError = null;
    notifyListeners();
    try {
      final values = await Future.wait<dynamic>([
        _referralRemoteService.loadProgram(),
        _referralRemoteService.loadReferrals(),
      ]);
      if (user?.id != userId) return;
      referralProgram = values[0] as ReferralProgram?;
      referrals = values[1] as List<ReferralEntry>;
      referralLoadState = ReferralLoadState.loaded;
    } catch (_) {
      if (user?.id != userId) return;
      referralLoadState = ReferralLoadState.error;
      referralError = 'No se pudo cargar el programa de referidos.';
    }
    notifyListeners();
  }

  Future<void> retryPendingReferralClaim() async {
    final currentUser = user;
    if (currentUser == null) return;
    await _pendingReferralClaims.allowRetryForUser(currentUser.id);
    referralClaimNeedsRetry = false;
    await _processPendingReferralClaim(currentUser.id);
  }

  Future<void> _processPendingReferralClaim(String userId) async {
    final inFlight = _pendingReferralClaimFuture;
    if (inFlight != null) return inFlight;
    final future = _runPendingReferralClaim(userId);
    _pendingReferralClaimFuture = future;
    try {
      await future;
    } finally {
      if (identical(_pendingReferralClaimFuture, future)) {
        _pendingReferralClaimFuture = null;
      }
    }
  }

  Future<void> _runPendingReferralClaim(String userId) async {
    final result = await _pendingReferralClaims.claimForUser(
      userId: userId,
      claim: _referralRemoteService.claim,
    );
    if (user?.id != userId) return;
    referralClaimNeedsRetry = result == PendingReferralClaimResult.failed;
    if (result == PendingReferralClaimResult.success) {
      await loadReferrals(force: true);
    } else {
      notifyListeners();
    }
  }

  Future<void> _captureReferralUri(Uri uri) async {
    final captured = await _pendingReferralClaims.capture(uri);
    final currentUser = user;
    if (captured && initialized && currentUser != null) {
      await _processPendingReferralClaim(currentUser.id);
    }
  }

  Future<void> _captureInstallReferrer() async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        _installReferrerAttemptedThisSession ||
        _meta.get(_installReferrerCheckedKey) == true) {
      return;
    }
    _installReferrerAttemptedThisSession = true;
    final result = await const AndroidInstallReferrerService().read();
    if (result.status == InstallReferrerStatus.ok) {
      final code = parseInstallReferrerCode(result.installReferrer);
      final captured = await _pendingReferralClaims.captureCode(code);
      await _meta.put(_installReferrerCheckedKey, true);
      final currentUser = user;
      if (captured && initialized && currentUser != null) {
        await _processPendingReferralClaim(currentUser.id);
      }
      return;
    }
    if (result.isDefinitive) {
      await _meta.put(_installReferrerCheckedKey, true);
    }
  }

  WhatsAppContactAction? supportWhatsAppAction() => buildWhatsAppContactAction(
        settings: whatsAppSettings,
        channel: WhatsAppChannel.support,
        variables: _whatsAppVariables(),
      );

  WhatsAppContactAction? paymentWhatsAppAction({
    String? requestedPlan,
    String? contactReason,
  }) =>
      buildWhatsAppContactAction(
        settings: whatsAppSettings,
        channel: WhatsAppChannel.payment,
        variables: _whatsAppVariables(
          requestedPlan: requestedPlan,
          contactReason: contactReason ?? _defaultPaymentContactReason,
        ),
      );

  String get _defaultPaymentContactReason => switch (license.licenseStatus) {
        LicenseStatus.trial || LicenseStatus.pending => 'pagar y activar',
        LicenseStatus.expiring ||
        LicenseStatus.expired ||
        LicenseStatus.suspended ||
        LicenseStatus.revoked =>
          'renovar',
        _ => 'pagar o renovar',
      };

  Map<String, String?> _whatsAppVariables({
    String? requestedPlan,
    String? contactReason,
  }) {
    final expiry = license.expiresAt ?? license.trialEndsAt;
    return {
      'customer_name': profileDisplayName,
      'customer_email': user?.email,
      'license_key': license.licenseKey,
      'application_name': whatsAppSettings.applicationName,
      'current_plan': license.planId,
      'requested_plan': requestedPlan,
      'expires_at': expiry == null
          ? null
          : DateFormat('yyyy-MM-dd').format(expiry.toLocal()),
      'contact_reason': contactReason,
    };
  }

  Future<LicenseSnapshot> refreshLicense() async {
    final currentUser = user;
    if (currentUser == null) {
      license = LicenseSnapshot.local;
      notifyListeners();
      return license;
    }

    final refreshed = await _licenseService.refresh(
      userId: currentUser.id,
      deviceFingerprint: deviceId,
    );

    // El usuario pudo cambiar mientras la petición estaba en curso.
    // Una respuesta vieja nunca debe modificar la cuenta nueva.
    if (user?.id != currentUser.id) return license;

    license = refreshed;
    notifyListeners();
    return license;
  }

  bool get _hasFreshLicenseValidation {
    if (!license.validatedFromServer) return false;

    final validatedAt = license.lastServerValidation;
    if (validatedAt == null) return false;

    final age = DateTime.now().toUtc().difference(validatedAt.toUtc());
    return age.compareTo(Duration.zero) >= 0 &&
        age.compareTo(_licenseValidationInterval) < 0;
  }

  Future<LicenseSnapshot> _refreshLicenseIfNeeded({
    bool force = false,
  }) {
    final currentUserId = user?.id;
    final inFlight = _licenseRefreshFuture;

    if (inFlight != null && _licenseRefreshUserId == currentUserId) {
      return inFlight;
    }

    final now = DateTime.now().toUtc();

    if (!force && _hasFreshLicenseValidation) {
      return Future.value(license);
    }

    final lastAttempt = _lastLicenseRefreshAttemptAt;
    if (!force &&
        lastAttempt != null &&
        now.difference(lastAttempt).compareTo(_licenseRetryInterval) < 0) {
      return Future.value(license);
    }

    _lastLicenseRefreshAttemptAt = now;

    final future = refreshLicense();
    _licenseRefreshFuture = future;
    _licenseRefreshUserId = currentUserId;

    return future.whenComplete(() {
      if (identical(_licenseRefreshFuture, future)) {
        _licenseRefreshFuture = null;
        _licenseRefreshUserId = null;
      }
    });
  }

  Future<void> _requireWriteAccess() async {
    final currentUser = user;
    if (currentUser != null) {
      license = _licenseService.cachedLicense(currentUser.id);
      await _refreshLicenseIfNeeded();
    }

    if (!canWrite) throw ReadOnlyLicenseException(license);
  }

  List<DailyRecord> get records => [..._records]..sort(_compareRecordsDesc);

  List<MaintenanceRecord> get maintenanceRecords => [..._maintenanceRecords]
    ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

  int get pendingSyncCount =>
      _syncQueue.pendingForUser(activeUserId, limit: 100000).length;

  double get maintenanceIntervalKm {
    final value = _meta.get('maintenanceIntervalKm');
    return value == null
        ? _defaultMaintenanceIntervalKm
        : (value as num).toDouble();
  }

  String get deviceId {
    final existing = _meta.get('deviceId');
    if (existing is String && existing.isNotEmpty) return existing;
    final generated =
        'device-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(999999)}';
    _meta.put('deviceId', generated);
    return generated;
  }

  String get localOwnerId {
    final existing = _meta.get('localOwnerId');
    if (existing is String && existing.isNotEmpty) return existing;
    final generated = 'local-owner-$deviceId';
    _meta.put('localOwnerId', generated);
    return generated;
  }

  String get activeUserId {
    final googleUser = user;
    return googleUser?.id ?? localOwnerId;
  }

  String get activeVehicleId {
    final key = 'activeVehicleId:$activeUserId';
    final existing = _meta.get(key);
    if (existing is String && existing.isNotEmpty) return existing;
    final generated = 'vehicle-$activeUserId-primary';
    final now = DateTime.now();
    _meta.put(key, generated);
    _meta.put(
      'vehicle:$generated',
      VehicleProfile(
        id: generated,
        userId: activeUserId,
        name: 'Mi Tuk Tuk',
        createdAt: now,
        updatedAt: now,
        deviceId: deviceId,
        syncStatus: SyncStatus.pending,
      ).toMap(),
    );
    return generated;
  }

  VehicleProfile? _vehicleForUser(String userId) {
    final key = 'activeVehicleId:$userId';
    final vehicleId = _meta.get(key);
    if (vehicleId is! String || vehicleId.isEmpty) return null;
    final raw = _meta.get('vehicle:$vehicleId');
    if (raw is! Map) return null;
    final vehicle = VehicleProfile.fromMap(raw);
    return vehicle.userId == userId ? vehicle : null;
  }

  VehicleProfile? get activeVehicle => _vehicleForUser(activeUserId);

  List<VehicleProfile> get vehicles {
    final ownerId = activeUserId;
    final values = <VehicleProfile>[];
    for (final key in _meta.keys) {
      if (key is! String || !key.startsWith('vehicle:')) continue;
      final raw = _meta.get(key);
      if (raw is! Map) continue;
      final vehicle = VehicleProfile.fromMap(raw);
      if (vehicle.userId == ownerId && !vehicle.isDeleted) values.add(vehicle);
    }
    values.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return values;
  }

  bool get needsOnboarding => initialized && activeVehicle == null;

  DateTime? get lastSyncAt {
    final currentUser = user;
    if (currentUser == null) return null;

    final scoped = _meta.get('lastSyncAt:${currentUser.id}');
    if (scoped != null) return DateTime.tryParse('$scoped');

    // Compatibilidad con instalaciones anteriores al aislamiento por usuario:
    // el valor histórico solo pertenece al usuario que reclamó esos datos.
    final claimed = _meta.get('claimedUserId');
    if (claimed == currentUser.id) {
      final legacy = _meta.get('lastSyncAt');
      return legacy == null ? null : DateTime.tryParse('$legacy');
    }

    return null;
  }

  String get profileDisplayName {
    final custom = _meta.get('profileDisplayName:$activeUserId');
    if (custom is String && custom.trim().isNotEmpty) return custom.trim();
    final googleName =
        user?.userMetadata?['full_name'] ?? user?.userMetadata?['name'];
    if (googleName != null && googleName.trim().isNotEmpty) return googleName;
    final email = user?.email;
    return email == null ? 'Usuario invitado' : email.split('@').first;
  }

  String get preferredCurrency => '${_meta.get('preferredCurrency') ?? 'CUP'}';
  String get preferredLanguage => '${_meta.get('preferredLanguage') ?? 'es'}';
  String get preferredTheme => '${_meta.get('preferredTheme') ?? 'system'}';

  Future<void> setProfileDisplayName(String value) async {
    await _requireWriteAccess();
    final clean = value.trim();
    if (clean.isEmpty) return;
    final previousSettings = _settingsRollbackPayload();
    await _meta.put('profileDisplayName:$activeUserId', clean);
    await _enqueueSettingsSync(previousPayload: previousSettings);
    notifyListeners();
    unawaitedSync();
  }

  Future<void> savePreferences({
    required String currency,
    required String language,
    required String theme,
  }) async {
    await _requireWriteAccess();
    final previousSettings = _settingsRollbackPayload();
    await _meta.putAll({
      'preferredCurrency': currency,
      'preferredLanguage': language,
      'preferredTheme': theme,
    });
    await _enqueueSettingsSync(previousPayload: previousSettings);
    notifyListeners();
    unawaitedSync();
  }

  Map<String, dynamic> _settingsRollbackPayload() => {
        'maintenanceIntervalKm': maintenanceIntervalKm,
        'preferredCurrency': preferredCurrency,
        'preferredLanguage': preferredLanguage,
        'preferredTheme': preferredTheme,
        'profileDisplayName:$activeUserId': profileDisplayName,
        'settingsUpdatedAt':
            '${_meta.get('settingsUpdatedAt') ?? DateTime.now().toIso8601String()}',
      };

  Future<void> _enqueueSettingsSync({
    Map<String, dynamic>? previousPayload,
  }) async {
    await _meta.put('settingsUpdatedAt', DateTime.now().toIso8601String());
    await _syncQueue.enqueue(
      entityType: SyncEntityType.settings,
      entityId: 'app-settings-$activeVehicleId',
      action: SyncAction.upsert,
      userId: activeUserId,
      vehicleId: activeVehicleId,
      previousPayload: previousPayload,
      rollbackOnLicenseRejection: previousPayload != null,
    );
  }

  String exportBackupJson() => const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': _databaseSchemaVersion,
        'app': 'TukTuk Control',
        'kind': 'database-backup',
        'backupId':
            'backup-$activeUserId-${DateTime.now().microsecondsSinceEpoch}',
        'userId': activeUserId,
        'ownerUserId': activeUserId,
        'vehicleId': activeVehicleId,
        'vehicle': activeVehicle?.toMap(),
        'vehicles': vehicles.map((vehicle) => vehicle.toMap()).toList(),
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'settings': {'maintenanceIntervalKm': maintenanceIntervalKm},
        'records': _allDailyRecords
            .where((record) => record.userId == activeUserId)
            .map((record) => record.toMap())
            .toList(),
        'maintenanceRecords': _allMaintenanceRecords
            .where((record) => record.userId == activeUserId)
            .map((record) => record.toMap())
            .toList(),
      });

  String exportBackupCsv() {
    const header =
        'fecha,ingreso,gasto,categoria_gasto,odometro,batteryVoltage,nota';
    String cell(Object? value) =>
        '"${'$value'.replaceAll('"', '""').replaceAll('\n', ' ')}"';
    final rows = records.map((record) => [
          DateFormat('yyyy-MM-dd').format(record.date),
          record.earnings,
          record.expense,
          record.expenseCategory,
          record.odometer,
          record.batteryVoltage ?? '',
          record.note,
        ].map(cell).join(','));
    return [header, ...rows].join('\r\n');
  }

  Future<void> restoreBackupJson(String source) async {
    await _requireWriteAccess();
    final decoded = jsonDecode(source);
    if (decoded is! Map) throw const FormatException('Respaldo no válido');
    await _replaceWithPortableBackup(Map<String, dynamic>.from(decoded));
    _load();
  }

  Future<void> _initialize() async {
    await _initialReferralCapture;
    unawaited(_captureInstallReferrer());
    unawaited(refreshWhatsAppSettings());
    try {
      await _migrateLegacyMaintenance();
      await _migrateSyncMetadata();
      await _seedInitialEarningsIfEmpty();
      await _seedInitialMaintenanceIfEmpty();
      await _seedSyncQueueIfNeeded();
      _load();
    } finally {
      initialized = true;
      notifyListeners();
    }
    final hadPendingAuthState = _hasPendingAuthState;
    final pendingAuthUser = _pendingAuthUser;
    _hasPendingAuthState = false;
    _pendingAuthUser = null;
    if (hadPendingAuthState) {
      unawaited(_handleAuthState(pendingAuthUser));
    } else {
      unawaited(restoreGoogleSession());
    }
  }

  Future<void> configureFirstVehicle({
    required String name,
    String registration = '',
    double initialOdometer = 0,
  }) async {
    await _requireWriteAccess();
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'El nombre es obligatorio.');
    }
    final now = DateTime.now();
    final vehicleId = 'vehicle-$activeUserId-primary';
    final vehicle = VehicleProfile(
      id: vehicleId,
      userId: activeUserId,
      name: cleanName,
      registration: registration.trim(),
      initialOdometer: initialOdometer,
      createdAt: now,
      updatedAt: now,
      deviceId: deviceId,
      syncStatus: SyncStatus.pending,
    );
    await _meta.put('activeVehicleId:$activeUserId', vehicleId);
    await _meta.put('vehicle:$vehicleId', vehicle.toMap());
    await _syncQueue.enqueue(
      entityType: SyncEntityType.vehicle,
      entityId: vehicleId,
      action: SyncAction.upsert,
      userId: activeUserId,
      vehicleId: vehicleId,
      rollbackOnLicenseRejection: true,
    );
    if (initialOdometer > 0 && records.isEmpty) {
      await save(
        DailyRecord(
          id: 'vehicle-setup-${now.microsecondsSinceEpoch}',
          date: DateTime(now.year, now.month, now.day),
          earnings: 0,
          odometer: initialOdometer,
          note: 'Odometro inicial del vehiculo',
        ),
      );
    }
    notifyListeners();
    unawaitedSync();
  }

  /// Prepara soporte multivehículo sin exponer todavía una pantalla de flota.
  Future<VehicleProfile> createVehicle({
    required String name,
    String registration = '',
    double initialOdometer = 0,
  }) async {
    await _requireWriteAccess();
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'El nombre es obligatorio.');
    }
    final now = DateTime.now();
    final vehicleId =
        'vehicle-$activeUserId-${now.microsecondsSinceEpoch}-${Random().nextInt(999999)}';
    final vehicle = VehicleProfile(
      id: vehicleId,
      userId: activeUserId,
      name: cleanName,
      registration: registration.trim(),
      initialOdometer: initialOdometer,
      createdAt: now,
      updatedAt: now,
      deviceId: deviceId,
      syncStatus: SyncStatus.pending,
    );
    await _meta.put('vehicle:$vehicleId', vehicle.toMap());
    await _syncQueue.enqueue(
      entityType: SyncEntityType.vehicle,
      entityId: vehicleId,
      action: SyncAction.upsert,
      userId: activeUserId,
      vehicleId: vehicleId,
      rollbackOnLicenseRejection: true,
    );
    notifyListeners();
    unawaitedSync();
    return vehicle;
  }

  Future<void> selectVehicle(String vehicleId) async {
    VehicleProfile? vehicle;
    for (final item in vehicles) {
      if (item.id == vehicleId) {
        vehicle = item;
        break;
      }
    }
    if (vehicle == null) {
      throw StateError('El vehículo no pertenece al usuario activo.');
    }
    await _meta.put('activeVehicleId:$activeUserId', vehicle.id);
    _load();
  }

  Future<void> updateActiveVehicle({
    required String name,
    String registration = '',
  }) async {
    await _requireWriteAccess();
    final current = activeVehicle;
    final cleanName = name.trim();
    if (current == null || cleanName.isEmpty) return;
    final updated = VehicleProfile(
      id: current.id,
      userId: current.userId,
      name: cleanName,
      registration: registration.trim(),
      initialOdometer: current.initialOdometer,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
      deviceId: current.deviceId.isEmpty ? deviceId : current.deviceId,
      syncStatus: SyncStatus.pending,
    );
    await _meta.put('vehicle:${current.id}', updated.toMap());
    await _syncQueue.enqueue(
      entityType: SyncEntityType.vehicle,
      entityId: current.id,
      action: SyncAction.upsert,
      userId: activeUserId,
      vehicleId: current.id,
      previousPayload: current.toMap(),
      rollbackOnLicenseRejection: true,
    );
    notifyListeners();
    unawaitedSync();
  }

  void _load() {
    final ownerId = activeUserId;
    final vehicleId = activeVehicle?.id;
    _records
      ..clear()
      ..addAll(
        _box.values
            .map((raw) => DailyRecord.fromMap(raw as Map))
            .where(
              (record) =>
                  !record.isDeleted &&
                  record.userId == ownerId &&
                  vehicleId != null &&
                  record.vehicleId == vehicleId,
            )
            .toList(),
      );
    _maintenanceRecords
      ..clear()
      ..addAll(
        _maintenanceBox.values
            .map((raw) => MaintenanceRecord.fromMap(raw as Map))
            .where(
              (record) =>
                  !record.isDeleted &&
                  record.userId == ownerId &&
                  vehicleId != null &&
                  record.vehicleId == vehicleId,
            )
            .toList(),
      );
    notifyListeners();
  }

  List<DailyRecord> get _allDailyRecords =>
      _box.values.map((raw) => DailyRecord.fromMap(raw as Map)).toList();

  List<MaintenanceRecord> get _allMaintenanceRecords => _maintenanceBox.values
      .map((raw) => MaintenanceRecord.fromMap(raw as Map))
      .toList();

  Future<void> _seedSyncQueueIfNeeded() async {
    if (_meta.get('syncQueueV1Seeded') == true) return;
    for (final record in _allDailyRecords) {
      await _syncQueue.enqueue(
        entityType: SyncEntityType.dailyRecord,
        entityId: record.id,
        action: record.isDeleted ? SyncAction.delete : SyncAction.upsert,
        userId: record.userId,
        vehicleId: record.vehicleId,
      );
    }
    for (final record in _allMaintenanceRecords) {
      await _syncQueue.enqueue(
        entityType: SyncEntityType.maintenance,
        entityId: record.id,
        action: record.isDeleted ? SyncAction.delete : SyncAction.upsert,
        userId: record.userId,
        vehicleId: record.vehicleId,
      );
    }
    for (final vehicle in vehicles) {
      await _syncQueue.enqueue(
        entityType: SyncEntityType.vehicle,
        entityId: vehicle.id,
        action: SyncAction.upsert,
        userId: vehicle.userId,
        vehicleId: vehicle.id,
      );
    }
    await _meta.put('syncQueueV1Seeded', true);
  }

  Future<void> _migrateLegacyMaintenance() async {
    if (_maintenanceBox.isNotEmpty) return;
    final legacy = (_meta.get('maintenanceRecords') as List?) ?? [];
    if (legacy.isEmpty) return;
    for (final raw in legacy) {
      final record = MaintenanceRecord.fromMap(raw as Map)
          .withSyncInfo(deviceId: deviceId);
      await _maintenanceBox.put(record.id, record.toMap());
    }
    await _meta.delete('maintenanceRecords');
  }

  Future<void> _migrateSyncMetadata() async {
    for (final key in _meta.keys.toList()) {
      if (key is! String || !key.startsWith('vehicle:')) continue;
      final raw = _meta.get(key);
      if (raw is! Map) continue;
      final vehicle = VehicleProfile.fromMap(raw);
      if (vehicle.schemaVersion < _databaseSchemaVersion ||
          vehicle.deviceId.isEmpty) {
        await _meta.put(
          key,
          vehicle.withSyncInfo(deviceId: deviceId).toMap(),
        );
      }
    }
    for (final record in _allDailyRecords) {
      final raw = _box.get(record.id);
      final hasLegacyVoltage = raw is Map &&
          (raw.containsKey('batteryPercent') ||
              raw.containsKey('chargeTo80v') ||
              (!raw.containsKey('batteryVoltage') &&
                  RegExp(r'\bVoltaje\s*:', caseSensitive: false)
                      .hasMatch('${raw['note'] ?? ''}')));
      if (record.schemaVersion < _databaseSchemaVersion ||
          hasLegacyVoltage ||
          record.deviceId.isEmpty ||
          record.userId.isEmpty ||
          record.vehicleId.isEmpty) {
        final migrated = record.withSyncInfo(
          deviceId: deviceId,
          userId: record.userId.isEmpty ? localOwnerId : null,
          vehicleId: record.vehicleId.isEmpty ? activeVehicleId : null,
        );
        await _box.put(migrated.id, migrated.toMap());
      }
    }
    for (final record in _allMaintenanceRecords) {
      if (record.schemaVersion < _databaseSchemaVersion ||
          record.deviceId.isEmpty ||
          record.userId.isEmpty ||
          record.vehicleId.isEmpty) {
        final migrated = record.withSyncInfo(
          deviceId: deviceId,
          userId: record.userId.isEmpty ? localOwnerId : null,
          vehicleId: record.vehicleId.isEmpty ? activeVehicleId : null,
        );
        await _maintenanceBox.put(migrated.id, migrated.toMap());
      }
    }
    await _meta.put('databaseSchemaVersion', _databaseSchemaVersion);
  }

  Future<void> _seedInitialEarningsIfEmpty() async {
    final currentSeedVersion = _meta.get('seedVersion');
    if (!OwnershipPolicy.shouldLoadHistoricalSeed(currentSeedVersion)) return;
    final canReplaceSeed = _box.isEmpty ||
        (_box.values.isNotEmpty &&
            _box.values.every((raw) {
              final map = raw as Map;
              return map['note'] == 'Carga inicial de ganancias' ||
                  map['note'] == 'Carga hasta 80 V';
            }));
    if (currentSeedVersion == _seedVersion || !canReplaceSeed) return;
    await _box.clear();
    for (var i = 0; i < _initialRecords.length; i++) {
      final item = _initialRecords[i];
      final record = DailyRecord(
        id: 'seed-${item.date.toIso8601String()}-${item.earnings}-${item.odometer}-$i',
        date: item.date,
        earnings: item.earnings,
        odometer: item.odometer,
        batteryVoltage: item.batteryVoltage,
        note: item.earnings > 0 ? 'Carga inicial de ganancias' : '',
      ).withSyncInfo(
        deviceId: deviceId,
        userId: localOwnerId,
        vehicleId: activeVehicleId,
      );
      await _box.put(record.id, record.toMap());
    }
    await _meta.put('seedVersion', _seedVersion);
    await _seedInitialMaintenanceIfEmpty();
    _load();
  }

  Future<void> _seedInitialMaintenanceIfEmpty() async {
    if (_maintenanceBox.isNotEmpty) return;
    if (!OwnershipPolicy.shouldLoadHistoricalSeed(_meta.get('seedVersion'))) {
      return;
    }
    await _meta.put('maintenanceIntervalKm', _defaultMaintenanceIntervalKm);
    final record = MaintenanceRecord(
      id: 'maintenance-seed-2026-03-14',
      dateTime: DateTime(2026, 3, 14, 9),
      odometer: 526,
      type: 'General',
      description: 'Mantenimiento general registrado',
      notes: 'Base para calcular el proximo mantenimiento cada 5,000 km.',
    ).withSyncInfo(
      deviceId: deviceId,
      userId: localOwnerId,
      vehicleId: activeVehicleId,
    );
    await _maintenanceBox.put(record.id, record.toMap());
  }

  Future<void> save(DailyRecord record) async {
    await _requireWriteAccess();
    final previousRaw = _box.get(record.id);
    final normalized = record.withSyncInfo(
      deviceId: deviceId,
      userId: activeUserId,
      vehicleId: activeVehicleId,
      syncStatus: SyncStatus.pending,
      updatedAt: DateTime.now(),
    );
    await _box.put(normalized.id, normalized.toMap());
    await _syncQueue.enqueue(
      entityType: SyncEntityType.dailyRecord,
      entityId: normalized.id,
      action: SyncAction.upsert,
      userId: normalized.userId,
      vehicleId: normalized.vehicleId,
      previousPayload:
          previousRaw is Map ? Map<String, dynamic>.from(previousRaw) : null,
      rollbackOnLicenseRejection: true,
    );
    _load();
    unawaitedSync();
  }

  Future<void> delete(String id) async {
    await _requireWriteAccess();
    final raw = _box.get(id);
    if (raw != null) {
      final record = DailyRecord.fromMap(raw as Map).withSyncInfo(
        deviceId: deviceId,
        userId: activeUserId,
        vehicleId: activeVehicleId,
        syncStatus: SyncStatus.pending,
        updatedAt: DateTime.now(),
        deletedAt: DateTime.now(),
      );
      await _box.put(record.id, record.toMap());
      await _syncQueue.enqueue(
        entityType: SyncEntityType.dailyRecord,
        entityId: record.id,
        action: SyncAction.delete,
        userId: record.userId,
        vehicleId: record.vehicleId,
        previousPayload: Map<String, dynamic>.from(raw),
        rollbackOnLicenseRejection: true,
      );
    }
    _load();
    unawaitedSync();
  }

  Future<void> saveMaintenance(MaintenanceRecord record) async {
    await _requireWriteAccess();
    final previousRaw = _maintenanceBox.get(record.id);
    final normalized = record.withSyncInfo(
      deviceId: deviceId,
      userId: activeUserId,
      vehicleId: activeVehicleId,
      syncStatus: SyncStatus.pending,
      updatedAt: DateTime.now(),
    );
    await _maintenanceBox.put(normalized.id, normalized.toMap());
    await _syncQueue.enqueue(
      entityType: SyncEntityType.maintenance,
      entityId: normalized.id,
      action: SyncAction.upsert,
      userId: normalized.userId,
      vehicleId: normalized.vehicleId,
      previousPayload:
          previousRaw is Map ? Map<String, dynamic>.from(previousRaw) : null,
      rollbackOnLicenseRejection: true,
    );
    _load();
    unawaitedSync();
  }

  Future<void> deleteMaintenance(String id) async {
    await _requireWriteAccess();
    final raw = _maintenanceBox.get(id);
    if (raw != null) {
      final record = MaintenanceRecord.fromMap(raw as Map).withSyncInfo(
        deviceId: deviceId,
        userId: activeUserId,
        vehicleId: activeVehicleId,
        syncStatus: SyncStatus.pending,
        updatedAt: DateTime.now(),
        deletedAt: DateTime.now(),
      );
      await _maintenanceBox.put(record.id, record.toMap());
      await _syncQueue.enqueue(
        entityType: SyncEntityType.maintenance,
        entityId: record.id,
        action: SyncAction.delete,
        userId: record.userId,
        vehicleId: record.vehicleId,
        previousPayload: Map<String, dynamic>.from(raw),
        rollbackOnLicenseRejection: true,
      );
    }
    _load();
    unawaitedSync();
  }

  Future<void> setMaintenanceInterval(double intervalKm) async {
    await _requireWriteAccess();
    final previousSettings = _settingsRollbackPayload();
    await _meta.put('maintenanceIntervalKm', intervalKm);
    await _enqueueSettingsSync(previousPayload: previousSettings);
    _load();
    unawaitedSync();
  }

  Future<void> signIn() async {
    syncMessage = 'Abriendo acceso seguro con Google...';
    notifyListeners();
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? webOAuthRedirect(Uri.base) : _supabaseMobileRedirect,
      authScreenLaunchMode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
  }

  Future<void> restoreGoogleSession() async {
    await _handleAuthState(_supabase.auth.currentUser);
  }

  Future<void> signOut() async {
    _stopAutomaticSync();
    final currentUser = user;
    if (currentUser != null) {
      await _pushTokenCoordinator?.unregisterBeforeSignOut(currentUser.id);
    }
    await _supabase.auth.signOut();
    user = null;
    _load();
    await refreshLicense();
    syncMessage = 'Sesion cerrada. La base local sigue en este dispositivo';
    notifyListeners();
  }

  Future<void> restoreThenSync() async {
    await syncNow();
  }

  Future<void> syncNow() async {
    await _withSync(() async {
      if (user == null) return;
      await _refreshLicenseIfNeeded();
      if (activeVehicle == null) {
        syncMessage = 'Configura tu primer vehiculo para comenzar';
        return;
      }
      await _synchronizeWithSupabase();
      syncMessage = !canWrite
          ? 'Tu licencia no permite realizar cambios. Modo solo lectura'
          : pendingSyncCount == 0
              ? 'Datos sincronizados de forma segura'
              : 'Cambios guardados localmente, pendientes de conexion';
    });
  }

  void unawaitedSync() {
    if (user == null) return;
    if (syncing) {
      _syncRequestedWhileRunning = true;
      return;
    }
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(
      const Duration(milliseconds: 900),
      () => unawaited(syncNow()),
    );
  }

  Future<void> _withSync(Future<void> Function() action) async {
    if (syncing) {
      _syncRequestedWhileRunning = true;
      return;
    }
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = null;
    final syncingUserId = user?.id;
    syncing = true;
    syncMessage = 'Sincronizando...';
    notifyListeners();
    try {
      await action();
      _consecutiveSyncFailures = 0;
      _retrySyncTimer?.cancel();
      _retrySyncTimer = null;
      if (syncingUserId != null) {
        await _meta.put(
          'lastSyncAt:$syncingUserId',
          DateTime.now().toIso8601String(),
        );
      }
    } catch (_) {
      syncMessage = 'Sin conexion. Los cambios permanecen guardados';
      _scheduleSyncRetry();
    } finally {
      syncing = false;
      notifyListeners();
      if (_syncRequestedWhileRunning && user != null) {
        _syncRequestedWhileRunning = false;
        unawaitedSync();
      }
    }
  }

  Future<void> _handleAuthState(User? authenticatedUser) async {
    if (authenticatedUser == null) {
      user = null;
      referralProgram = null;
      referrals = const [];
      referralLoadState = ReferralLoadState.idle;
      referralError = null;
      referralClaimNeedsRetry = false;
      _stopAutomaticSync();
      _load();
      await refreshLicense();
      if (initialized) {
        syncMessage = 'Entra con Google para activar la sincronizacion';
        notifyListeners();
      }
      return;
    }
    if (user?.id != authenticatedUser.id) {
      referralProgram = null;
      referrals = const [];
      referralLoadState = ReferralLoadState.idle;
      referralError = null;
      referralClaimNeedsRetry = false;
    }
    user = authenticatedUser;
    license = _licenseService.cachedLicense(authenticatedUser.id);
    notifyListeners();
    unawaited(refreshExchangeRate());
    _startAutomaticSync();
    try {
      await _pushTokenCoordinator
          ?.handleAuthenticatedUser(authenticatedUser.id);
      await _ensureRemoteProfile();
      await _processPendingReferralClaim(authenticatedUser.id);
      await _refreshLicenseIfNeeded(force: true);

      if (canWrite) {
        await _claimLocalDataForSignedInUser();
      }

      // Los datos remotos deben restaurarse tambien en modo solo lectura.
      // Una licencia sin permiso de escritura no debe impedir consultar
      // el vehiculo y los registros que ya existen en Supabase.
      if (activeVehicle == null) {
        await _synchronizeWithSupabase();
      }

      // Solo un usuario realmente nuevo y con permiso de escritura
      // recibe un vehiculo inicial.
      if (canWrite && activeVehicle == null) {
        await configureFirstVehicle(name: 'Mi Tuk Tuk');
      }

      await syncNow();
    } catch (_) {
      syncMessage = 'Sin conexion. Trabajando con los datos locales';
      notifyListeners();
      _scheduleSyncRetry();
    }
  }

  void _scheduleSyncRetry() {
    if (user == null || _retrySyncTimer?.isActive == true) return;
    _consecutiveSyncFailures = min(_consecutiveSyncFailures + 1, 6);
    const delays = <Duration>[
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 30),
      Duration(minutes: 1),
      Duration(minutes: 2),
      Duration(minutes: 5),
    ];
    _retrySyncTimer = Timer(
      delays[_consecutiveSyncFailures - 1],
      () {
        _retrySyncTimer = null;
        unawaited(syncNow());
      },
    );
  }

  void _startAutomaticSync() {
    _stopAutomaticSync();
    final currentUser = user;
    if (currentUser == null) return;
    _realtimeChannel = _supabase
        .channel('sync:${currentUser.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseSyncGateway.tableName,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: currentUser.id,
          ),
          callback: (_) => unawaitedSync(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'licenses',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: currentUser.id,
          ),
          callback: (_) =>
              unawaited(_refreshLicenseIfNeeded(force: true)),
        )
        .subscribe();

    _automaticSyncTimer = Timer.periodic(
      _automaticSyncInterval,
      (_) {
        unawaited(_refreshLicenseIfNeeded());
        unawaited(refreshWhatsAppSettings());
        unawaited(refreshExchangeRate());
        unawaitedSync();
      },
    );
  }

  void _stopAutomaticSync() {
    _automaticSyncTimer?.cancel();
    _automaticSyncTimer = null;
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = null;
    _retrySyncTimer?.cancel();
    _retrySyncTimer = null;
    _consecutiveSyncFailures = 0;
    _syncRequestedWhileRunning = false;
    _ensuredProfileFingerprint = null;
    _lastBackgroundRefreshAt = null;
    _lastLicenseRefreshAttemptAt = null;
    _licenseRefreshUserId = null;
    final channel = _realtimeChannel;
    _realtimeChannel = null;
    if (channel != null) unawaited(_supabase.removeChannel(channel));
  }

  Map<String, dynamic>? _payloadForOperation(SyncOperation operation) {
    switch (operation.entityType) {
      case SyncEntityType.dailyRecord:
        final raw = _box.get(operation.entityId);
        return raw is Map ? Map<String, dynamic>.from(raw) : null;
      case SyncEntityType.maintenance:
        final raw = _maintenanceBox.get(operation.entityId);
        return raw is Map ? Map<String, dynamic>.from(raw) : null;
      case SyncEntityType.vehicle:
        final raw = _meta.get('vehicle:${operation.entityId}');
        return raw is Map ? Map<String, dynamic>.from(raw) : null;
      case SyncEntityType.settings:
        final settingsUpdatedAt =
            DateTime.tryParse('${_meta.get('settingsUpdatedAt')}') ??
                operation.updatedAt;
        return {
          'id': operation.entityId,
          'userId': operation.userId,
          'vehicleId': operation.vehicleId,
          'deviceId': deviceId,
          'maintenanceIntervalKm': maintenanceIntervalKm,
          'preferredCurrency': preferredCurrency,
          'preferredLanguage': preferredLanguage,
          'preferredTheme': preferredTheme,
          'profileDisplayName': profileDisplayName,
          'createdAt': operation.createdAt.toIso8601String(),
          'updatedAt': settingsUpdatedAt.toIso8601String(),
          'deletedAt': null,
        };
    }
  }

  Future<void> _synchronizeWithSupabase() async {
    final currentUser = user;
    if (currentUser == null) return;
    await _ensureRemoteProfile();
    final cursorKey = 'supabaseCursor:${currentUser.id}';
    var cursor = _meta.get(cursorKey)?.toString();
    var pageCount = 0;
    var hasMore = true;
    while (hasMore && pageCount < 100) {
      final remote = await _supabaseGateway.pull(
        userId: currentUser.id,
        cursor: cursor,
      );
      await _applyRemoteChanges(remote.changes);
      if (remote.nextCursor != null) {
        cursor = remote.nextCursor;
        await _meta.put(cursorKey, cursor);
      }
      hasMore = remote.hasMore && remote.changes.isNotEmpty;
      pageCount++;
    }

    final pendingBatch = _syncQueue.pendingForUser(
      currentUser.id,
      limit: 500,
    );
    if (!canWrite) {
      _load();
      return;
    }
    final report = await _syncCoordinator.pushPending(
      userId: currentUser.id,
      batchSize: 500,
    );
    for (final operation in pendingBatch) {
      if (report.completedOperationIds.contains(operation.id)) {
        await _markEntitySynced(operation);
      }
    }
    if (report.blockedByLicense) {
      await _licenseService.markWriteRejected(
        currentUser.id,
        const LicenseWriteRejectedException('RLS rejected write'),
      );
      await refreshLicense();
      await _rollbackBlockedOperations(
        pendingBatch.where(
          (operation) =>
              report.blockedOperationIds.contains(operation.id) &&
              operation.rollbackOnLicenseRejection,
        ),
      );
      syncMessage =
          'Tu licencia no permite realizar cambios. Modo solo lectura';
    }
    _load();
    if (report.failed > 0 && !report.blockedByLicense) {
      throw const TemporarySyncException('remote push failed');
    }
  }

  Future<void> _rollbackBlockedOperations(
    Iterable<SyncOperation> operations,
  ) async {
    for (final operation in operations) {
      final previous = operation.previousPayload;
      switch (operation.entityType) {
        case SyncEntityType.dailyRecord:
          if (previous == null) {
            await _box.delete(operation.entityId);
          } else {
            await _box.put(operation.entityId, previous);
          }
          break;
        case SyncEntityType.maintenance:
          if (previous == null) {
            await _maintenanceBox.delete(operation.entityId);
          } else {
            await _maintenanceBox.put(operation.entityId, previous);
          }
          break;
        case SyncEntityType.vehicle:
          if (previous == null) {
            await _meta.delete('vehicle:${operation.entityId}');
          } else {
            await _meta.put('vehicle:${operation.entityId}', previous);
          }
          break;
        case SyncEntityType.settings:
          if (previous != null) await _meta.putAll(previous);
          break;
      }
    }
    _load();
  }

  Future<void> _ensureRemoteProfile() async {
    final currentUser = user;
    if (currentUser == null) return;
    final metadata = currentUser.userMetadata ?? const <String, dynamic>{};
    final profile = {
      'id': currentUser.id,
      'email': currentUser.email,
      'display_name': metadata['full_name'] ??
          metadata['name'] ??
          currentUser.email?.split('@').first,
      'avatar_url': metadata['avatar_url'] ?? metadata['picture'],
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final fingerprint = jsonEncode({
      'id': profile['id'],
      'email': profile['email'],
      'display_name': profile['display_name'],
      'avatar_url': profile['avatar_url'],
    });
    if (_ensuredProfileFingerprint == fingerprint) return;
    final existing = await _supabase
        .from('profiles')
        .select('id')
        .eq('id', currentUser.id)
        .maybeSingle();
    if (existing == null) {
      await _supabase.from('profiles').insert(profile);
    }
    _ensuredProfileFingerprint = fingerprint;
  }

  Future<void> _applyRemoteChanges(List<RemoteChange> changes) async {
    final currentUser = user;
    if (currentUser == null) return;
    for (final change in changes) {
      if (change.userId != currentUser.id) continue;
      final operationId = '${change.entityType.name}:${change.entityId}';
      switch (change.entityType) {
        case SyncEntityType.dailyRecord:
          final remote = DailyRecord.fromMap(change.payload);
          final raw = _box.get(change.entityId);
          final local = raw is Map ? DailyRecord.fromMap(raw) : null;
          if (_remoteWins(
              local?.updatedAt, local?.deviceId, local?.deletedAt, change)) {
            await _box.put(
              remote.id,
              remote
                  .withSyncInfo(
                    deviceId: change.deviceId,
                    userId: change.userId,
                    vehicleId: change.vehicleId,
                    syncStatus: SyncStatus.synced,
                    updatedAt: change.updatedAt,
                    deletedAt: change.deletedAt,
                  )
                  .toMap(),
            );
            await _syncQueue.complete([operationId]);
          }
          break;
        case SyncEntityType.maintenance:
          final remote = MaintenanceRecord.fromMap(change.payload);
          final raw = _maintenanceBox.get(change.entityId);
          final local = raw is Map ? MaintenanceRecord.fromMap(raw) : null;
          if (_remoteWins(
              local?.updatedAt, local?.deviceId, local?.deletedAt, change)) {
            await _maintenanceBox.put(
              remote.id,
              remote
                  .withSyncInfo(
                    deviceId: change.deviceId,
                    userId: change.userId,
                    vehicleId: change.vehicleId,
                    syncStatus: SyncStatus.synced,
                    updatedAt: change.updatedAt,
                    deletedAt: change.deletedAt,
                  )
                  .toMap(),
            );
            await _syncQueue.complete([operationId]);
          }
          break;
        case SyncEntityType.vehicle:
          final remote = VehicleProfile.fromMap(change.payload);
          final raw = _meta.get('vehicle:${change.entityId}');
          final local = raw is Map ? VehicleProfile.fromMap(raw) : null;
          if (_remoteWins(
              local?.updatedAt, local?.deviceId, local?.deletedAt, change)) {
            await _meta.put(
              'vehicle:${remote.id}',
              remote
                  .withSyncInfo(
                    deviceId: change.deviceId,
                    userId: change.userId,
                    syncStatus: SyncStatus.synced,
                    updatedAt: change.updatedAt,
                    deletedAt: change.deletedAt,
                  )
                  .toMap(),
            );
            await _meta.put(
              'activeVehicleId:${change.userId}',
              change.vehicleId,
            );
            await _syncQueue.complete([operationId]);
          }
          break;
        case SyncEntityType.settings:
          final payload = change.payload;
          final localUpdatedAt =
              DateTime.tryParse('${_meta.get('settingsUpdatedAt')}');
          if (!_remoteWins(localUpdatedAt, deviceId, null, change)) break;
          await _meta.putAll({
            'maintenanceIntervalKm':
                (payload['maintenanceIntervalKm'] as num?)?.toDouble() ??
                    maintenanceIntervalKm,
            'preferredCurrency':
                '${payload['preferredCurrency'] ?? preferredCurrency}',
            'preferredLanguage':
                '${payload['preferredLanguage'] ?? preferredLanguage}',
            'preferredTheme': '${payload['preferredTheme'] ?? preferredTheme}',
            'profileDisplayName:${change.userId}':
                '${payload['profileDisplayName'] ?? profileDisplayName}',
            'settingsUpdatedAt': change.updatedAt.toIso8601String(),
          });
          await _syncQueue.complete([operationId]);
          break;
      }
    }
    _load();
  }

  bool _remoteWins(
    DateTime? localUpdatedAt,
    String? localDeviceId,
    DateTime? localDeletedAt,
    RemoteChange remote,
  ) {
    if (localUpdatedAt == null) return true;
    return ConflictResolver.resolve(
          local: ConflictCandidate(
            updatedAt: localUpdatedAt,
            deviceId: localDeviceId ?? '',
            deletedAt: localDeletedAt,
          ),
          remote: ConflictCandidate(
            updatedAt: remote.updatedAt,
            deviceId: remote.deviceId,
            deletedAt: remote.deletedAt,
          ),
        ) ==
        ConflictWinner.remote;
  }

  Future<void> _markEntitySynced(SyncOperation operation) async {
    switch (operation.entityType) {
      case SyncEntityType.dailyRecord:
        final raw = _box.get(operation.entityId);
        if (raw is Map) {
          final record = DailyRecord.fromMap(raw);
          await _box.put(
            record.id,
            record
                .withSyncInfo(
                  deviceId: deviceId,
                  syncStatus: SyncStatus.synced,
                )
                .toMap(),
          );
        }
        break;
      case SyncEntityType.maintenance:
        final raw = _maintenanceBox.get(operation.entityId);
        if (raw is Map) {
          final record = MaintenanceRecord.fromMap(raw);
          await _maintenanceBox.put(
            record.id,
            record
                .withSyncInfo(
                  deviceId: deviceId,
                  syncStatus: SyncStatus.synced,
                )
                .toMap(),
          );
        }
        break;
      case SyncEntityType.vehicle:
        final raw = _meta.get('vehicle:${operation.entityId}');
        if (raw is Map) {
          final vehicle = VehicleProfile.fromMap(raw);
          await _meta.put(
            'vehicle:${vehicle.id}',
            vehicle
                .withSyncInfo(
                  deviceId: deviceId,
                  syncStatus: SyncStatus.synced,
                )
                .toMap(),
          );
        }
        break;
      case SyncEntityType.settings:
        break;
    }
  }

  _PortableBackup _preparePortableBackup(Map<String, dynamic> remote) {
    final rawRecords = remote['records'];
    if (rawRecords is! List) {
      throw const FormatException('El respaldo no contiene registros válidos.');
    }
    final ownerId = activeUserId;
    final currentDeviceId = deviceId;
    final targetVehicleId = activeVehicle?.id ?? 'vehicle-$ownerId-primary';
    final now = DateTime.now();
    final rawVehicles = <Map>[
      if (remote['vehicles'] is List)
        ...(remote['vehicles'] as List).map((raw) {
          if (raw is! Map) throw const FormatException('Vehículo no válido.');
          return raw;
        }),
      if (remote['vehicles'] is! List && remote['vehicle'] is Map)
        remote['vehicle'] as Map,
    ];
    final sourceVehicle =
        rawVehicles.isEmpty ? null : VehicleProfile.fromMap(rawVehicles.first);
    final vehicle = VehicleProfile(
      id: targetVehicleId,
      userId: ownerId,
      name: sourceVehicle?.name ?? activeVehicle?.name ?? 'Mi Tuk Tuk',
      registration:
          sourceVehicle?.registration ?? activeVehicle?.registration ?? '',
      initialOdometer:
          sourceVehicle?.initialOdometer ?? activeVehicle?.initialOdometer ?? 0,
      createdAt: sourceVehicle?.createdAt ?? activeVehicle?.createdAt ?? now,
      updatedAt: sourceVehicle?.updatedAt ?? now,
      deviceId: currentDeviceId,
      syncStatus: SyncStatus.pending,
      deletedAt: sourceVehicle?.deletedAt,
    );
    final records = rawRecords.map((raw) {
      if (raw is! Map) throw const FormatException('Registro no válido.');
      final record = DailyRecord.fromMap(raw);
      if (record.id.isEmpty || record.id == 'null') {
        throw const FormatException('Registro sin identificador.');
      }
      return _adaptDailyRecord(
        record,
        userId: ownerId,
        vehicleId: targetVehicleId,
        deviceId: currentDeviceId,
      );
    }).toList();
    final rawMaintenance = remote['maintenanceRecords'];
    if (rawMaintenance != null && rawMaintenance is! List) {
      throw const FormatException('Mantenimientos no válidos.');
    }
    final maintenanceRecords = (rawMaintenance as List? ?? []).map((raw) {
      if (raw is! Map) throw const FormatException('Mantenimiento no válido.');
      final record = MaintenanceRecord.fromMap(raw);
      if (record.id.isEmpty || record.id == 'null') {
        throw const FormatException('Mantenimiento sin identificador.');
      }
      return _adaptMaintenanceRecord(
        record,
        userId: ownerId,
        vehicleId: targetVehicleId,
        deviceId: currentDeviceId,
      );
    }).toList();
    final settings =
        remote['settings'] is Map ? remote['settings'] as Map : remote;
    final interval = settings['maintenanceIntervalKm'] == null
        ? maintenanceIntervalKm
        : (settings['maintenanceIntervalKm'] as num).toDouble();
    return _PortableBackup(
      vehicle: vehicle,
      records: records,
      maintenanceRecords: maintenanceRecords,
      maintenanceIntervalKm: interval,
    );
  }

  Future<void> _replaceWithPortableBackup(Map<String, dynamic> remote) async {
    final backup = _preparePortableBackup(remote);
    final recordsSnapshot = Map<dynamic, dynamic>.from(_box.toMap());
    final maintenanceSnapshot =
        Map<dynamic, dynamic>.from(_maintenanceBox.toMap());
    final metaSnapshot = Map<dynamic, dynamic>.from(_meta.toMap());
    final queueBox = Hive.box(_syncQueueBox);
    final queueSnapshot = Map<dynamic, dynamic>.from(queueBox.toMap());
    try {
      await _box.clear();
      await _maintenanceBox.clear();
      await queueBox.clear();
      for (final key in _meta.keys.toList()) {
        if (key is String &&
            (key.startsWith('vehicle:') ||
                key.startsWith('activeVehicleId:'))) {
          await _meta.delete(key);
        }
      }
      await _meta.put('activeVehicleId:$activeUserId', backup.vehicle.id);
      await _meta.put('vehicle:${backup.vehicle.id}', backup.vehicle.toMap());
      await _meta.put('maintenanceIntervalKm', backup.maintenanceIntervalKm);
      await _meta.put('databaseSchemaVersion', _databaseSchemaVersion);
      for (final record in backup.records) {
        await _box.put(record.id, record.toMap());
      }
      for (final record in backup.maintenanceRecords) {
        await _maintenanceBox.put(record.id, record.toMap());
      }
      await _seedSyncQueueIfNeededAfterRestore(backup);
    } catch (_) {
      await _box.clear();
      await _box.putAll(recordsSnapshot);
      await _maintenanceBox.clear();
      await _maintenanceBox.putAll(maintenanceSnapshot);
      await _meta.clear();
      await _meta.putAll(metaSnapshot);
      await queueBox.clear();
      await queueBox.putAll(queueSnapshot);
      _load();
      rethrow;
    }
  }

  Future<void> _seedSyncQueueIfNeededAfterRestore(
      _PortableBackup backup) async {
    await _syncQueue.enqueue(
      entityType: SyncEntityType.vehicle,
      entityId: backup.vehicle.id,
      action: SyncAction.upsert,
      userId: activeUserId,
      vehicleId: backup.vehicle.id,
    );
    for (final record in backup.records) {
      await _syncQueue.enqueue(
        entityType: SyncEntityType.dailyRecord,
        entityId: record.id,
        action: record.isDeleted ? SyncAction.delete : SyncAction.upsert,
        userId: activeUserId,
        vehicleId: backup.vehicle.id,
      );
    }
    for (final record in backup.maintenanceRecords) {
      await _syncQueue.enqueue(
        entityType: SyncEntityType.maintenance,
        entityId: record.id,
        action: record.isDeleted ? SyncAction.delete : SyncAction.upsert,
        userId: activeUserId,
        vehicleId: backup.vehicle.id,
      );
    }
  }

  DailyRecord _adaptDailyRecord(
    DailyRecord record, {
    required String userId,
    required String vehicleId,
    required String deviceId,
  }) {
    return DailyRecord(
      id: record.id,
      date: record.date,
      earnings: record.earnings,
      odometer: record.odometer,
      expense: record.expense,
      expenseCategory: record.expenseCategory,
      batteryVoltage: record.batteryVoltage,
      note: record.note,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      deletedAt: record.deletedAt,
      deviceId: deviceId,
      userId: userId,
      vehicleId: vehicleId,
      syncStatus: SyncStatus.pending,
    );
  }

  MaintenanceRecord _adaptMaintenanceRecord(
    MaintenanceRecord record, {
    required String userId,
    required String vehicleId,
    required String deviceId,
  }) {
    return MaintenanceRecord(
      id: record.id,
      dateTime: record.dateTime,
      odometer: record.odometer,
      type: record.type,
      description: record.description,
      cost: record.cost,
      notes: record.notes,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      deletedAt: record.deletedAt,
      deviceId: deviceId,
      userId: userId,
      vehicleId: vehicleId,
      syncStatus: SyncStatus.pending,
    );
  }

  Future<void> _claimLocalDataForSignedInUser() async {
    final googleUser = user;
    if (googleUser == null) return;
    final legacyClaimed = _meta.get('claimedUserId');
    final supabaseClaimed = _meta.get('supabaseClaimedUserId');
    final claimedUserId =
        supabaseClaimed is String && supabaseClaimed.isNotEmpty
            ? supabaseClaimed
            : legacyClaimed is String && legacyClaimed.isNotEmpty
                ? legacyClaimed
                : null;

    if (!OwnershipPolicy.canClaimLocalData(
      claimedUserId,
      googleUser.id,
    )) {
      // Este dispositivo ya contiene datos de otra cuenta.
      // Se conservan intactos y la cuenta nueva usa exclusivamente
      // sus propios datos locales/remotos.
      _load();
      return;
    }

    final targetUserId = googleUser.id;
    final targetVehicleId = 'vehicle-$targetUserId-primary';
    final sourceOwners = <String>{localOwnerId};
    if (legacyClaimed is String && legacyClaimed.isNotEmpty) {
      sourceOwners.add(legacyClaimed);
    }
    final sourceVehicle = legacyClaimed is String
        ? _vehicleForUser(legacyClaimed) ?? _vehicleForUser(localOwnerId)
        : _vehicleForUser(localOwnerId);
    for (final record in _allDailyRecords) {
      if (record.userId.isEmpty || sourceOwners.contains(record.userId)) {
        final migrated = record.withSyncInfo(
          deviceId: deviceId,
          userId: targetUserId,
          vehicleId: targetVehicleId,
          syncStatus: SyncStatus.pending,
        );
        await _box.put(migrated.id, migrated.toMap());
      }
    }
    for (final record in _allMaintenanceRecords) {
      if (record.userId.isEmpty || sourceOwners.contains(record.userId)) {
        final migrated = record.withSyncInfo(
          deviceId: deviceId,
          userId: targetUserId,
          vehicleId: targetVehicleId,
          syncStatus: SyncStatus.pending,
        );
        await _maintenanceBox.put(migrated.id, migrated.toMap());
      }
    }
    final now = DateTime.now();
    for (final sourceOwner in sourceOwners) {
      await _syncQueue.reassignOwnership(
        fromUserId: sourceOwner,
        toUserId: targetUserId,
        vehicleId: targetVehicleId,
      );
    }
    await _meta.put('claimedUserId', targetUserId);
    await _meta.put('supabaseClaimedUserId', targetUserId);
    final hasOwnedData = _allDailyRecords.any(
          (record) => record.userId == targetUserId,
        ) ||
        _allMaintenanceRecords.any(
          (record) => record.userId == targetUserId,
        );
    if (hasOwnedData && activeVehicle == null) {
      await _meta.put('activeVehicleId:$targetUserId', targetVehicleId);
      await _meta.put(
        'vehicle:$targetVehicleId',
        VehicleProfile(
          id: targetVehicleId,
          userId: targetUserId,
          name: sourceVehicle?.name ?? 'Mi Tuk Tuk',
          registration: sourceVehicle?.registration ?? '',
          initialOdometer: sourceVehicle?.initialOdometer ?? 0,
          createdAt: sourceVehicle?.createdAt ?? now,
          updatedAt: now,
          deviceId: deviceId,
          syncStatus: SyncStatus.pending,
        ).toMap(),
      );
    }
    _load();
  }

  @override
  void dispose() {
    _stopAutomaticSync();
    unawaited(_authSubscription?.cancel());
    unawaited(_pushTokenCoordinator?.dispose());
    unawaited(_referralLinkListener?.dispose());
    super.dispose();
  }
}

class _PortableBackup {
  const _PortableBackup({
    required this.vehicle,
    required this.records,
    required this.maintenanceRecords,
    required this.maintenanceIntervalKm,
  });

  final VehicleProfile vehicle;
  final List<DailyRecord> records;
  final List<MaintenanceRecord> maintenanceRecords;
  final double maintenanceIntervalKm;
}
