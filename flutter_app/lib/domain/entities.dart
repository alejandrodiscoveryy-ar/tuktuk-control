part of '../main.dart';

enum SyncStatus { localOnly, pending, synced, conflict, failed }

abstract final class OwnershipPolicy {
  static bool canClaimLocalData(String? claimedUserId, String candidateUserId) {
    return claimedUserId == null ||
        claimedUserId.isEmpty ||
        claimedUserId == candidateUserId;
  }

  static bool acceptsBackup(String activeUserId, String? backupUserId) {
    return backupUserId == null ||
        backupUserId.isEmpty ||
        backupUserId == activeUserId;
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
  final int? batteryPercent;
  final bool chargeTo80v;
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
        'batteryPercent': batteryPercent,
        'chargeTo80v': chargeTo80v,
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
      batteryPercent: batteryPercent,
      chargeTo80v: chargeTo80v,
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
  const VehicleProfile({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory VehicleProfile.fromMap(Map<dynamic, dynamic> map) => VehicleProfile(
        id: '${map['id']}',
        userId: '${map['userId']}',
        name: '${map['name'] ?? 'Mi Tuk Tuk'}',
        createdAt: DateTime.parse('${map['createdAt']}'),
        updatedAt: DateTime.parse('${map['updatedAt']}'),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
