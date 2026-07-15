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
  final List<DailyRecord> _records = [];
  final List<MaintenanceRecord> _maintenanceRecords = [];
  GoogleSignInAccount? user;
  bool syncing = false;
  String syncMessage = 'Base local pendiente de respaldo';

  List<DailyRecord> get records => [..._records]..sort(_compareRecordsDesc);

  List<MaintenanceRecord> get maintenanceRecords => [..._maintenanceRecords]
    ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

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

  DateTime? get lastSyncAt {
    final raw = _meta.get('lastSyncAt');
    return raw == null ? null : DateTime.tryParse('$raw');
  }

  Future<void> _initialize() async {
    await _migrateLegacyMaintenance();
    await _migrateSyncMetadata();
    await _seedInitialEarningsIfEmpty();
    await _seedInitialMaintenanceIfEmpty();
    _load();
    await restoreGoogleSession();
  }

  void _load() {
    _records
      ..clear()
      ..addAll(
        _box.values
            .map((raw) => DailyRecord.fromMap(raw as Map))
            .where((record) => !record.isDeleted)
            .toList(),
      );
    _maintenanceRecords
      ..clear()
      ..addAll(
        _maintenanceBox.values
            .map((raw) => MaintenanceRecord.fromMap(raw as Map))
            .where((record) => !record.isDeleted)
            .toList(),
      );
    notifyListeners();
  }

  List<DailyRecord> get _allDailyRecords =>
      _box.values.map((raw) => DailyRecord.fromMap(raw as Map)).toList();

  List<MaintenanceRecord> get _allMaintenanceRecords => _maintenanceBox.values
      .map((raw) => MaintenanceRecord.fromMap(raw as Map))
      .toList();

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
          record.deviceId.isEmpty) {
        final migrated = record.withSyncInfo(deviceId: deviceId);
        await _box.put(migrated.id, migrated.toMap());
      }
    }
    for (final record in _allMaintenanceRecords) {
      if (record.schemaVersion < _databaseSchemaVersion ||
          record.deviceId.isEmpty) {
        final migrated = record.withSyncInfo(deviceId: deviceId);
        await _maintenanceBox.put(migrated.id, migrated.toMap());
      }
    }
    await _meta.put('databaseSchemaVersion', _databaseSchemaVersion);
  }

  Future<void> _seedInitialEarningsIfEmpty() async {
    final currentSeedVersion = _meta.get('seedVersion');
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
      ).withSyncInfo(deviceId: deviceId);
      await _box.put(record.id, record.toMap());
    }
    await _meta.put('seedVersion', _seedVersion);
    await _seedInitialMaintenanceIfEmpty();
    _load();
  }

  Future<void> _seedInitialMaintenanceIfEmpty() async {
    if (_maintenanceBox.isNotEmpty) return;
    await _meta.put('maintenanceIntervalKm', _defaultMaintenanceIntervalKm);
    final record = MaintenanceRecord(
      id: 'maintenance-seed-2026-03-14',
      dateTime: DateTime(2026, 3, 14, 9),
      odometer: 526,
      type: 'General',
      description: 'Mantenimiento general registrado',
      notes: 'Base para calcular el proximo mantenimiento cada 5,000 km.',
    ).withSyncInfo(deviceId: deviceId);
    await _maintenanceBox.put(record.id, record.toMap());
  }

  Future<void> save(DailyRecord record) async {
    final normalized = record.withSyncInfo(
      deviceId: deviceId,
      updatedAt: DateTime.now(),
    );
    await _box.put(normalized.id, normalized.toMap());
    _load();
    unawaitedSync();
  }

  Future<void> delete(String id) async {
    final raw = _box.get(id);
    if (raw != null) {
      final record = DailyRecord.fromMap(raw as Map).withSyncInfo(
        deviceId: deviceId,
        updatedAt: DateTime.now(),
        deletedAt: DateTime.now(),
      );
      await _box.put(record.id, record.toMap());
    }
    _load();
    unawaitedSync();
  }

  Future<void> saveMaintenance(MaintenanceRecord record) async {
    final normalized = record.withSyncInfo(
      deviceId: deviceId,
      updatedAt: DateTime.now(),
    );
    await _maintenanceBox.put(normalized.id, normalized.toMap());
    _load();
    unawaitedSync();
  }

  Future<void> deleteMaintenance(String id) async {
    final raw = _maintenanceBox.get(id);
    if (raw != null) {
      final record = MaintenanceRecord.fromMap(raw as Map).withSyncInfo(
        deviceId: deviceId,
        updatedAt: DateTime.now(),
        deletedAt: DateTime.now(),
      );
      await _maintenanceBox.put(record.id, record.toMap());
    }
    _load();
    unawaitedSync();
  }

  Future<void> setMaintenanceInterval(double intervalKm) async {
    await _meta.put('maintenanceIntervalKm', intervalKm);
    _load();
    unawaitedSync();
  }

  Future<void> signIn() async {
    user = await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
    notifyListeners();
    if (user != null) {
      await restoreThenSync();
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
    await restoreThenSync();
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
      await _upload(api);
      syncMessage = 'Base respaldada en Google Drive';
    });
  }

  Future<void> syncNow() async {
    await _withSync(() async {
      final api = await _driveApi();
      if (api == null) return;
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
      'deviceId': deviceId,
      'updatedAt': DateTime.now().toIso8601String(),
      'settings': {
        'maintenanceIntervalKm': maintenanceIntervalKm,
        'seedVersion': _meta.get('seedVersion'),
      },
      'records': _allDailyRecords.map((record) => record.toMap()).toList(),
      'maintenanceRecords':
          _allMaintenanceRecords.map((record) => record.toMap()).toList(),
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
    var changed = false;
    final remoteRecords = (remote['records'] as List? ?? [])
        .map((raw) => DailyRecord.fromMap(raw as Map))
        .toList();
    final localById = {
      for (final record in _allDailyRecords) record.id: record
    };
    for (final remoteRecord in remoteRecords) {
      final localRecord = localById[remoteRecord.id];
      if (localRecord == null ||
          remoteRecord.updatedAt.isAfter(localRecord.updatedAt)) {
        await _box.put(remoteRecord.id, remoteRecord.toMap());
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
        final localRecord = localById[remoteRecord.id];
        if (localRecord == null ||
            remoteRecord.updatedAt.isAfter(localRecord.updatedAt)) {
          await _maintenanceBox.put(remoteRecord.id, remoteRecord.toMap());
          changed = true;
        }
      }
    }
    if (changed) _load();
    return changed;
  }

  DateTime _latestLocalUpdate() {
    final dates = [
      ..._allDailyRecords.map((record) => record.updatedAt),
      ..._allMaintenanceRecords.map((record) => record.updatedAt),
    ];
    if (dates.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    return dates.reduce((a, b) => a.isAfter(b) ? a : b);
  }
}
