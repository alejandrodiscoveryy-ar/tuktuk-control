part of '../main.dart';

class RecordStore extends ChangeNotifier {
  RecordStore() {
    _supabaseGateway = SupabaseSyncGateway(
      client: _supabase,
      payloadFor: _payloadForOperation,
    );
    _syncCoordinator = SyncCoordinator(
      queue: _syncQueue,
      gateway: _supabaseGateway,
    );
    _authSubscription = _supabase.auth.onAuthStateChange.listen((state) {
      if (initialized) unawaited(_handleAuthState(state.session?.user));
    });
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
  StreamSubscription<AuthState>? _authSubscription;
  RealtimeChannel? _realtimeChannel;
  Timer? _automaticSyncTimer;
  Timer? _syncDebounceTimer;
  bool _syncRequestedWhileRunning = false;
  String? _ensuredProfileFingerprint;
  final List<DailyRecord> _records = [];
  final List<MaintenanceRecord> _maintenanceRecords = [];
  User? user;
  bool initialized = false;
  bool syncing = false;
  String syncMessage = 'Base local pendiente de respaldo';

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
    if (googleUser != null) return googleUser.id;
    final claimed = _meta.get('claimedUserId');
    return claimed is String && claimed.isNotEmpty ? claimed : localOwnerId;
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
    final raw = _meta.get('lastSyncAt');
    return raw == null ? null : DateTime.tryParse('$raw');
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
    final clean = value.trim();
    if (clean.isEmpty) return;
    await _meta.put('profileDisplayName:$activeUserId', clean);
    await _enqueueSettingsSync();
    notifyListeners();
    unawaitedSync();
  }

  Future<void> savePreferences({
    required String currency,
    required String language,
    required String theme,
  }) async {
    await _meta.putAll({
      'preferredCurrency': currency,
      'preferredLanguage': language,
      'preferredTheme': theme,
    });
    await _enqueueSettingsSync();
    notifyListeners();
    unawaitedSync();
  }

  Future<void> _enqueueSettingsSync() async {
    await _meta.put('settingsUpdatedAt', DateTime.now().toIso8601String());
    await _syncQueue.enqueue(
      entityType: SyncEntityType.settings,
      entityId: 'app-settings-$activeVehicleId',
      action: SyncAction.upsert,
      userId: activeUserId,
      vehicleId: activeVehicleId,
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
    final decoded = jsonDecode(source);
    if (decoded is! Map) throw const FormatException('Respaldo no válido');
    await _replaceWithPortableBackup(Map<String, dynamic>.from(decoded));
    _load();
  }

  Future<void> _initialize() async {
    try {
      await _migrateLegacyMaintenance();
      await _migrateSyncMetadata();
      await _seedInitialEarningsIfEmpty();
      await _seedInitialMaintenanceIfEmpty();
      await _seedSyncQueueIfNeeded();
      _load();
      await restoreGoogleSession();
    } finally {
      initialized = true;
      notifyListeners();
    }
  }

  Future<void> configureFirstVehicle({
    required String name,
    String registration = '',
    double initialOdometer = 0,
  }) async {
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
    );
    _load();
    unawaitedSync();
  }

  Future<void> delete(String id) async {
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
      );
    }
    _load();
    unawaitedSync();
  }

  Future<void> saveMaintenance(MaintenanceRecord record) async {
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
    );
    _load();
    unawaitedSync();
  }

  Future<void> deleteMaintenance(String id) async {
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
      );
    }
    _load();
    unawaitedSync();
  }

  Future<void> setMaintenanceInterval(double intervalKm) async {
    await _meta.put('maintenanceIntervalKm', intervalKm);
    await _enqueueSettingsSync();
    _load();
    unawaitedSync();
  }

  Future<void> signIn() async {
    syncMessage = 'Abriendo acceso seguro con Google...';
    notifyListeners();
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? Uri.base.origin : _supabaseMobileRedirect,
      authScreenLaunchMode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
  }

  Future<void> restoreGoogleSession() async {
    await _handleAuthState(_supabase.auth.currentUser);
  }

  Future<void> signOut() async {
    _stopAutomaticSync();
    await _supabase.auth.signOut();
    user = null;
    syncMessage = 'Sesion cerrada. La base local sigue en este dispositivo';
    notifyListeners();
  }

  Future<void> restoreThenSync() async {
    await syncNow();
  }

  Future<void> syncNow() async {
    await _withSync(() async {
      if (user == null) return;
      if (activeVehicle == null) {
        syncMessage = 'Configura tu primer vehiculo para comenzar';
        return;
      }
      await _synchronizeWithSupabase();
      syncMessage = pendingSyncCount == 0
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
    syncing = true;
    syncMessage = 'Sincronizando...';
    notifyListeners();
    try {
      await action();
      await _meta.put('lastSyncAt', DateTime.now().toIso8601String());
    } catch (_) {
      syncMessage = 'Sin conexion. Los cambios permanecen guardados';
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
      _stopAutomaticSync();
      if (initialized) {
        syncMessage = 'Entra con Google para activar la sincronizacion';
        notifyListeners();
      }
      return;
    }
    user = authenticatedUser;
    notifyListeners();
    try {
      await _claimLocalDataForSignedInUser();
      _startAutomaticSync();
      await syncNow();
    } on StateError {
      _stopAutomaticSync();
      await _supabase.auth.signOut();
      user = null;
      syncMessage = 'Este dispositivo ya contiene datos de otro usuario';
      notifyListeners();
    }
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
        .subscribe();
    _automaticSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaitedSync(),
    );
  }

  void _stopAutomaticSync() {
    _automaticSyncTimer?.cancel();
    _automaticSyncTimer = null;
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = null;
    _syncRequestedWhileRunning = false;
    _ensuredProfileFingerprint = null;
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
    final report = await _syncCoordinator.pushPending(
      userId: currentUser.id,
      batchSize: 500,
    );
    for (final operation in pendingBatch) {
      if (report.completedOperationIds.contains(operation.id)) {
        await _markEntitySynced(operation);
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
    await _supabase.from('profiles').upsert(profile, onConflict: 'id');
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
    final claimed = _meta.get('supabaseClaimedUserId');
    if (!OwnershipPolicy.canClaimLocalData(
      claimed is String ? claimed : null,
      googleUser.id,
    )) {
      _load();
      throw StateError('Este dispositivo ya contiene datos de otro usuario.');
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
