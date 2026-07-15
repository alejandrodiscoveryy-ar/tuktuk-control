import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

const _recordsBox = 'daily_records';
const _maintenanceRecordsBox = 'maintenance_records';
const _metaBox = 'meta';
const _syncFileName = 'control_tuk_tuk_backup.json';
const _seedVersion = 'earnings-odometer-charge80v-maintenance-2026-07-03';
const _defaultMaintenanceIntervalKm = 5000.0;
const _databaseSchemaVersion = 2;

const kBg = Color(0xFF0B0F14);
const kSurface = Color(0xFF141A22);
const kSurfaceHigh = Color(0xFF1E2630);
const kOutline = Color(0xFF334155);
const kPrimary = Color(0xFF22D3A6);
const kSecondary = Color(0xFF60A5FA);
const kTertiary = Color(0xFFF59E0B);
const kText = Color(0xFFE5EDF7);
const kMuted = Color(0xFF9AA7B7);
const kDanger = Color(0xFFFB7185);
const kAccentPink = Color(0xFFF472B6);
const kCardGradientTop = Color(0xFF19212B);
const kCardGradientBottom = Color(0xFF10161D);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  Intl.defaultLocale = 'es';
  await Hive.initFlutter();
  await Hive.openBox(_recordsBox);
  await Hive.openBox(_maintenanceRecordsBox);
  await Hive.openBox(_metaBox);
  runApp(const ControlTukTukApp());
}

class ControlTukTukApp extends StatelessWidget {
  const ControlTukTukApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TukTuk Control',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(
          primary: kPrimary,
          secondary: kSecondary,
          tertiary: kTertiary,
          surface: kSurface,
          error: kDanger,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: kBg,
          foregroundColor: kText,
          titleTextStyle: TextStyle(
            color: kText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: const Color(0xFF06251C),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: kSecondary,
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kSecondary,
            side: const BorderSide(color: Color(0xFF35506B)),
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: kSurfaceHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: kSurfaceHigh,
          contentTextStyle: const TextStyle(color: kText),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 72,
          backgroundColor: kSurface,
          indicatorColor: kPrimary.withOpacity(.16),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected) ? kPrimary : kMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? kPrimary : kMuted,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kSurface,
          labelStyle: const TextStyle(color: kMuted),
          prefixIconColor: kSecondary,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF263241)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF263241)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kPrimary, width: 1.5),
          ),
        ),
      ),
      home: const AppShell(),
    );
  }
}

class DailyRecord {
  DailyRecord({
    required this.id,
    required this.date,
    required this.earnings,
    required this.odometer,
    this.batteryPercent,
    this.chargeTo80v = false,
    this.note = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    this.deviceId = '',
    this.schemaVersion = _databaseSchemaVersion,
  })  : createdAt = createdAt ?? updatedAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final DateTime date;
  final double earnings;
  final double odometer;
  final int? batteryPercent;
  final bool chargeTo80v;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String deviceId;
  final int schemaVersion;

  bool get isDeleted => deletedAt != null;

  factory DailyRecord.fromMap(Map<dynamic, dynamic> map) {
    final parsedUpdatedAt =
        DateTime.tryParse('${map['updatedAt']}') ?? DateTime.now();
    return DailyRecord(
      id: '${map['id']}',
      date: DateTime.parse('${map['date']}'),
      earnings: _numFromMap(map, 'earnings'),
      odometer: _numFromMap(map, 'odometer'),
      batteryPercent: map['batteryPercent'] == null
          ? null
          : (map['batteryPercent'] as num).round(),
      chargeTo80v: map['chargeTo80v'] == true,
      note: '${map['note'] ?? ''}',
      createdAt: DateTime.tryParse('${map['createdAt']}') ?? parsedUpdatedAt,
      updatedAt: parsedUpdatedAt,
      deletedAt: DateTime.tryParse('${map['deletedAt'] ?? ''}'),
      deviceId: '${map['deviceId'] ?? ''}',
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'date': DateFormat('yyyy-MM-dd').format(date),
        'earnings': earnings,
        'odometer': odometer,
        'batteryPercent': batteryPercent,
        'chargeTo80v': chargeTo80v,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
        'deviceId': deviceId,
      };

  DailyRecord withSyncInfo({
    required String deviceId,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return DailyRecord(
      id: id,
      date: date,
      earnings: earnings,
      odometer: odometer,
      batteryPercent: batteryPercent,
      chargeTo80v: chargeTo80v,
      note: note,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: this.deviceId.isEmpty ? deviceId : this.deviceId,
      schemaVersion: _databaseSchemaVersion,
    );
  }
}

class MaintenanceRecord {
  MaintenanceRecord({
    required this.id,
    required this.dateTime,
    required this.odometer,
    required this.type,
    required this.description,
    this.cost,
    this.notes = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    this.deviceId = '',
    this.schemaVersion = _databaseSchemaVersion,
  })  : createdAt = createdAt ?? updatedAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final DateTime dateTime;
  final double odometer;
  final String type;
  final String description;
  final double? cost;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String deviceId;
  final int schemaVersion;

  bool get isDeleted => deletedAt != null;

  factory MaintenanceRecord.fromMap(Map<dynamic, dynamic> map) {
    final parsedUpdatedAt =
        DateTime.tryParse('${map['updatedAt']}') ?? DateTime.now();
    return MaintenanceRecord(
      id: '${map['id']}',
      dateTime: DateTime.parse('${map['dateTime']}'),
      odometer: _numFromMap(map, 'odometer'),
      type: '${map['type'] ?? 'General'}',
      description: '${map['description'] ?? ''}',
      cost: map['cost'] == null ? null : _numFromMap(map, 'cost'),
      notes: '${map['notes'] ?? ''}',
      createdAt: DateTime.tryParse('${map['createdAt']}') ?? parsedUpdatedAt,
      updatedAt: parsedUpdatedAt,
      deletedAt: DateTime.tryParse('${map['deletedAt'] ?? ''}'),
      deviceId: '${map['deviceId'] ?? ''}',
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'dateTime': dateTime.toIso8601String(),
        'odometer': odometer,
        'type': type,
        'description': description,
        'cost': cost,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
        'deviceId': deviceId,
      };

  MaintenanceRecord withSyncInfo({
    required String deviceId,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return MaintenanceRecord(
      id: id,
      dateTime: dateTime,
      odometer: odometer,
      type: type,
      description: description,
      cost: cost,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: this.deviceId.isEmpty ? deviceId : this.deviceId,
      schemaVersion: _databaseSchemaVersion,
    );
  }
}

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

  List<MaintenanceRecord> get maintenanceRecords =>
      [..._maintenanceRecords]..sort((a, b) => b.dateTime.compareTo(a.dateTime));

  double get maintenanceIntervalKm {
    final value = _meta.get('maintenanceIntervalKm');
    return value == null ? _defaultMaintenanceIntervalKm : (value as num).toDouble();
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

  List<DailyRecord> get _allDailyRecords => _box.values
      .map((raw) => DailyRecord.fromMap(raw as Map))
      .toList();

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
    final localById = {for (final record in _allDailyRecords) record.id: record};
    for (final remoteRecord in remoteRecords) {
      final localRecord = localById[remoteRecord.id];
      if (localRecord == null ||
          remoteRecord.updatedAt.isAfter(localRecord.updatedAt)) {
        await _box.put(remoteRecord.id, remoteRecord.toMap());
        changed = true;
      }
    }
    final settings = remote['settings'] is Map ? remote['settings'] as Map : remote;
    if (settings['maintenanceIntervalKm'] != null) {
      final remoteInterval = (settings['maintenanceIntervalKm'] as num).toDouble();
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
      final localById = {for (final record in _allMaintenanceRecords) record.id: record};
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

class Metrics {
  Metrics(this.records);

  final List<DailyRecord> records;
  DateTime get today => DateTime.now();

  List<DailyRecord> get sorted => [...records]..sort(_compareRecordsAsc);

  List<DailyRecord> get withOdometer =>
      sorted.where((record) => record.odometer > 0).toList();

  double get totalEarnings => records.fold(0, (sum, r) => sum + r.earnings);
  int get chargeEvents => records.where((record) => record.chargeTo80v).length;
  List<DailyRecord> get earningsWithoutOdometer => records
      .where((record) => record.earnings > 0 && record.odometer <= 0)
      .toList();

  List<OdometerIssue> get odometerDrops {
    final days = withOdometer;
    final issues = <OdometerIssue>[];
    for (var i = 1; i < days.length; i++) {
      final previous = days[i - 1];
      final current = days[i];
      if (current.odometer < previous.odometer) {
        issues.add(OdometerIssue(previous: previous, current: current));
      }
    }
    return issues;
  }

  double get latestOdometer {
    if (withOdometer.isEmpty) return 0;
    return withOdometer.map((record) => record.odometer).reduce(max);
  }

  double get totalDistance {
    if (withOdometer.length < 2) return 0;
    final values = withOdometer.map((record) => record.odometer);
    return max(0, values.reduce(max) - values.reduce(min));
  }

  double get todayEarnings {
    return records
        .where((r) => _sameDay(r.date, today))
        .fold(0, (sum, r) => sum + r.earnings);
  }

  CycleRange get currentCycle => CycleRange.forDate(today);

  List<DailyRecord> get currentCycleRecords =>
      records.where((r) => currentCycle.contains(r.date)).toList();

  double get currentCycleEarnings =>
      currentCycleRecords.fold(0, (sum, r) => sum + r.earnings);

  double get currentCycleDistance {
    final days = [...currentCycleRecords.where((record) => record.odometer > 0)]
      ..sort(_compareRecordsAsc);
    if (days.length < 2) return 0;
    final values = days.map((record) => record.odometer);
    return max(0, values.reduce(max) - values.reduce(min));
  }

  double get averageDailyEarnings {
    final uniqueDays = records
        .where((r) => r.earnings > 0)
        .map((r) => DateFormat('yyyy-MM-dd').format(r.date))
        .toSet();
    return uniqueDays.isEmpty ? 0 : totalEarnings / uniqueDays.length;
  }

  double get efficiency =>
      totalDistance <= 0 ? 0 : totalEarnings / totalDistance;

  Map<String, double> get monthlyEarnings {
    final map = <String, double>{};
    for (final record in records.where((record) => record.earnings > 0)) {
      final key = DateFormat('MMM yyyy', 'es').format(record.date);
      map[key] = (map[key] ?? 0) + record.earnings;
    }
    return map;
  }

  List<CycleSummary> get cycleSummaries {
    final map = <DateTime, List<DailyRecord>>{};
    for (final record in records) {
      final cycle = CycleRange.forDate(record.date);
      map.putIfAbsent(cycle.start, () => []).add(record);
    }
    final summaries = map.entries.map((entry) {
      final cycle = CycleRange(entry.key, DateTime(entry.key.year, entry.key.month + 1, 0));
      final days = entry.value.where((record) => record.odometer > 0).toList()
        ..sort(_compareRecordsAsc);
      final values = days.map((record) => record.odometer);
      final distance = days.length < 2 ? 0 : max(0, values.reduce(max) - values.reduce(min));
      return CycleSummary(
        start: entry.key,
        label: cycle.label,
        earnings: entry.value.fold(0, (sum, r) => sum + r.earnings),
        distance: distance.toDouble(),
      );
    }).toList();
    summaries.sort((a, b) => a.start.compareTo(b.start));
    return summaries;
  }
}

class MaintenanceSnapshot {
  MaintenanceSnapshot({
    required this.lastMaintenance,
    required this.intervalKm,
    required this.nextMaintenanceKm,
    required this.remainingKm,
    required this.status,
    required this.color,
  });

  final MaintenanceRecord? lastMaintenance;
  final double intervalKm;
  final double nextMaintenanceKm;
  final double remainingKm;
  final String status;
  final Color color;

  factory MaintenanceSnapshot.from({
    required List<MaintenanceRecord> records,
    required double intervalKm,
    required double currentOdometer,
  }) {
    final sorted = [...records]..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    final last = sorted.isEmpty ? null : sorted.first;
    final next = last == null ? intervalKm : last.odometer + intervalKm;
    final remaining = next - currentOdometer;
    final status = _maintenanceStatus(remaining);
    return MaintenanceSnapshot(
      lastMaintenance: last,
      intervalKm: intervalKm,
      nextMaintenanceKm: next,
      remainingKm: remaining,
      status: status.$1,
      color: status.$2,
    );
  }

  static (String, Color) _maintenanceStatus(double remainingKm) {
    if (remainingKm < 0) return ('Mantenimiento vencido', kDanger);
    if (remainingKm < 50) return ('Mantenimiento pendiente', kDanger);
    if (remainingKm <= 200) return ('Programe el mantenimiento', kTertiary);
    if (remainingKm <= 500) return ('Se aproxima el mantenimiento', kSecondary);
    return ('Estado normal', kPrimary);
  }
}

class OdometerIssue {
  const OdometerIssue({required this.previous, required this.current});

  final DailyRecord previous;
  final DailyRecord current;
}

class CycleRange {
  CycleRange(this.start, this.end);

  final DateTime start;
  final DateTime end;

  factory CycleRange.forDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final start = DateTime(normalized.year, normalized.month);
    final end = DateTime(start.year, start.month + 1, 0);
    return CycleRange(start, end);
  }

  bool contains(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  String get label {
    final month = DateFormat('MMMM yyyy', 'es').format(start);
    return month[0].toUpperCase() + month.substring(1);
  }
}

class CycleSummary {
  CycleSummary({
    required this.start,
    required this.label,
    required this.earnings,
    required this.distance,
  });

  final DateTime start;
  final String label;
  final double earnings;
  final double distance;
}

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
            color: kPrimary.withOpacity(.22),
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
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0B0F14),
            Color(0xFF101820),
            Color(0xFF0B0F14),
          ],
        ),
      ),
      child: child,
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
        final screens = [
          DashboardScreen(store: store),
          RegisterScreen(store: store),
          HistoryScreen(store: store),
          StatsScreen(store: store),
          LoginScreen(store: store),
        ];
        return Scaffold(
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
                onPressed: store.user == null || store.syncing ? null : store.syncNow,
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
            child: SafeArea(child: screens[index]),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
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
                label: 'Google',
              ),
            ],
          ),
        );
      },
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
                label: 'Odometro',
                value: '${numFmt(metrics.latestOdometer)} km',
                icon: Icons.speed,
                color: kSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                label: 'Mes',
                value: metrics.currentCycle.label,
                icon: Icons.route_outlined,
                color: kTertiary,
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
          trailing: store.records.isEmpty ? null : '${store.records.length} registros',
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
    earnings = TextEditingController(text: record == null ? '' : trimNum(record.earnings));
    odometer = TextEditingController(text: record == null ? '' : trimNum(record.odometer));
    battery = TextEditingController(text: record?.batteryPercent?.toString() ?? '');
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
    if (earned == 0 &&
        odo == 0 &&
        !chargeTo80v &&
        note.text.trim().isEmpty) {
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
        SectionTitle(title: 'Historial editable', trailing: '${records.length} dias'),
        if (records.isEmpty)
          const EmptyState('Cuando guardes registros, apareceran aqui.')
        else
          ...records.map((record) => Dismissible(
                key: ValueKey(record.id),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: kDanger.withOpacity(.25),
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

class StatsScreen extends StatelessWidget {
  const StatsScreen({required this.store, super.key});

  final RecordStore store;

  @override
  Widget build(BuildContext context) {
    final metrics = Metrics(store.records);
    final months = metrics.monthlyEarnings.entries.toList();
    final maxMonth = months.isEmpty ? 1 : months.map((e) => e.value).reduce(max);
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
        const SectionTitle(title: 'Por mes'),
        if (months.isEmpty)
          const EmptyState('Sin datos suficientes para graficar.')
        else
          ...months.map((entry) => BarRow(
                label: entry.key,
                value: money(entry.value),
                percent: entry.value / maxMonth,
              )),
        const SizedBox(height: 18),
        const SectionTitle(title: 'Por mes'),
        if (metrics.cycleSummaries.isEmpty)
          const EmptyState('Los meses se calculan del dia 1 al ultimo dia del mes.')
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
                user == null ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
                color: user == null ? kMuted : kPrimary,
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                user == null ? 'No conectado' : user.email,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                user == null
                    ? 'Conecta Google para guardar la base de datos en Google Drive y recuperarla al reinstalar.'
                    : store.syncMessage,
                style: const TextStyle(color: kMuted),
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
                icon: Icon(user == null ? Icons.login : Icons.cloud_sync_outlined),
                label: Text(user == null ? 'Entrar con Google' : 'Respaldar ahora'),
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
        MaintenanceSettingsPanel(store: store),
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
                    color: kDanger.withOpacity(.25),
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
                            appBar: AppBar(title: const Text('Editar mantenimiento')),
                            body: MaintenanceFormScreen(
                              store: widget.store,
                              record: record,
                            ),
                          ),
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.build_outlined, color: kPrimary),
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
        id: widget.record?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        dateTime: DateTime(date.year, date.month, date.day, time.hour, time.minute),
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

class MetricHero extends StatelessWidget {
  const MetricHero({
    required this.label,
    required this.value,
    required this.sublabel,
    required this.icon,
    super.key,
  });

  final String label;
  final String value;
  final String sublabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GradientMetricCard(
      child: Stack(
        children: [
          Positioned(
            right: 2,
            top: 2,
            child: Icon(icon, size: 86, color: kText.withOpacity(.08)),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 92,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  colors: [kPrimary, kSecondary, kAccentPink],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Label(label),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  color: kPrimary,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              const Divider(color: kOutline),
              Text(sublabel, style: const TextStyle(color: kMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class MaintenanceDashboardCard extends StatelessWidget {
  const MaintenanceDashboardCard({required this.snapshot, super.key});

  final MaintenanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final last = snapshot.lastMaintenance;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Label('Mantenimiento general')),
              Icon(Icons.build_circle_outlined, color: snapshot.color),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            snapshot.status,
            style: TextStyle(
              color: snapshot.color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          InfoLine(
            label: 'Ultimo mantenimiento',
            value: last == null
                ? 'Sin registrar'
                : DateFormat('d MMM yyyy, HH:mm', 'es').format(last.dateTime),
          ),
          InfoLine(
            label: 'Km del ultimo mantenimiento',
            value: last == null ? '-' : '${numFmt(last.odometer)} km',
          ),
          InfoLine(
            label: 'Proximo mantenimiento',
            value: '${numFmt(snapshot.nextMaintenanceKm)} km',
          ),
          InfoLine(
            label: 'Km restantes',
            value: snapshot.remainingKm < 0
                ? 'Vencido por ${numFmt(snapshot.remainingKm.abs())} km'
                : '${numFmt(snapshot.remainingKm)} km',
          ),
        ],
      ),
    );
  }
}

class DataHealthCard extends StatelessWidget {
  const DataHealthCard({required this.metrics, super.key});

  final Metrics metrics;

  @override
  Widget build(BuildContext context) {
    final missing = metrics.earningsWithoutOdometer.length;
    final drops = metrics.odometerDrops;
    final statusColor = missing == 0 && drops.isEmpty ? kPrimary : kTertiary;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Label('Salud de datos')),
              Icon(Icons.fact_check_outlined, color: statusColor),
            ],
          ),
          const SizedBox(height: 12),
          InfoLine(
            label: 'Registros con ganancia',
            value: metrics.records.where((record) => record.earnings > 0).length.toString(),
          ),
          InfoLine(
            label: 'Cargas a 80 V',
            value: metrics.chargeEvents.toString(),
          ),
          InfoLine(
            label: 'Ganancias sin odometro',
            value: missing.toString(),
          ),
          InfoLine(
            label: 'Lecturas sospechosas',
            value: drops.length.toString(),
          ),
          if (missing > 0 || drops.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _healthMessage(missing, drops),
              style: const TextStyle(color: kMuted),
            ),
          ],
        ],
      ),
    );
  }

  String _healthMessage(int missing, List<OdometerIssue> drops) {
    final parts = <String>[];
    if (missing > 0) {
      parts.add('$missing registros con ganancia no tienen odometro.');
    }
    if (drops.isNotEmpty) {
      final issue = drops.first;
      parts.add(
        'Revisa ${DateFormat('d MMM', 'es').format(issue.current.date)}: '
        '${numFmt(issue.current.odometer)} km es menor que '
        '${numFmt(issue.previous.odometer)} km.',
      );
    }
    return parts.join(' ');
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color = kPrimary,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Label(label)),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class InfoLine extends StatelessWidget {
  const InfoLine({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: kMuted))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class RecordTile extends StatelessWidget {
  const RecordTile({required this.record, this.onTap, super.key});

  final DailyRecord record;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (record.odometer > 0) '${numFmt(record.odometer)} km',
      if (record.chargeTo80v) 'Carga hasta 80 V',
      if (record.note.isNotEmpty) record.note,
    ];
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.zero,
        title: Text(DateFormat('d MMMM yyyy', 'es').format(record.date)),
        subtitle: Text(details.isEmpty ? 'Sin detalles' : details.join(' - ')),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              record.earnings > 0
                  ? '+${money(record.earnings)}'
                  : record.chargeTo80v
                      ? '80 V'
                      : '0 CUP',
              style: TextStyle(
                color: record.earnings > 0 ? kPrimary : kSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (record.batteryPercent != null)
              Text('${record.batteryPercent}% bateria', style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class BarRow extends StatelessWidget {
  const BarRow({
    required this.label,
    required this.value,
    required this.percent,
    super.key,
  });

  final String label;
  final String value;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(value, style: const TextStyle(color: kPrimary)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent.clamp(0, 1),
              minHeight: 10,
              color: kPrimary,
              backgroundColor: kSurfaceHigh,
            ),
          ),
        ],
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.margin,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kCardGradientTop, kCardGradientBottom],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A3645)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class GradientMetricCard extends StatelessWidget {
  const GradientMetricCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF18362F),
            Color(0xFF142237),
            Color(0xFF21192B),
          ],
        ),
        border: Border.all(color: Color(0xFF2C4B46)),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(.12),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({required this.title, this.trailing, super.key});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          if (trailing != null)
            Text(trailing!, style: const TextStyle(color: kMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class Label extends StatelessWidget {
  const Label(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: kMuted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: .7,
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Text(text, style: const TextStyle(color: kMuted)),
    );
  }
}

String money(double value) => '${NumberFormat('#,##0.##', 'es').format(value)} CUP';
String numFmt(double value) => NumberFormat('#,##0.##', 'es').format(value);
String trimNum(double value) => value % 1 == 0 ? value.toInt().toString() : value.toString();

double _numFromMap(Map<dynamic, dynamic> map, String key) {
  final value = map[key];
  if (value is num) return value.toDouble();
  return double.tryParse('$value'.replaceAll(',', '.')) ?? 0;
}

double? _parseOptionalNumber(String value) {
  final normalized = value.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

int _compareRecordsAsc(DailyRecord a, DailyRecord b) {
  final date = a.date.compareTo(b.date);
  if (date != 0) return date;
  final updated = a.updatedAt.compareTo(b.updatedAt);
  if (updated != 0) return updated;
  final odometer = a.odometer.compareTo(b.odometer);
  if (odometer != 0) return odometer;
  return a.id.compareTo(b.id);
}

int _compareRecordsDesc(DailyRecord a, DailyRecord b) => _compareRecordsAsc(b, a);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _InitialRecord {
  const _InitialRecord(
    this.date,
    this.earnings,
    this.odometer, {
    this.chargeTo80v = false,
  });

  final DateTime date;
  final double earnings;
  final double odometer;
  final bool chargeTo80v;
}

final List<_InitialRecord> _initialRecords = [
  _InitialRecord(DateTime(2026, 2, 28), 0, 0, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 3, 2), 0, 0, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 3, 3), 4450, 141),
  _InitialRecord(DateTime(2026, 3, 4), 1600, 174, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 3, 5), 4450, 0),
  _InitialRecord(DateTime(2026, 3, 6), 3000, 239, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 3, 9), 0, 0, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 3, 10), 3400, 337, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 3, 11), 3400, 391, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 3, 12), 2510, 437),
  _InitialRecord(DateTime(2026, 3, 13), 4480, 468),
  _InitialRecord(DateTime(2026, 3, 14), 2900, 526, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 3, 15), 1700, 580),
  _InitialRecord(DateTime(2026, 3, 17), 3000, 631),
  _InitialRecord(DateTime(2026, 3, 18), 4300, 631, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 3, 20), 4250, 679, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 3, 23), 5130, 772),
  _InitialRecord(DateTime(2026, 3, 24), 5060, 799, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 3, 25), 3350, 839),
  _InitialRecord(DateTime(2026, 3, 26), 4130, 885),
  _InitialRecord(DateTime(2026, 3, 27), 2870, 922, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 3, 28), 3150, 949),
  _InitialRecord(DateTime(2026, 3, 29), 400, 970, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 3, 30), 4400, 998),
  _InitialRecord(DateTime(2026, 3, 31), 0, 0, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 4, 1), 3700, 1060),
  _InitialRecord(DateTime(2026, 4, 2), 3850, 1089, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 4, 3), 2350, 1132),
  _InitialRecord(DateTime(2026, 4, 4), 2800, 1160, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 4, 5), 5290, 1166),
  _InitialRecord(DateTime(2026, 4, 6), 1000, 1242),
  _InitialRecord(DateTime(2026, 4, 8), 2950, 1278),
  _InitialRecord(DateTime(2026, 4, 9), 2400, 1332),
  _InitialRecord(DateTime(2026, 4, 10), 2170, 1358),
  _InitialRecord(DateTime(2026, 4, 11), 1100, 1396),
  _InitialRecord(DateTime(2026, 4, 12), 5800, 1466),
  _InitialRecord(DateTime(2026, 4, 13), 4390, 1493, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 4, 14), 3300, 1539),
  _InitialRecord(DateTime(2026, 4, 15), 4600, 1567),
  _InitialRecord(DateTime(2026, 4, 16), 4310, 1594, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 4, 19), 2950, 1666),
  _InitialRecord(DateTime(2026, 4, 20), 4050, 1699, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 4, 21), 2050, 1739),
  _InitialRecord(DateTime(2026, 4, 22), 5480, 1768),
  _InitialRecord(DateTime(2026, 4, 23), 4750, 1796, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 4, 25), 3750, 1822, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 4, 25), 5250, 1867),
  _InitialRecord(DateTime(2026, 4, 27), 4000, 1911, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 4, 28), 4580, 1938),
  _InitialRecord(DateTime(2026, 4, 29), 4200, 1972),
  _InitialRecord(DateTime(2026, 4, 30), 4370, 2012, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 5, 4), 5000, 2107, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 5, 5), 5140, 2137, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 5, 6), 5110, 2177, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 5, 7), 3400, 2205, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 5, 8), 3900, 2233),
  _InitialRecord(DateTime(2026, 5, 11), 4450, 0),
  _InitialRecord(DateTime(2026, 5, 13), 5890, 2354, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 5, 14), 5600, 2385),
  _InitialRecord(DateTime(2026, 5, 15), 5600, 2421),
  _InitialRecord(DateTime(2026, 5, 16), 1750, 2439),
  _InitialRecord(DateTime(2026, 5, 18), 4800, 2429),
  _InitialRecord(DateTime(2026, 5, 20), 4000, 2485),
  _InitialRecord(DateTime(2026, 5, 21), 1200, 2513),
  _InitialRecord(DateTime(2026, 5, 21), 1200, 2541),
  _InitialRecord(DateTime(2026, 5, 23), 3100, 2588, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 5, 25), 4620, 2642),
  _InitialRecord(DateTime(2026, 5, 26), 2700, 2670, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 5, 27), 3950, 2699),
  _InitialRecord(DateTime(2026, 5, 28), 3200, 2744),
  _InitialRecord(DateTime(2026, 5, 29), 4490, 2782),
  _InitialRecord(DateTime(2026, 6, 1), 5810, 2841, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 6, 2), 5150, 2885),
  _InitialRecord(DateTime(2026, 6, 4), 4000, 2926, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 6, 6), 2600, 2954, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 6, 8), 4250, 3039, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 6, 9), 5840, 3089, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 6, 10), 4290, 3117),
  _InitialRecord(DateTime(2026, 6, 11), 4740, 3161),
  _InitialRecord(DateTime(2026, 6, 12), 5350, 3205),
  _InitialRecord(DateTime(2026, 6, 13), 4200, 3236, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 6, 15), 5700, 3289, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 6, 16), 2000, 3310),
  _InitialRecord(DateTime(2026, 6, 17), 6700, 3356, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 6, 18), 7620, 3387),
  _InitialRecord(DateTime(2026, 6, 19), 4860, 3419),
  _InitialRecord(DateTime(2026, 6, 20), 2500, 3474, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 6, 21), 7650, 3542),
  _InitialRecord(DateTime(2026, 6, 23), 6870, 3600, chargeTo80v: true),
  _InitialRecord(DateTime(2026, 6, 24), 6850, 3640),
  _InitialRecord(DateTime(2026, 6, 26), 5550, 3686),
  _InitialRecord(DateTime(2026, 6, 27), 2530, 3732),
  _InitialRecord(DateTime(2026, 6, 28), 5750, 3763),
  _InitialRecord(DateTime(2026, 6, 29), 4050, 3809),
  _InitialRecord(DateTime(2026, 6, 30), 5400, 3858),
  _InitialRecord(DateTime(2026, 7, 1), 6490, 3919),
  _InitialRecord(DateTime(2026, 7, 2), 4700, 3980),
];
