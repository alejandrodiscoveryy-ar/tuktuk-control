part of '../main.dart';

class SyncQueueStore implements SyncQueueRepository {
  SyncQueueStore() : _box = Hive.box(_syncQueueBox);

  final Box _box;

  @override
  List<SyncOperation> pendingForUser(String userId, {int limit = 50}) {
    final operations = _box.values
        .map((raw) => SyncOperation.fromMap(raw as Map))
        .where((operation) => operation.userId == userId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return operations.take(limit).toList();
  }

  Future<void> enqueue({
    required SyncEntityType entityType,
    required String entityId,
    required SyncAction action,
    required String userId,
    required String vehicleId,
    Map<String, dynamic>? previousPayload,
    bool rollbackOnLicenseRejection = false,
  }) async {
    final id = '${entityType.name}:$entityId';
    final raw = _box.get(id);
    final existing = raw is Map ? SyncOperation.fromMap(raw) : null;
    final now = DateTime.now();
    final incoming = SyncOperation(
      id: id,
      entityType: entityType,
      entityId: entityId,
      action: action,
      userId: userId,
      vehicleId: vehicleId,
      createdAt: now,
      updatedAt: now,
      previousPayload: previousPayload,
      rollbackOnLicenseRejection: rollbackOnLicenseRejection,
    );
    final consolidated = SyncQueuePolicy.consolidate(existing, incoming);
    await _box.put(id, consolidated.toMap());
  }

  Future<void> reassignOwnership({
    required String fromUserId,
    required String toUserId,
    required String vehicleId,
  }) async {
    for (final raw in _box.values.toList()) {
      final operation = SyncOperation.fromMap(raw as Map);
      if (operation.userId != fromUserId) continue;
      final reassigned = operation.reassign(
        userId: toUserId,
        vehicleId: vehicleId,
      );
      await _box.put(reassigned.id, reassigned.toMap());
    }
  }

  @override
  Future<void> complete(Iterable<String> operationIds) async {
    await _box.deleteAll(operationIds);
  }

  @override
  Future<Set<String>> completeIfUnchanged(
    Iterable<SyncOperation> operations,
  ) async {
    final completed = <String>{};
    for (final sent in operations) {
      final raw = _box.get(sent.id);
      if (raw is! Map) continue;
      final current = SyncOperation.fromMap(raw);
      if (!SyncQueuePolicy.canComplete(sent, current)) continue;
      await _box.delete(sent.id);
      completed.add(sent.id);
    }
    return completed;
  }

  @override
  Future<void> markFailed(
    Iterable<String> operationIds,
    String error,
  ) async {
    for (final id in operationIds) {
      final raw = _box.get(id);
      if (raw is! Map) continue;
      final operation = SyncOperation.fromMap(raw);
      final failed = SyncOperation(
        id: operation.id,
        entityType: operation.entityType,
        entityId: operation.entityId,
        action: operation.action,
        userId: operation.userId,
        vehicleId: operation.vehicleId,
        createdAt: operation.createdAt,
        updatedAt: DateTime.now(),
        attempts: operation.attempts + 1,
        lastError: error,
        previousPayload: operation.previousPayload,
        rollbackOnLicenseRejection: operation.rollbackOnLicenseRejection,
      );
      await _box.put(id, failed.toMap());
    }
  }
}
