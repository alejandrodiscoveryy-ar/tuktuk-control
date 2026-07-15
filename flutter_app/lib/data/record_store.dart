part of '../main.dart';

class RecordStore extends ChangeNotifier {
  RecordStore() {
    _load();
    unawaited(_initialize());
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
  );
  final Box _box = Hive.box(_recordsBox);
  final Box _maintenanceBox = Hive.box(_maintenanceRecordsBox);
  final Box _meta = Hive.box(_metaBox);
  final SyncQueueStore _syncQueue = SyncQueueStore();
  final List<DailyRecord> _records = [];
  final List<MaintenanceRecord> _maintenanceRecords = [];
  GoogleSignInAccount? user;
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
    return VehicleProfile.fromMap(raw);
  }

  VehicleProfile? get activeVehicle => _vehicleForUser(activeUserId);

  bool get needsOnboarding => initialized && activeVehicle == null;

  DateTime? get lastSyncAt {
    final raw = _meta.get('lastSyncAt');
    return raw == null ? null : DateTime.tryParse('$raw');
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
    _records
      ..clear()
      ..addAll(
        _box.values
            .map((raw) => DailyRecord.fromMap(raw as Map))
            .where(
              (record) => !record.isDeleted && record.userId == ownerId,
            )
            .toList(),
      );
    _maintenanceRecords
      ..clear()
      ..addAll(
        _maintenanceBox.values
            .map((raw) => MaintenanceRecord.fromMap(raw as Map))
            .where(
              (record) => !record.isDeleted && record.userId == ownerId,
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
    final vehicle = activeVehicle;
    if (vehicle != null) {
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
    for (final record in _allDailyRecords) {
      if (record.schemaVersion < _databaseSchemaVersion ||
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
        chargeTo80v: item.chargeTo80v,
        note: item.earnings > 0
            ? 'Carga inicial de ganancias'
            : 'Carga hasta 80 V',
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
    await _syncQueue.enqueue(
      entityType: SyncEntityType.settings,
      entityId: 'maintenance-settings',
      action: SyncAction.upsert,
      userId: activeUserId,
      vehicleId: activeVehicleId,
    );
    _load();
    unawaitedSync();
  }

  Future<void> signIn() async {
    user = await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
    notifyListeners();
    if (user != null) {
      try {
        await _claimLocalDataForSignedInUser();
        await restoreThenSync();
      } on StateError {
        await _googleSignIn.signOut();
        user = null;
        syncMessage = 'Este dispositivo ya contiene datos de otro usuario';
        notifyListeners();
      }
    }
  }

  Future<void> restoreGoogleSession() async {
    user = await _googleSignIn.signInSilently();
    if (user == null) {
      syncMessage = 'Entra con Google para respaldar en Drive';
      notifyListeners();
      return;
    }
    notifyListeners();
    try {
      await _claimLocalDataForSignedInUser();
      await restoreThenSync();
    } on StateError {
      await _googleSignIn.signOut();
      user = null;
      syncMessage = 'Este dispositivo ya contiene datos de otro usuario';
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    user = null;
    syncMessage = 'Sesion cerrada. La base local sigue en este dispositivo';
    notifyListeners();
  }

  Future<void> restoreThenSync() async {
    await _withSync(() async {
      final api = await _driveApi();
      if (api == null) return;

      final remote = await _readRemote(api);
      if (remote != null) {
        final changed = await _mergeRemote(remote);
        if (changed) syncMessage = 'Base recuperada desde Google Drive';
      }
      await _claimLocalDataForSignedInUser();
      if (activeVehicle == null) {
        syncMessage = 'Configura tu primer vehiculo para comenzar';
        return;
      }
      await _upload(api);
      syncMessage = 'Base respaldada en Google Drive';
    });
  }

  Future<void> syncNow() async {
    await _withSync(() async {
      final api = await _driveApi();
      if (api == null) return;
      if (activeVehicle == null) {
        syncMessage = 'Configura tu primer vehiculo para comenzar';
        return;
      }
      await _upload(api);
      syncMessage = 'Base respaldada en Google Drive';
    });
  }

  void unawaitedSync() {
    if (user != null) {
      syncNow();
    }
  }

  Future<void> _withSync(Future<void> Function() action) async {
    syncing = true;
    syncMessage = 'Sincronizando...';
    notifyListeners();
    try {
      await action();
      await _meta.put('lastSyncAt', DateTime.now().toIso8601String());
    } catch (_) {
      syncMessage = 'No se pudo sincronizar';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<drive.DriveApi?> _driveApi() async {
    final client = await _googleSignIn.authenticatedClient();
    return client == null ? null : drive.DriveApi(client);
  }

  Future<Map<String, dynamic>?> _readRemote(drive.DriveApi api) async {
    final files = await api.files.list(
      spaces: 'appDataFolder',
      q: "name='$_syncFileName' and trashed=false",
      $fields: 'files(id, name, modifiedTime)',
    );
    if (files.files == null || files.files!.isEmpty) return null;
    final id = files.files!.first.id;
    if (id == null) return null;
    final media = await api.files.get(
      id,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  Future<void> _upload(drive.DriveApi api) async {
    final payload = utf8.encode(jsonEncode({
      'schemaVersion': _databaseSchemaVersion,
      'app': 'TukTuk Control',
      'kind': 'database-backup',
      'ownerUserId': activeUserId,
      'vehicleId': activeVehicleId,
      'vehicle': activeVehicle?.toMap(),
      'deviceId': deviceId,
      'updatedAt': DateTime.now().toIso8601String(),
      'settings': {
        'maintenanceIntervalKm': maintenanceIntervalKm,
        'seedVersion': _meta.get('seedVersion'),
      },
      'records': _allDailyRecords
          .where((record) => record.userId == activeUserId)
          .map((record) => record.toMap())
          .toList(),
      'maintenanceRecords': _allMaintenanceRecords
          .where((record) => record.userId == activeUserId)
          .map((record) => record.toMap())
          .toList(),
    }));
    final media = drive.Media(Stream.value(payload), payload.length);
    final existing = await api.files.list(
      spaces: 'appDataFolder',
      q: "name='$_syncFileName' and trashed=false",
      $fields: 'files(id)',
    );
    if (existing.files != null && existing.files!.isNotEmpty) {
      await api.files.update(
        drive.File()..name = _syncFileName,
        existing.files!.first.id!,
        uploadMedia: media,
      );
    } else {
      await api.files.create(
        drive.File()
          ..name = _syncFileName
          ..parents = ['appDataFolder'],
        uploadMedia: media,
      );
    }
  }

  Future<bool> _mergeRemote(Map<String, dynamic> remote) async {
    final remoteOwner = '${remote['ownerUserId'] ?? ''}';
    if (!OwnershipPolicy.acceptsBackup(activeUserId, remoteOwner)) {
      throw StateError('El respaldo pertenece a otro usuario.');
    }
    var changed = false;
    if (remote['vehicle'] is Map) {
      final remoteVehicle = VehicleProfile.fromMap(remote['vehicle'] as Map);
      if (remoteVehicle.userId != activeUserId) {
        throw StateError('El vehiculo del respaldo pertenece a otro usuario.');
      }
      final localVehicle = activeVehicle;
      if (localVehicle == null ||
          remoteVehicle.updatedAt.isAfter(localVehicle.updatedAt)) {
        await _meta.put(
          'activeVehicleId:$activeUserId',
          remoteVehicle.id,
        );
        await _meta.put(
          'vehicle:${remoteVehicle.id}',
          remoteVehicle.toMap(),
        );
        await _syncQueue.enqueue(
          entityType: SyncEntityType.vehicle,
          entityId: remoteVehicle.id,
          action: SyncAction.upsert,
          userId: remoteVehicle.userId,
          vehicleId: remoteVehicle.id,
        );
        changed = true;
      }
    }
    final remoteRecords = (remote['records'] as List? ?? [])
        .map((raw) => DailyRecord.fromMap(raw as Map))
        .toList();
    final localById = {
      for (final record in _allDailyRecords) record.id: record
    };
    for (final remoteRecord in remoteRecords) {
      if (remoteRecord.userId.isNotEmpty &&
          remoteRecord.userId != activeUserId) {
        throw StateError('El respaldo contiene datos de otro usuario.');
      }
      final localRecord = localById[remoteRecord.id];
      if (localRecord == null ||
          remoteRecord.updatedAt.isAfter(localRecord.updatedAt)) {
        await _box.put(remoteRecord.id, remoteRecord.toMap());
        await _syncQueue.enqueue(
          entityType: SyncEntityType.dailyRecord,
          entityId: remoteRecord.id,
          action:
              remoteRecord.isDeleted ? SyncAction.delete : SyncAction.upsert,
          userId:
              remoteRecord.userId.isEmpty ? localOwnerId : remoteRecord.userId,
          vehicleId: remoteRecord.vehicleId.isEmpty
              ? activeVehicleId
              : remoteRecord.vehicleId,
        );
        changed = true;
      }
    }
    final settings =
        remote['settings'] is Map ? remote['settings'] as Map : remote;
    if (settings['maintenanceIntervalKm'] != null) {
      final remoteInterval =
          (settings['maintenanceIntervalKm'] as num).toDouble();
      if (remoteInterval != maintenanceIntervalKm) changed = true;
      await _meta.put(
        'maintenanceIntervalKm',
        remoteInterval,
      );
    }
    if (remote['maintenanceRecords'] is List) {
      final remoteMaintenance = (remote['maintenanceRecords'] as List)
          .map((raw) => MaintenanceRecord.fromMap(raw as Map))
          .toList();
      final localById = {
        for (final record in _allMaintenanceRecords) record.id: record
      };
      for (final remoteRecord in remoteMaintenance) {
        if (remoteRecord.userId.isNotEmpty &&
            remoteRecord.userId != activeUserId) {
          throw StateError('El respaldo contiene datos de otro usuario.');
        }
        final localRecord = localById[remoteRecord.id];
        if (localRecord == null ||
            remoteRecord.updatedAt.isAfter(localRecord.updatedAt)) {
          await _maintenanceBox.put(remoteRecord.id, remoteRecord.toMap());
          await _syncQueue.enqueue(
            entityType: SyncEntityType.maintenance,
            entityId: remoteRecord.id,
            action:
                remoteRecord.isDeleted ? SyncAction.delete : SyncAction.upsert,
            userId: remoteRecord.userId.isEmpty
                ? localOwnerId
                : remoteRecord.userId,
            vehicleId: remoteRecord.vehicleId.isEmpty
                ? activeVehicleId
                : remoteRecord.vehicleId,
          );
          changed = true;
        }
      }
    }
    if (changed) _load();
    return changed;
  }

  Future<void> _claimLocalDataForSignedInUser() async {
    final googleUser = user;
    if (googleUser == null) return;
    final claimed = _meta.get('claimedUserId');
    if (!OwnershipPolicy.canClaimLocalData(
      claimed is String ? claimed : null,
      googleUser.id,
    )) {
      _load();
      throw StateError('Este dispositivo ya contiene datos de otro usuario.');
    }

    final targetUserId = googleUser.id;
    final targetVehicleId = 'vehicle-$targetUserId-primary';
    final sourceVehicle = _vehicleForUser(localOwnerId);
    for (final record in _allDailyRecords) {
      if (record.userId.isEmpty || record.userId == localOwnerId) {
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
      if (record.userId.isEmpty || record.userId == localOwnerId) {
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
    await _syncQueue.reassignOwnership(
      fromUserId: localOwnerId,
      toUserId: targetUserId,
      vehicleId: targetVehicleId,
    );
    await _meta.put('claimedUserId', targetUserId);
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
        ).toMap(),
      );
    }
    _load();
  }
}
