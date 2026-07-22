part of '../main.dart';

enum SyncStatus { localOnly, pending, synced, conflict, failed }

abstract final class OwnershipPolicy {
  static bool canClaimLocalData(String? claimedUserId, String candidateUserId) {
    return claimedUserId == null ||
        claimedUserId.isEmpty ||
        claimedUserId == candidateUserId;
  }

  static bool acceptsBackup(String activeUserId, String? backupUserId) {
    return true;
  }

  static bool shouldLoadHistoricalSeed(Object? seedVersion) {
    return seedVersion != null;
  }
}

SyncStatus _syncStatusFromMap(dynamic value) {
  return SyncStatus.values.firstWhere(
    (status) => status.name == '$value',
    orElse: () => SyncStatus.localOnly,
  );
}

class DailyRecord {
  static const int batteryVoltageHiveFieldIndex = 17;

  DailyRecord({
    required this.id,
    required this.date,
    required this.earnings,
    required this.odometer,
    this.expense = 0,
    this.expenseCategory = '',
    this.batteryVoltage,
    this.note = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    this.deviceId = '',
    this.userId = '',
    this.vehicleId = '',
    this.syncStatus = SyncStatus.localOnly,
    this.schemaVersion = _databaseSchemaVersion,
  })  : createdAt = createdAt ?? updatedAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final DateTime date;
  final double earnings;
  final double odometer;
  final double expense;
  final String expenseCategory;
  @HiveField(batteryVoltageHiveFieldIndex)
  final double? batteryVoltage;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String deviceId;
  final String userId;
  final String vehicleId;
  final SyncStatus syncStatus;
  final int schemaVersion;

  bool get isDeleted => deletedAt != null;

  factory DailyRecord.fromMap(Map<dynamic, dynamic> map) {
    final parsedUpdatedAt =
        DateTime.tryParse('${map['updatedAt']}') ?? DateTime.now();
    final legacyNote = '${map['note'] ?? ''}';
    final noteVoltage = _extractLegacyVoltage(legacyNote);
    final voltage = _optionalNum(map['batteryVoltage']) ??
        _optionalNum(map['batteryPercent']) ??
        noteVoltage.value ??
        (map['chargeTo80v'] == true ? 80.0 : null);
    return DailyRecord(
      id: '${map['id']}',
      date: DateTime.parse('${map['date']}'),
      earnings: _numFromMap(map, 'earnings'),
      odometer: _numFromMap(map, 'odometer'),
      expense: _numFromMap(map, 'expense'),
      expenseCategory: '${map['expenseCategory'] ?? ''}',
      batteryVoltage: voltage,
      note: noteVoltage.cleanedNote,
      createdAt: DateTime.tryParse('${map['createdAt']}') ?? parsedUpdatedAt,
      updatedAt: parsedUpdatedAt,
      deletedAt: DateTime.tryParse('${map['deletedAt'] ?? ''}'),
      deviceId: '${map['deviceId'] ?? ''}',
      userId: '${map['userId'] ?? ''}',
      vehicleId: '${map['vehicleId'] ?? ''}',
      syncStatus: _syncStatusFromMap(map['syncStatus']),
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'date': DateFormat('yyyy-MM-dd').format(date),
        'earnings': earnings,
        'odometer': odometer,
        'expense': expense,
        'expenseCategory': expenseCategory,
        'batteryVoltage': batteryVoltage,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
        'deviceId': deviceId,
        'userId': userId,
        'vehicleId': vehicleId,
        'syncStatus': syncStatus.name,
      };

  DailyRecord withSyncInfo({
    required String deviceId,
    String? userId,
    String? vehicleId,
    SyncStatus? syncStatus,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return DailyRecord(
      id: id,
      date: date,
      earnings: earnings,
      odometer: odometer,
      expense: expense,
      expenseCategory: expenseCategory,
      batteryVoltage: batteryVoltage,
      note: note,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: this.deviceId.isEmpty ? deviceId : this.deviceId,
      userId: userId ?? this.userId,
      vehicleId: vehicleId ?? this.vehicleId,
      syncStatus: syncStatus ?? this.syncStatus,
      schemaVersion: _databaseSchemaVersion,
    );
  }
}

double? _optionalNum(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.'));
  return null;
}

({double? value, String cleanedNote}) _extractLegacyVoltage(String note) {
  final pattern = RegExp(
    r'\bVoltaje\s*:\s*(-?\d+(?:[\.,]\d+)?)\s*V\b',
    caseSensitive: false,
  );
  final match = pattern.firstMatch(note);
  if (match == null) return (value: null, cleanedNote: note);
  final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
  final cleaned = note
      .replaceRange(match.start, match.end, '')
      .replaceAll(RegExp(r'^\s*[-|;]\s*'), '')
      .replaceAll(RegExp(r'\s*[-|;]\s*$'), '')
      .replaceAll(RegExp(r'^\s*$\n?', multiLine: true), '')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .trim();
  return (value: value, cleanedNote: cleaned);
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
    this.userId = '',
    this.vehicleId = '',
    this.syncStatus = SyncStatus.localOnly,
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
  final String userId;
  final String vehicleId;
  final SyncStatus syncStatus;
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
      userId: '${map['userId'] ?? ''}',
      vehicleId: '${map['vehicleId'] ?? ''}',
      syncStatus: _syncStatusFromMap(map['syncStatus']),
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
        'userId': userId,
        'vehicleId': vehicleId,
        'syncStatus': syncStatus.name,
      };

  MaintenanceRecord withSyncInfo({
    required String deviceId,
    String? userId,
    String? vehicleId,
    SyncStatus? syncStatus,
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
      userId: userId ?? this.userId,
      vehicleId: vehicleId ?? this.vehicleId,
      syncStatus: syncStatus ?? this.syncStatus,
      schemaVersion: _databaseSchemaVersion,
    );
  }
}

class VehicleProfile {
  VehicleProfile({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.registration = '',
    this.initialOdometer = 0,
    this.deviceId = '',
    this.syncStatus = SyncStatus.localOnly,
    this.deletedAt,
    this.schemaVersion = _databaseSchemaVersion,
  });

  final String id;
  final String userId;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String registration;
  final double initialOdometer;
  final String deviceId;
  final SyncStatus syncStatus;
  final DateTime? deletedAt;
  final int schemaVersion;

  bool get isDeleted => deletedAt != null;

  factory VehicleProfile.fromMap(Map<dynamic, dynamic> map) {
    final now = DateTime.now();
    final updatedAt = DateTime.tryParse('${map['updatedAt']}') ?? now;
    return VehicleProfile(
      id: '${map['id'] ?? ''}',
      userId: '${map['userId'] ?? map['ownerUserId'] ?? ''}',
      name: '${map['name'] ?? 'Mi Tuk Tuk'}',
      createdAt: DateTime.tryParse('${map['createdAt']}') ?? updatedAt,
      updatedAt: updatedAt,
      registration: '${map['registration'] ?? ''}',
      initialOdometer: (map['initialOdometer'] as num?)?.toDouble() ?? 0,
      deviceId: '${map['deviceId'] ?? ''}',
      syncStatus: _syncStatusFromMap(map['syncStatus']),
      deletedAt: DateTime.tryParse('${map['deletedAt'] ?? ''}'),
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'userId': userId,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'registration': registration,
        'initialOdometer': initialOdometer,
        'deviceId': deviceId,
        'syncStatus': syncStatus.name,
        'deletedAt': deletedAt?.toIso8601String(),
      };

  VehicleProfile withSyncInfo({
    required String deviceId,
    String? userId,
    SyncStatus? syncStatus,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return VehicleProfile(
      id: id,
      userId: userId ?? this.userId,
      name: name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      registration: registration,
      initialOdometer: initialOdometer,
      deviceId: this.deviceId.isEmpty ? deviceId : this.deviceId,
      syncStatus: syncStatus ?? this.syncStatus,
      deletedAt: deletedAt ?? this.deletedAt,
      schemaVersion: _databaseSchemaVersion,
    );
  }
}
