part of '../main.dart';

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
