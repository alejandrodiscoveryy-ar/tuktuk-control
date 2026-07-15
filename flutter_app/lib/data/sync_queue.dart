part of '../main.dart';

class SyncQueueStore {
  SyncQueueStore() : _box = Hive.box(_syncQueueBox);

  final Box _box;

  List<SyncOperation> pendingForUser(String userId) {
    final operations = _box.values
        .map((raw) => SyncOperation.fromMap(raw as Map))
        .where((operation) => operation.userId == userId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return operations;
  }

  Future<void> enqueue({
    required SyncEntityType entityType,
    required String entityId,
    required SyncAction action,
    required String userId,
    required String vehicleId,
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
}
