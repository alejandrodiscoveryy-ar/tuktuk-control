import 'dart:io';

import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('tuktuk-offline-');
    Hive.init(hiveDirectory.path);
    await Hive.openBox('sync_queue');
  });

  tearDown(() async {
    await Hive.box('sync_queue').clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test(
    'la cola offline sobrevive al reinicio y no duplica la entidad',
    () async {
      final firstStore = SyncQueueStore();
      await firstStore.enqueue(
        entityType: SyncEntityType.dailyRecord,
        entityId: 'record-offline-1',
        action: SyncAction.upsert,
        userId: 'user-1',
        vehicleId: 'vehicle-1',
      );
      await firstStore.enqueue(
        entityType: SyncEntityType.dailyRecord,
        entityId: 'record-offline-1',
        action: SyncAction.upsert,
        userId: 'user-1',
        vehicleId: 'vehicle-1',
      );

      final storeAfterRestart = SyncQueueStore();
      final pending = storeAfterRestart.pendingForUser('user-1');

      expect(pending, hasLength(1));
      expect(pending.single.entityId, 'record-offline-1');
    },
  );

  test('una edición durante el envío permanece pendiente', () async {
    final store = SyncQueueStore();
    await store.enqueue(
      entityType: SyncEntityType.dailyRecord,
      entityId: 'record-offline-2',
      action: SyncAction.upsert,
      userId: 'user-1',
      vehicleId: 'vehicle-1',
    );
    final sent = store.pendingForUser('user-1').single;
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await store.enqueue(
      entityType: SyncEntityType.dailyRecord,
      entityId: 'record-offline-2',
      action: SyncAction.upsert,
      userId: 'user-1',
      vehicleId: 'vehicle-1',
    );

    final completed = await store.completeIfUnchanged([sent]);

    expect(completed, isEmpty);
    expect(store.pendingForUser('user-1'), hasLength(1));
  });

  test('al recuperar conexión sincroniza una vez y vacía la cola', () async {
    final store = SyncQueueStore();
    await store.enqueue(
      entityType: SyncEntityType.dailyRecord,
      entityId: 'record-offline-3',
      action: SyncAction.upsert,
      userId: 'user-1',
      vehicleId: 'vehicle-1',
    );
    final gateway = _ReconnectGateway();
    final coordinator = SyncCoordinator(queue: store, gateway: gateway);

    final offline = await coordinator.pushPending(userId: 'user-1');
    final online = await coordinator.pushPending(userId: 'user-1');

    expect(offline.failed, 1);
    expect(online.completed, 1);
    expect(gateway.successfulEntityIds, {'record-offline-3'});
    expect(store.pendingForUser('user-1'), isEmpty);
  });
}

class _ReconnectGateway implements RemoteSyncGateway {
  var calls = 0;
  final Set<String> successfulEntityIds = {};

  @override
  bool get isConfigured => true;

  @override
  Future<RemotePushResult> push(List<SyncOperation> operations) async {
    calls++;
    if (calls == 1) throw const TemporarySyncException('offline');
    successfulEntityIds.addAll(
      operations.map((operation) => operation.entityId),
    );
    return RemotePushResult(
      acceptedOperationIds:
          operations.map((operation) => operation.id).toSet(),
    );
  }

  @override
  Future<RemotePullResult> pull({
    required String userId,
    String? cursor,
    int limit = 250,
  }) async =>
      const RemotePullResult(changes: [], nextCursor: null);
}
