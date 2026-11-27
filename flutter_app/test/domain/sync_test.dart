import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('279 remote rows cross a legacy-sequence page boundary exactly once',
      () async {
    final directory = await Directory.systemTemp.createTemp('sync-pagination-');
    Hive.init(directory.path);
    await Hive.openBox('meta');
    final rows = List.generate(279, (index) => <String, dynamic>{
      'user_id': 'owner',
      'vehicle_id': 'car',
      'entity_type': 'dailyRecord',
      'entity_id': 'record-${index.toString().padLeft(3, '0')}',
      'device_id': 'server',
      'payload': {'id': 'record-${index.toString().padLeft(3, '0')}'},
      'updated_at': '2026-11-26T12:00:00Z',
      'deleted_at': null,
      'server_version': 1,
      'server_seq': index < 260 ? 0 : index - 259,
    });
    var calls = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        calls++;
        final query = request.url.queryParameters;
        expect(request.url.path, '/rest/v1/sync_entities');
        expect(query['user_id'], 'eq.owner');
        expect(query['limit'], '250');
        expect(query['order'], 'server_seq.asc.nullslast,'
          'entity_type.asc.nullslast,entity_id.asc.nullslast');
        if (calls == 1) {
          expect(query['or'], isNull);
        } else {
          expect(query['or'], '(server_seq.gt.0,'
            'and(server_seq.eq.0,entity_type.gt."dailyRecord"),'
            'and(server_seq.eq.0,entity_type.eq."dailyRecord",'
            'entity_id.gt."record-249"))');
        }
        return http.Response(jsonEncode(calls == 1
          ? rows.take(250).toList() : rows.skip(250).toList()), 200,
          headers: {'content-type': 'application/json'});
      }),
    );
    try {
      final gateway = SupabaseSyncGateway(client: client, payloadFor: (_) => null);
      final first = await gateway.pull(userId: 'owner');
      expect(first.changes, hasLength(250));
      expect(first.hasMore, isTrue);
      final second = await gateway.pull(userId: 'owner', cursor: first.nextCursor);
      expect(second.changes, hasLength(29));
      expect(second.hasMore, isFalse);
      final received = [...first.changes, ...second.changes];
      expect(received.map((row) => row.entityId).toSet(), hasLength(279));
      expect(RemoteSyncCursor.tryParse(second.nextCursor)?.serverSeq, 19);
      expect(calls, 2);
    } finally {
      await client.dispose();
      await Hive.close();
      await directory.delete(recursive: true);
    }
  });

  test('financial pagination orders identities in the direction of its cursor', () {
    final source = File('lib/data/supabase_sync_gateway.dart').readAsStringSync();
    expect(source, contains("query = query.gt('entity_id', after)"));
    expect(source, contains("query.order('entity_id', ascending: true)"));
  });

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

  test('reconstruye solo los cambios locales realmente pendientes', () {
    SyncQueueRecoveryCandidate candidate(
      String id, {
      String owner = 'user-1',
      String vehicle = 'vehicle-1',
      SyncStatus status = SyncStatus.pending,
      bool deleted = false,
    }) =>
        SyncQueueRecoveryCandidate(
          entityType: SyncEntityType.dailyRecord,
          entityId: id,
          userId: owner,
          vehicleId: vehicle,
          status: status,
          deleted: deleted,
        );

    final queue = <String>{'dailyRecord:already-queued'};
    final found = SyncQueueRecoveryPolicy.missing(
      userId: 'user-1',
      queuedIds: queue,
      local: [
        candidate('offline-1'),
        candidate('offline-delete', deleted: true),
        candidate('already-queued'),
        candidate('synced', status: SyncStatus.synced),
        candidate('other-user', owner: 'user-2'),
        candidate('no-vehicle', vehicle: ''),
        candidate('offline-1'),
      ],
    ).toList();

    expect(found.map((item) => item.entityId),
        ['offline-1', 'offline-delete']);
    expect(found.last.action, SyncAction.delete);
    expect(queue, containsAll([
      'dailyRecord:offline-1',
      'dailyRecord:offline-delete',
    ]));
  });

  test('datos sin cambiar y datos de otro usuario no se reencolan', () {
    final items = SyncQueueRecoveryPolicy.missing(
      userId: 'user-1',
      queuedIds: <String>{},
      local: [
        const SyncQueueRecoveryCandidate(
          entityType: SyncEntityType.vehicle,
          entityId: 'old-vehicle',
          userId: 'user-1',
          vehicleId: 'old-vehicle',
          status: SyncStatus.localOnly,
          deleted: false,
        ),
        const SyncQueueRecoveryCandidate(
          entityType: SyncEntityType.maintenance,
          entityId: 'other-maintenance',
          userId: 'user-2',
          vehicleId: 'other-vehicle',
          status: SyncStatus.pending,
          deleted: false,
        ),
      ],
    ).toList();
    expect(items, isEmpty);
  });

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

  test('revision de cola se conserva en almacenamiento y migra datos antiguos', () {
    final current = operation();
    expect(current.revision, 1);
    final restored = SyncOperation.fromMap(current.toMap());
    expect(restored.revision, 1);
    final legacy = Map<String, dynamic>.from(current.toMap())
      ..remove('revision');
    expect(SyncOperation.fromMap(legacy).revision, 1);
  });

  test('edicion durante el envio no se confirma aunque cambie el reloj', () {
    final sent = operation(updatedAt: DateTime.utc(2026, 7, 15, 12));
    final incoming = operation(updatedAt: DateTime.utc(2026, 7, 15, 11));
    final edited = SyncQueuePolicy.consolidate(sent, incoming);
    expect(edited.revision, sent.revision + 1);
    expect(edited.updatedAt.isBefore(sent.updatedAt), isTrue);
    expect(SyncQueuePolicy.canComplete(sent, edited), isFalse);
    expect(SyncQueuePolicy.canComplete(sent, sent), isTrue);
  });

  test('reclasificar el propietario no permite completar acuse antiguo', () {
    final sent = operation();
    final reassigned = sent.reassign(
      userId: 'new-user',
      vehicleId: 'new-vehicle',
    );
    expect(reassigned.revision, greaterThan(sent.revision));
    expect(SyncQueuePolicy.canComplete(sent, reassigned), isFalse);
  });

  test('al subir un registro se valida cuenta vehículo e identificador', () {
    final sent = operation();
    final payload = <String, dynamic>{
      'id': sent.entityId,
      'userId': sent.userId,
      'vehicleId': sent.vehicleId,
    };
    expect(SyncPayloadOwnership.matches(sent, payload), isTrue);
    expect(
      SyncPayloadOwnership.matches(sent, {...payload, 'userId': 'stranger'}),
      isFalse,
    );
    expect(
      SyncPayloadOwnership.matches(sent, {...payload, 'vehicleId': 'other'}),
      isFalse,
    );
    expect(
      SyncPayloadOwnership.matches(sent, {...payload, 'id': 'other'}),
      isFalse,
    );
  });

  test('vehículo usa su id propio aunque no tenga campo vehicleId', () {
    final source = operation();
    final vehicleOperation = SyncOperation(
      id: 'vehicle:vehicle-1',
      entityType: SyncEntityType.vehicle,
      entityId: 'vehicle-1',
      action: SyncAction.upsert,
      userId: source.userId,
      vehicleId: 'vehicle-1',
      createdAt: source.createdAt,
      updatedAt: source.updatedAt,
    );
    final legacy = <String, dynamic>{'id': 'vehicle-1', 'userId': 'user-1'};
    final wire = syncCasWirePayload(vehicleOperation, legacy);
    expect(wire['vehicleId'], 'vehicle-1');
    expect(wire['id'], wire['vehicleId']);
    expect(legacy.containsKey('vehicleId'), isFalse);
    expect(() => syncCasWirePayload(vehicleOperation, {...legacy, 'userId': 'stranger'}),
        throwsStateError);
    // VehicleProfile.toMap contiene id y userId, no vehicleId.
    expect(
      SyncPayloadOwnership.matches(vehicleOperation, {
        'id': 'vehicle-1',
        'userId': 'user-1',
      }),
      isTrue,
    );
    expect(
      SyncPayloadOwnership.matches(vehicleOperation, {
        'id': 'vehicle-1',
        'userId': 'stranger',
      }),
      isFalse,
    );
  });

  test('acuse confirmado marca registros históricos localOnly ya enviados', () {
    final sent = operation();
    expect(
      SyncReceiptPolicy.canMarkSynced(
        operation: sent,
        localUserId: sent.userId,
        localVehicleId: sent.vehicleId,
        localStatus: SyncStatus.localOnly,
        stillQueued: false,
      ),
      isTrue,
    );
  });

  test('acuse antiguo no marca sincronizada una edición pendiente', () {
    final sent = operation();
    expect(
      SyncReceiptPolicy.canMarkSynced(
        operation: sent,
        localUserId: sent.userId,
        localVehicleId: sent.vehicleId,
        localStatus: SyncStatus.pending,
        stillQueued: true,
      ),
      isFalse,
    );
    expect(
      SyncReceiptPolicy.canMarkSynced(
        operation: sent,
        localUserId: 'other',
        localVehicleId: sent.vehicleId,
        localStatus: SyncStatus.pending,
        stillQueued: false,
      ),
      isFalse,
    );
    expect(
      SyncReceiptPolicy.canMarkSynced(
        operation: sent,
        localUserId: sent.userId,
        localVehicleId: sent.vehicleId,
        localStatus: SyncStatus.pending,
        stillQueued: false,
      ),
      isTrue,
    );
  });

  test('conflicto sólo si el remoto cambió respecto de la base anterior', () {
    final base = <String, dynamic>{
      'id': 'r-1',
      'userId': 'u-1',
      'vehicleId': 'v-1',
      'note': 'Antes',
      'earnings': 100,
      'updatedAt': '2026-11-09',
      'deviceId': 'phone-a',
      'syncStatus': 'synced',
    };
    final unchangedRemote = <String, dynamic>{
      ...base,
      'updatedAt': '2026-11-09T00:00:00Z',
      'deviceId': 'phone-b',
      'syncStatus': 'synced',
    };
    expect(
      SyncMultiDeviceConflictPolicy.remoteDivergedFromBase(
        entityType: SyncEntityType.dailyRecord,
        previousPayload: base,
        localPayload: {...base, 'earnings': 150},
        remotePayload: unchangedRemote,
      ),
      isFalse,
    );
    expect(
      SyncMultiDeviceConflictPolicy.remoteDivergedFromBase(
        entityType: SyncEntityType.dailyRecord,
        previousPayload: base,
        localPayload: {...base, 'earnings': 150},
        remotePayload: {...unchangedRemote, 'earnings': 200},
      ),
      isTrue,
    );
    expect(
      SyncMultiDeviceConflictPolicy.remoteDivergedFromBase(
        entityType: SyncEntityType.dailyRecord,
        previousPayload: null,
        localPayload: {...base, 'earnings': 150},
        remotePayload: unchangedRemote,
      ),
      isTrue,
    );
  });

  test('compara vehículos sin metadato derivado vehicleId', () {
    final base = {'id': 'v-1', 'userId': 'u-1', 'name': 'Moto'};
    final remote = {...base, 'vehicleId': 'v-1'};
    expect(
      SyncMultiDeviceConflictPolicy.remoteDivergedFromBase(
        entityType: SyncEntityType.vehicle,
        previousPayload: base,
        localPayload: {...base, 'name': 'Triciclo'},
        remotePayload: remote,
      ),
      isFalse,
    );
  });

  test('reenvío de contenido idéntico no bloquea sin base previa', () {
    final same = <String, dynamic>{
      'id': 'record-1',
      'userId': 'u',
      'vehicleId': 'v',
      'earnings': 75,
    };
    expect(
      SyncMultiDeviceConflictPolicy.remoteDivergedFromBase(
        entityType: SyncEntityType.dailyRecord,
        previousPayload: null,
        localPayload: same,
        remotePayload: {...same, 'syncStatus': 'synced'},
      ),
      isFalse,
    );
  });

  test('preferencias normalizan el nombre antiguo con clave por usuario', () {
    final base = <String, dynamic>{
      'maintenanceIntervalKm': 500,
      'preferredCurrency': 'CUP',
      'preferredLanguage': 'es',
      'preferredTheme': 'dark',
      'profileDisplayName:u-1': 'Anterior',
      'settingsUpdatedAt': '2026-11-01',
    };
    final remote = <String, dynamic>{
      'maintenanceIntervalKm': 500.0,
      'preferredCurrency': 'CUP',
      'preferredLanguage': 'es',
      'preferredTheme': 'dark',
      'profileDisplayName': 'Anterior',
    };
    final local = {...remote, 'profileDisplayName': 'Actual'};
    expect(
      SyncMultiDeviceConflictPolicy.remoteDivergedFromBase(
        entityType: SyncEntityType.settings,
        previousPayload: base,
        localPayload: local,
        remotePayload: remote,
      ),
      isFalse,
    );
    expect(
      SyncMultiDeviceConflictPolicy.remoteDivergedFromBase(
        entityType: SyncEntityType.settings,
        previousPayload: base,
        localPayload: local,
        remotePayload: {...remote, 'profileDisplayName': 'Otra persona'},
      ),
      isTrue,
    );
  });

  test('un conflicto no bloquea la cola completa de otro registro', () async {
    final queue = _MemoryQueue([operationFor('blocked'), operationFor('safe')]);
    final gateway = _AcceptingGateway();
    final coordinator = SyncCoordinator(queue: queue, gateway: gateway);
    final report = await coordinator.pushPendingBatches(
      userId: 'user-1',
      excludedOperationIds: {'dailyRecord:blocked'},
      onCompletedBatch: (_) async {},
    );
    expect(report.completed, 1);
    expect(report.pendingRemaining, isTrue);
    expect(report.sendablePendingRemaining, isFalse);
    expect(queue.pendingForUser('user-1').single.id, 'dailyRecord:blocked');
    expect(gateway.batchSizes, [1]);
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

  test('cursor de servidor no depende de la fecha de edición', () {
    final lateOffline = RemoteChange(
      entityType: SyncEntityType.dailyRecord,
      entityId: 'late-offline',
      userId: 'user-1',
      vehicleId: 'vehicle-1',
      updatedAt: DateTime.utc(2026, 11, 1),
      deviceId: 'phone-a',
      payload: const {'id': 'late-offline'},
      serverVersion: 7,
      serverSeq: 91,
    );
    final encoded = RemoteSyncCursor.fromChange(lateOffline).encode();
    final decoded = RemoteSyncCursor.tryParse(encoded);
    expect(decoded, isNotNull);
    expect(decoded!.serverSeq, 91);
    expect(decoded.entityType, 'dailyRecord');
    expect(decoded.entityId, 'late-offline');
    expect(decoded.isLegacy, isFalse);
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

  test('mas de 500 cambios se envian en lotes hasta vaciar la cola', () async {
    final operations = List.generate(1001, (i) => operationFor('batch-$i'));
    final queue = _MemoryQueue(operations);
    final gateway = _AcceptingGateway();
    final coordinator = SyncCoordinator(queue: queue, gateway: gateway);
    var marked = 0;

    final report = await coordinator.pushPendingBatches(
      userId: 'user-1',
      batchSize: 500,
      maxBatches: 4,
      onCompletedBatch: (items) async => marked += items.length,
    );

    expect(gateway.batchSizes, [500, 500, 1]);
    expect(marked, 1001);
    expect(report.completed, 1001);
    expect(report.pendingRemaining, isFalse);
    expect(queue.pendingForUser('user-1'), isEmpty);
  });

  test('cola extensa no bloquea; queda pendiente para proxima ronda', () async {
    final queue = _MemoryQueue(
      List.generate(1250, (i) => operationFor('long-$i')),
    );
    final gateway = _AcceptingGateway();
    final coordinator = SyncCoordinator(queue: queue, gateway: gateway);
    final first = await coordinator.pushPendingBatches(
      userId: 'user-1',
      batchSize: 250,
      maxBatches: 3,
      onCompletedBatch: (_) async {},
    );
    expect(first.completed, 750);
    expect(first.pendingRemaining, isTrue);
    expect(queue.pendingForUser('user-1', limit: 1000), hasLength(500));
    final second = await coordinator.pushPendingBatches(
      userId: 'user-1',
      batchSize: 250,
      maxBatches: 3,
      onCompletedBatch: (_) async {},
    );
    expect(second.completed, 500);
    expect(second.pendingRemaining, isFalse);
    expect(gateway.batchSizes, [250, 250, 250, 250, 250]);
  });

  test('fallo temporal en lote conserva datos no confirmados', () async {
    final queue = _MemoryQueue(
      List.generate(4, (i) => operationFor('fail-$i')),
    );
    final gateway = _AcceptingGateway(failOnCall: 2);
    final coordinator = SyncCoordinator(queue: queue, gateway: gateway);
    final report = await coordinator.pushPendingBatches(
      userId: 'user-1',
      batchSize: 2,
      maxBatches: 4,
      onCompletedBatch: (_) async {},
    );
    expect(report.completed, 2);
    expect(report.failed, 2);
    expect(report.pendingRemaining, isTrue);
    expect(gateway.batchSizes, [2, 2]);
    expect(queue.pendingForUser('user-1', limit: 10), hasLength(2));
    expect(queue.failed, hasLength(2));
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

  test('un rechazo RLS conserva la operación para diagnóstico y reintento',
      () async {
    final pending = operation();
    final queue = _MemoryQueue([pending]);
    final coordinator = SyncCoordinator(
      queue: queue,
      gateway: _LicenseBlockedGateway(),
    );

    final report = await coordinator.pushPending(userId: 'user-1');

    expect(report.blockedByLicense, isFalse);
    expect(report.blockedOperationIds, isEmpty);
    expect(queue.completed, isEmpty);
    expect(queue.failed, contains(pending.id));
  });

  test('identifica el rechazo 42501 de RLS como bloqueo de escritura', () {
    final rejected = isAuthorizationFailureCode(
      code: '42501',
      message: 'new row violates row-level security policy',
    );

    expect(rejected, isTrue);
  });
  test('explicit retired vehicle redirect permits only acknowledged same-account history recovery', () {
    RemoteChange vehicle(String id, String target, {String owner = 'u', bool deleted = false}) =>
        RemoteChange(entityType: SyncEntityType.vehicle, entityId: id,
          userId: owner, vehicleId: target, updatedAt: DateTime.utc(2026, 9, 18),
          deletedAt: deleted ? DateTime.utc(2026, 9, 18) : null,
          deviceId: 'server', payload: const {});
    final redirects = HistoryRecoveryPolicy.confirmedVehicleRedirects([
      vehicle('old', 'canonical', deleted: true),
      vehicle('ordinary-delete', 'ordinary-delete', deleted: true),
      vehicle('foreign', 'canonical', owner: 'other', deleted: true),
      vehicle('no-destination', 'missing', deleted: true),
      vehicle('not-retired', 'canonical'),
      vehicle('canonical', 'canonical'),
    ], 'u');
    expect(redirects, {'old': 'canonical'});
    for (final type in [SyncEntityType.dailyRecord, SyncEntityType.maintenance]) {
      final remote = RemoteChange(entityType: type, entityId: 'row',
        userId: 'u', vehicleId: 'canonical', updatedAt: DateTime.utc(2026, 9, 18),
        deviceId: 'server', payload: const {});
      bool repair({String owner = 'u', String vehicleId = 'old',
        SyncStatus status = SyncStatus.synced, bool queued = false, bool full = true}) =>
          HistoryRecoveryPolicy.canRepair(fullRefresh: full, localStatus: status,
            queued: queued, localUserId: owner, localVehicleId: vehicleId,
            remote: remote, vehicleRedirects: redirects);
      expect(repair(), isTrue);
      expect(repair(owner: 'other'), isFalse);
      expect(repair(vehicleId: 'ordinary-delete'), isFalse);
      expect(repair(vehicleId: 'no-destination'), isFalse);
      expect(repair(status: SyncStatus.pending), isFalse);
      expect(repair(queued: true), isFalse);
      expect(repair(full: false), isFalse);
    }
  });

  test('verified read imports missing records and tombstones without overwriting pending or newer data', () {
    for (final type in [SyncEntityType.dailyRecord, SyncEntityType.maintenance]) {
      for (final deleted in [false, true]) {
        final remote = RemoteChange(
          entityType: type, entityId: 'record', userId: 'owner',
          vehicleId: 'canonical', updatedAt: DateTime.utc(2026, 11, 26),
          deletedAt: deleted ? DateTime.utc(2026, 11, 26) : null,
          deviceId: 'server', payload: const {}, serverVersion: 3,
        );
        bool allowed({SyncStatus? status = SyncStatus.synced,
          String owner = 'owner', String vehicle = 'canonical',
          bool queued = false, int? version = 2}) =>
          HistoryRecoveryPolicy.canImportVerifiedRow(
            remote: remote, queued: queued, localStatus: status,
            localUserId: owner, localVehicleId: vehicle,
            localServerVersion: version, vehicleRedirects: {'old': 'canonical'},
          );
        expect(allowed(), isTrue);
        expect(allowed(status: null, version: null), isTrue);
        expect(allowed(vehicle: 'old'), isTrue);
        expect(allowed(vehicle: 'unrelated'), isFalse);
        expect(allowed(owner: 'other'), isFalse);
        expect(allowed(queued: true), isFalse);
        expect(allowed(status: SyncStatus.pending), isFalse);
        expect(allowed(status: SyncStatus.localOnly), isFalse);
        expect(allowed(status: SyncStatus.conflict), isFalse);
        expect(allowed(version: 4), isFalse);
        expect(allowed(version: 3), isTrue);
        expect(allowed(status: null, version: 4), isFalse);
      }
    }
  });

  test('history recovery repairs acknowledged cache but never pending or foreign data', () {
    final remote = RemoteChange(
      entityType: SyncEntityType.dailyRecord, entityId: 'record-1',
      userId: 'user-1', vehicleId: 'vehicle-1', updatedAt: DateTime.utc(2026, 7, 1),
      deviceId: 'remote', payload: const {},
    );
    bool canRepair({bool full = true, bool queued = false,
      SyncStatus status = SyncStatus.synced, String owner = 'user-1',
      String vehicle = 'vehicle-1'}) => HistoryRecoveryPolicy.canRepair(
        fullRefresh: full, localStatus: status, queued: queued,
        localUserId: owner, localVehicleId: vehicle, remote: remote);
    expect(canRepair(), isTrue);
    expect(canRepair(full: false), isFalse);
    expect(canRepair(queued: true), isFalse);
    expect(canRepair(status: SyncStatus.pending), isFalse);
    expect(canRepair(status: SyncStatus.localOnly), isFalse);
    expect(canRepair(owner: 'another'), isFalse);
    expect(canRepair(vehicle: 'another'), isFalse);
    expect(HistoryRecoveryPolicy.missingAcknowledgedRow(
      deleted: false, status: SyncStatus.synced, queued: false, seenInCloud: false), isTrue);
    expect(HistoryRecoveryPolicy.missingAcknowledgedRow(
      deleted: true, status: SyncStatus.synced, queued: false, seenInCloud: false), isFalse);
    expect(HistoryRecoveryPolicy.missingAcknowledgedRow(
      deleted: false, status: SyncStatus.pending, queued: true, seenInCloud: false), isFalse);
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
  List<SyncOperation> pendingForUser(
    String userId, {
    int limit = 50,
    Set<String> excludedOperationIds = const <String>{},
  }) {
    return operations
        .where((operation) =>
            operation.userId == userId &&
            !excludedOperationIds.contains(operation.id))
        .take(limit)
        .toList();
  }

  @override
  Future<void> complete(Iterable<String> operationIds) async {
    final ids = operationIds.toSet();
    completed.addAll(ids);
    operations.removeWhere((item) => ids.contains(item.id));
  }

  @override
  Future<Set<String>> completeIfUnchanged(
    Iterable<SyncOperation> operations,
  ) async {
    final ids = <String>{};
    for (final sent in operations) {
      final index = this.operations.indexWhere((item) => item.id == sent.id);
      if (index < 0) continue;
      if (!SyncQueuePolicy.canComplete(sent, this.operations[index])) continue;
      this.operations.removeAt(index);
      ids.add(sent.id);
    }
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

class _AcceptingGateway implements RemoteSyncGateway {
  _AcceptingGateway({this.failOnCall});

  final int? failOnCall;
  final List<int> batchSizes = [];

  @override
  bool get isConfigured => true;

  @override
  Future<RemotePushResult> push(List<SyncOperation> operations) async {
    batchSizes.add(operations.length);
    if (batchSizes.length == failOnCall) {
      throw const TemporarySyncException('offline during upload');
    }
    return RemotePushResult(
      acceptedOperationIds: operations.map((op) => op.id).toSet(),
    );
  }

  @override
  Future<RemotePullResult> pull({
    required String userId,
    String? cursor,
    int limit = 250,
  }) async => const RemotePullResult(changes: [], nextCursor: null);
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
