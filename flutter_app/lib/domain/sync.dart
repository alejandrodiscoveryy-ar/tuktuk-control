part of '../main.dart';

enum SyncEntityType { dailyRecord, maintenance, vehicle, settings }

enum SyncAction { upsert, delete }

class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.userId,
    required this.vehicleId,
    required this.createdAt,
    required this.updatedAt,
    this.attempts = 0,
    this.lastError,
    this.previousPayload,
    this.rollbackOnLicenseRejection = false,
  });

  final String id;
  final SyncEntityType entityType;
  final String entityId;
  final SyncAction action;
  final String userId;
  final String vehicleId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int attempts;
  final String? lastError;
  final Map<String, dynamic>? previousPayload;
  final bool rollbackOnLicenseRejection;

  factory SyncOperation.fromMap(Map<dynamic, dynamic> map) => SyncOperation(
        id: '${map['id']}',
        entityType: SyncEntityType.values.firstWhere(
          (value) => value.name == '${map['entityType']}',
        ),
        entityId: '${map['entityId']}',
        action: SyncAction.values.firstWhere(
          (value) => value.name == '${map['action']}',
        ),
        userId: '${map['userId']}',
        vehicleId: '${map['vehicleId']}',
        createdAt: DateTime.parse('${map['createdAt']}'),
        updatedAt: DateTime.parse('${map['updatedAt']}'),
        attempts: (map['attempts'] as num?)?.toInt() ?? 0,
        lastError: map['lastError'] == null ? null : '${map['lastError']}',
        previousPayload: map['previousPayload'] is Map
            ? Map<String, dynamic>.from(map['previousPayload'] as Map)
            : null,
        rollbackOnLicenseRejection: map['rollbackOnLicenseRejection'] == true,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'entityType': entityType.name,
        'entityId': entityId,
        'action': action.name,
        'userId': userId,
        'vehicleId': vehicleId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'attempts': attempts,
        'lastError': lastError,
        'previousPayload': previousPayload,
        'rollbackOnLicenseRejection': rollbackOnLicenseRejection,
      };

  SyncOperation reassign({
    required String userId,
    required String vehicleId,
  }) {
    return SyncOperation(
      id: id,
      entityType: entityType,
      entityId: entityId,
      action: action,
      userId: userId,
      vehicleId: vehicleId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      attempts: attempts,
      lastError: lastError,
      previousPayload: previousPayload,
      rollbackOnLicenseRejection: rollbackOnLicenseRejection,
    );
  }
}

abstract final class SyncQueuePolicy {
  static bool canComplete(SyncOperation sent, SyncOperation current) =>
      !current.updatedAt.isAfter(sent.updatedAt);

  static SyncOperation consolidate(
    SyncOperation? existing,
    SyncOperation incoming,
  ) {
    if (existing == null) return incoming;
    return SyncOperation(
      id: existing.id,
      entityType: incoming.entityType,
      entityId: incoming.entityId,
      action: incoming.action,
      userId: incoming.userId,
      vehicleId: incoming.vehicleId,
      createdAt: existing.createdAt,
      updatedAt: incoming.updatedAt,
      previousPayload: existing.previousPayload ?? incoming.previousPayload,
      rollbackOnLicenseRejection: existing.rollbackOnLicenseRejection ||
          incoming.rollbackOnLicenseRejection,
    );
  }
}

abstract interface class SyncQueueRepository {
  List<SyncOperation> pendingForUser(String userId, {int limit = 50});

  Future<void> complete(Iterable<String> operationIds);

  Future<Set<String>> completeIfUnchanged(
    Iterable<SyncOperation> operations,
  );

  Future<void> markFailed(
    Iterable<String> operationIds,
    String error,
  );
}

class RemotePushResult {
  const RemotePushResult({
    required this.acceptedOperationIds,
    this.rejectedOperations = const {},
  });

  final Set<String> acceptedOperationIds;
  final Map<String, String> rejectedOperations;
}

class RemotePullResult {
  const RemotePullResult({
    required this.changes,
    required this.nextCursor,
    this.hasMore = false,
  });

  final List<RemoteChange> changes;
  final String? nextCursor;
  final bool hasMore;
}

class RemoteSyncCursor {
  const RemoteSyncCursor({
    required this.updatedAt,
    required this.entityType,
    required this.entityId,
    this.isLegacy = false,
  });

  final DateTime updatedAt;
  final String entityType;
  final String entityId;
  final bool isLegacy;

  factory RemoteSyncCursor.fromChange(RemoteChange change) => RemoteSyncCursor(
        updatedAt: change.updatedAt.toUtc(),
        entityType: change.entityType.name,
        entityId: change.entityId,
      );

  static RemoteSyncCursor? tryParse(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(value))),
      );
      if (decoded is! Map) return null;
      final updatedAt = DateTime.tryParse('${decoded['updatedAt']}');
      if (updatedAt == null) return null;
      return RemoteSyncCursor(
        updatedAt: updatedAt.toUtc(),
        entityType: '${decoded['entityType'] ?? ''}',
        entityId: '${decoded['entityId'] ?? ''}',
      );
    } catch (_) {
      final legacyTimestamp = DateTime.tryParse(value);
      return legacyTimestamp == null
          ? null
          : RemoteSyncCursor(
              updatedAt: legacyTimestamp.toUtc(),
              entityType: '',
              entityId: '',
              isLegacy: true,
            );
    }
  }

  String encode() => base64Url.encode(
        utf8.encode(
          jsonEncode({
            'version': 1,
            'updatedAt': updatedAt.toUtc().toIso8601String(),
            'entityType': entityType,
            'entityId': entityId,
          }),
        ),
      );
}

class RemoteChange {
  const RemoteChange({
    required this.entityType,
    required this.entityId,
    required this.userId,
    required this.vehicleId,
    required this.updatedAt,
    required this.deviceId,
    required this.payload,
    this.deletedAt,
  });

  final SyncEntityType entityType;
  final String entityId;
  final String userId;
  final String vehicleId;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String deviceId;
  final Map<String, dynamic> payload;
}

abstract interface class RemoteSyncGateway {
  bool get isConfigured;

  Future<RemotePushResult> push(List<SyncOperation> operations);

  Future<RemotePullResult> pull({
    required String userId,
    String? cursor,
    int limit = 250,
  });
}

enum ConflictWinner { local, remote }

class ConflictCandidate {
  const ConflictCandidate({
    required this.updatedAt,
    required this.deviceId,
    this.deletedAt,
  });

  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String deviceId;
}

abstract final class ConflictResolver {
  static ConflictWinner resolve({
    required ConflictCandidate local,
    required ConflictCandidate remote,
  }) {
    if (local.updatedAt.isAfter(remote.updatedAt)) return ConflictWinner.local;
    if (remote.updatedAt.isAfter(local.updatedAt)) {
      return ConflictWinner.remote;
    }
    if (local.deletedAt != null && remote.deletedAt == null) {
      return ConflictWinner.local;
    }
    if (remote.deletedAt != null && local.deletedAt == null) {
      return ConflictWinner.remote;
    }
    return local.deviceId.compareTo(remote.deviceId) >= 0
        ? ConflictWinner.local
        : ConflictWinner.remote;
  }
}

class SyncRunReport {
  const SyncRunReport({
    required this.attempted,
    required this.completed,
    required this.failed,
    this.skippedBecauseUnconfigured = false,
    this.completedOperationIds = const {},
    this.blockedByLicense = false,
    this.blockedOperationIds = const {},
  });

  final int attempted;
  final int completed;
  final int failed;
  final bool skippedBecauseUnconfigured;
  final Set<String> completedOperationIds;
  final bool blockedByLicense;
  final Set<String> blockedOperationIds;
}

class TemporarySyncException implements Exception {
  const TemporarySyncException(this.cause);

  final Object cause;

  @override
  String toString() => 'TemporarySyncException($cause)';
}
