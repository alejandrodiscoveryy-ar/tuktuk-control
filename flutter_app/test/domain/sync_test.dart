import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SyncOperation operation({
    SyncAction action = SyncAction.upsert,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final created = createdAt ?? DateTime.utc(2026, 7, 15, 10);
    return SyncOperation(
      id: 'dailyRecord:record-1',
      entityType: SyncEntityType.dailyRecord,
      entityId: 'record-1',
      action: action,
      userId: 'user-1',
      vehicleId: 'vehicle-1',
      createdAt: created,
      updatedAt: updatedAt ?? created,
    );
  }

  test('SyncOperation conserva todos sus campos al serializar', () {
    final original = operation();

    final restored = SyncOperation.fromMap(original.toMap());

    expect(restored.id, original.id);
    expect(restored.entityType, SyncEntityType.dailyRecord);
    expect(restored.action, SyncAction.upsert);
    expect(restored.userId, 'user-1');
    expect(restored.vehicleId, 'vehicle-1');
    expect(restored.createdAt, original.createdAt);
  });

  test('la cola consolida cambios repetidos de la misma entidad', () {
    final first = operation();
    final latest = operation(
      updatedAt: DateTime.utc(2026, 7, 15, 11),
    );

    final result = SyncQueuePolicy.consolidate(first, latest);

    expect(result.id, first.id);
    expect(result.createdAt, first.createdAt);
    expect(result.updatedAt, latest.updatedAt);
    expect(result.action, SyncAction.upsert);
  });

  test('una eliminación reemplaza la actualización pendiente', () {
    final first = operation();
    final deletion = operation(
      action: SyncAction.delete,
      updatedAt: DateTime.utc(2026, 7, 15, 12),
    );

    final result = SyncQueuePolicy.consolidate(first, deletion);

    expect(result.action, SyncAction.delete);
    expect(result.createdAt, first.createdAt);
  });

  test('una edición nueva no se completa con una respuesta anterior', () {
    final sent = operation(updatedAt: DateTime.utc(2026, 7, 15, 10));
    final editedWhileSending =
        operation(updatedAt: DateTime.utc(2026, 7, 15, 10, 1));

    expect(SyncQueuePolicy.canComplete(sent, editedWhileSending), isFalse);
    expect(SyncQueuePolicy.canComplete(sent, sent), isTrue);
  });

  test('la propiedad pendiente puede migrarse a la cuenta Google', () {
    final local = operation();

    final claimed = local.reassign(
      userId: 'google-user',
      vehicleId: 'google-vehicle',
    );

    expect(claimed.id, local.id);
    expect(claimed.entityId, local.entityId);
    expect(claimed.userId, 'google-user');
    expect(claimed.vehicleId, 'google-vehicle');
  });

  test('ConflictResolver prioriza el cambio más reciente', () {
    final local = ConflictCandidate(
      updatedAt: DateTime.utc(2026, 7, 15, 10),
      deviceId: 'device-a',
    );
    final remote = ConflictCandidate(
      updatedAt: DateTime.utc(2026, 7, 15, 11),
      deviceId: 'device-b',
    );

    expect(
      ConflictResolver.resolve(local: local, remote: remote),
      ConflictWinner.remote,
    );
  });

  test('ConflictResolver conserva una eliminación con fecha empatada', () {
    final timestamp = DateTime.utc(2026, 7, 15, 10);
    final local = ConflictCandidate(
      updatedAt: timestamp,
      deletedAt: timestamp,
      deviceId: 'device-a',
    );
    final remote = ConflictCandidate(
      updatedAt: timestamp,
      deviceId: 'device-b',
    );

    expect(
      ConflictResolver.resolve(local: local, remote: remote),
      ConflictWinner.local,
    );
  });

  test('SyncCoordinator procesa aceptados y conserva rechazados', () async {
    final queue = _MemoryQueue([operation(), operationFor('record-2')]);
    final gateway = _FakeGateway(
      result: const RemotePushResult(
        acceptedOperationIds: {'dailyRecord:record-1'},
        rejectedOperations: {'dailyRecord:record-2': 'conflict'},
      ),
    );
    final coordinator = SyncCoordinator(queue: queue, gateway: gateway);

    final report = await coordinator.pushPending(userId: 'user-1');

    expect(report.attempted, 2);
    expect(report.completed, 1);
    expect(report.failed, 1);
    expect(queue.completed, {'dailyRecord:record-1'});
    expect(queue.failed['dailyRecord:record-2'], 'conflict');
  });

  test('SyncCoordinator no procesa cuando el gateway no está configurado',
      () async {
    final queue = _MemoryQueue([operation()]);
    final gateway = _FakeGateway(configured: false);
    final coordinator = SyncCoordinator(queue: queue, gateway: gateway);

    final report = await coordinator.pushPending(userId: 'user-1');

    expect(report.skippedBecauseUnconfigured, isTrue);
    expect(gateway.pushCalls, 0);
    expect(queue.completed, isEmpty);
  });

  test('un fallo temporal conserva la operación para reintentar', () async {
    final pending = operation();
    final queue = _MemoryQueue([pending]);
    final coordinator = SyncCoordinator(
      queue: queue,
      gateway: _TemporaryFailureGateway(),
    );

    final report = await coordinator.pushPending(userId: 'user-1');

    expect(report.failed, 1);
    expect(queue.completed, isEmpty);
    expect(queue.failed, contains(pending.id));
  });

  test('el cursor paginado conserva desempate estable y cursor antiguo', () {
    final change = RemoteChange(
      entityType: SyncEntityType.dailyRecord,
      entityId: 'record-250',
      userId: 'user-1',
      vehicleId: 'vehicle-1',
      updatedAt: DateTime.utc(2026, 7, 15, 10, 30),
      deviceId: 'device-a',
      payload: const {},
    );

    final encoded = RemoteSyncCursor.fromChange(change).encode();
    final restored = RemoteSyncCursor.tryParse(encoded);
    final legacy = RemoteSyncCursor.tryParse('2026-07-15T10:30:00.000Z');

    expect(restored?.updatedAt, change.updatedAt);
    expect(restored?.entityType, SyncEntityType.dailyRecord.name);
    expect(restored?.entityId, 'record-250');
    expect(restored?.isLegacy, isFalse);
    expect(legacy?.isLegacy, isTrue);
  });

  test('un rechazo RLS se retira de la cola y no se reintenta', () async {
    final pending = operation();
    final queue = _MemoryQueue([pending]);
    final coordinator = SyncCoordinator(
      queue: queue,
      gateway: _LicenseBlockedGateway(),
    );

    final report = await coordinator.pushPending(userId: 'user-1');

    expect(report.blockedByLicense, isTrue);
    expect(report.blockedOperationIds, {pending.id});
    expect(queue.completed, {pending.id});
    expect(queue.failed, isEmpty);
  });

  test('identifica el rechazo 42501 de RLS como bloqueo de escritura', () {
    final rejected = isAuthorizationFailureCode(
      code: '42501',
      message: 'new row violates row-level security policy',
    );

    expect(rejected, isTrue);
  });
}

SyncOperation operationFor(String entityId) {
  final now = DateTime.utc(2026, 7, 15, 10);
  return SyncOperation(
    id: 'dailyRecord:$entityId',
    entityType: SyncEntityType.dailyRecord,
    entityId: entityId,
    action: SyncAction.upsert,
    userId: 'user-1',
    vehicleId: 'vehicle-1',
    createdAt: now,
    updatedAt: now,
  );
}

class _MemoryQueue implements SyncQueueRepository {
  _MemoryQueue(this.operations);

  final List<SyncOperation> operations;
  final Set<String> completed = {};
  final Map<String, String> failed = {};

  @override
  List<SyncOperation> pendingForUser(String userId, {int limit = 50}) {
    return operations
        .where((operation) => operation.userId == userId)
        .take(limit)
        .toList();
  }

  @override
  Future<void> complete(Iterable<String> operationIds) async {
    completed.addAll(operationIds);
  }

  @override
  Future<Set<String>> completeIfUnchanged(
    Iterable<SyncOperation> operations,
  ) async {
    final ids = operations.map((operation) => operation.id).toSet();
    completed.addAll(ids);
    return ids;
  }

  @override
  Future<void> markFailed(
    Iterable<String> operationIds,
    String error,
  ) async {
    for (final id in operationIds) {
      failed[id] = error;
    }
  }
}

class _FakeGateway implements RemoteSyncGateway {
  _FakeGateway({
    this.configured = true,
    this.result = const RemotePushResult(acceptedOperationIds: {}),
  });

  final bool configured;
  final RemotePushResult result;
  int pushCalls = 0;

  @override
  bool get isConfigured => configured;

  @override
  Future<RemotePushResult> push(List<SyncOperation> operations) async {
    pushCalls++;
    return result;
  }

  @override
  Future<RemotePullResult> pull({
    required String userId,
    String? cursor,
    int limit = 250,
  }) async {
    return const RemotePullResult(changes: [], nextCursor: null);
  }
}

class _LicenseBlockedGateway implements RemoteSyncGateway {
  @override
  bool get isConfigured => true;

  @override
  Future<RemotePullResult> pull({
    required String userId,
    String? cursor,
    int limit = 250,
  }) async =>
      const RemotePullResult(changes: [], nextCursor: null);

  @override
  Future<RemotePushResult> push(List<SyncOperation> operations) {
    throw const LicenseWriteRejectedException('RLS');
  }
}

class _TemporaryFailureGateway implements RemoteSyncGateway {
  @override
  bool get isConfigured => true;

  @override
  Future<RemotePullResult> pull({
    required String userId,
    String? cursor,
    int limit = 250,
  }) async =>
      const RemotePullResult(changes: [], nextCursor: null);

  @override
  Future<RemotePushResult> push(List<SyncOperation> operations) {
    throw const TemporarySyncException('offline');
  }
}
