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
    );
  }
}

abstract final class SyncQueuePolicy {
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
    );
  }
}

abstract interface class SyncQueueRepository {
  List<SyncOperation> pendingForUser(String userId, {int limit = 50});

  Future<void> complete(Iterable<String> operationIds);

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
  });

  final List<RemoteChange> changes;
  final String? nextCursor;
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
  });

  final int attempted;
  final int completed;
  final int failed;
  final bool skippedBecauseUnconfigured;
}
