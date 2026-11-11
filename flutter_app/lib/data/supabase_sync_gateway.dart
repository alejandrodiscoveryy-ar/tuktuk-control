part of '../main.dart';

typedef SyncPayloadResolver = Map<String, dynamic>? Function(
    SyncOperation operation);

class SupabaseSyncGateway implements RemoteSyncGateway {
  SupabaseSyncGateway({
    required SupabaseClient client,
    required SyncPayloadResolver payloadFor,
  })  : _client = client,
        _payloadFor = payloadFor;

  static const tableName = 'sync_entities';
  static const defaultPageSize = 250;

  final SupabaseClient _client;
  final SyncPayloadResolver _payloadFor;
  final Box _syncMeta = Hive.box(_metaBox);

  String _versionKey(SyncOperation op) =>
      'syncVersion:${op.userId}:${op.id}';

  @override
  bool get isConfigured => _client.auth.currentUser != null;

  @override
  Future<RemotePushResult> push(List<SyncOperation> operations) async {
    if (operations.isEmpty) {
      return const RemotePushResult(acceptedOperationIds: {});
    }

    final rows = <Map<String, dynamic>>[];
    final accepted = <String>{};
    final rejected = <String, String>{};
    for (final operation in operations) {
      final payload = _payloadFor(operation);
      if (payload == null) {
        rejected[operation.id] = 'El registro local ya no existe';
        continue;
      }
      if (!SyncPayloadOwnership.matches(operation, payload)) {
        rejected[operation.id] =
            'El registro local no coincide con el propietario o vehículo.';
        continue;
      }
      final updatedAt =
          DateTime.tryParse('${payload['updatedAt']}') ?? operation.updatedAt;
      rows.add({
        'user_id': operation.userId,
        'vehicle_id': operation.vehicleId,
        'entity_type': operation.entityType.name,
        'entity_id': operation.entityId,
        'device_id': '${payload['deviceId'] ?? ''}',
        'payload': payload,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'deleted_at': payload['deletedAt'],
        'previous_payload': operation.previousPayload ??
            _syncMeta.get('syncOverride:${operation.userId}:${operation.id}'),
        'expected_version': _syncMeta.get(_versionKey(operation)),
      });
      accepted.add(operation.id);
    }

    if (rows.isNotEmpty) {
      try {
        // La RPC aplica cada cambio con verificación atómica. Un upsert
        // directo podría sobrescribir el trabajo de otro dispositivo.
        final response = await _client.rpc(
          'sync_entities_push_cas',
          params: {'p_rows': rows},
        );
        if (response is! Map) {
          throw const FormatException('Respuesta de sincronización inesperada.');
        }
        final result = Map<String, dynamic>.from(response);
        final acknowledgments = result['accepted'];
        final conflicts = result['conflicts'];
        if (acknowledgments is! List || conflicts is! List) {
          throw const FormatException('Acuse de sincronización incompleto.');
        }

        final acceptedByServer = <String>{};
        for (final item in acknowledgments) {
          if (item is! Map) continue;
          final ack = Map<String, dynamic>.from(item);
          final id = ack['id']?.toString();
          if (id == null || !accepted.contains(id)) continue;
          final op = operations.where((o) => o.id == id).first;
          // Persistir el acuse/version antes de retirar el cambio de la cola.
          final version = (ack['server_version'] as num?)?.toInt();
          if (version != null) await _syncMeta.put(_versionKey(op), version);
          await _syncMeta.delete('syncOverride:${op.userId}:${op.id}');
          acceptedByServer.add(id);
        }

        for (final item in conflicts) {
          if (item is! Map) continue;
          final conflict = Map<String, dynamic>.from(item);
          final id = conflict['id']?.toString();
          if (id == null || !accepted.contains(id)) continue;
          final operation = operations.where((o) => o.id == id).first;
          final payload = _payloadFor(operation);
          final key = 'syncConflict:${operation.userId}:$id';
          if (_syncMeta.containsKey(key)) continue;
          await _syncMeta.put(key, <String, dynamic>{
            'operationId': id,
            'entityId': operation.entityId,
            'entityType': operation.entityType.name,
            'userId': operation.userId,
            'vehicleId': operation.vehicleId,
            'savedAt': DateTime.now().toUtc().toIso8601String(),
            'localPayload': payload,
            'remotePayload': conflict['remote_payload'],
            'remoteVehicleId': conflict['remote_vehicle_id'],
            'remoteDeviceId': conflict['remote_device_id'],
            'remoteUpdatedAt': conflict['remote_updated_at'],
            'remoteDeletedAt': conflict['remote_deleted_at'],
            'remoteVersion': conflict['server_version'],
            'localOperation': operation.toMap(),
            'ownershipMismatch': false,
          });
        }
        accepted
          ..clear()
          ..addAll(acceptedByServer);
      } catch (error) {
        if (isSupabaseAuthorizationFailure(error)) {
          throw LicenseWriteRejectedException(error);
        }
        rethrow;
      }
    }
    return RemotePushResult(
      acceptedOperationIds: accepted,
      rejectedOperations: rejected,
    );
  }

  @override
  Future<RemotePullResult> pull({
    required String userId,
    String? cursor,
    int limit = defaultPageSize,
  }) async {
    final safeLimit = limit.clamp(1, 500);
    final parsedCursor = RemoteSyncCursor.tryParse(cursor);
    dynamic query = _client
        .from(tableName)
        .select(
          'user_id,vehicle_id,entity_type,entity_id,device_id,payload,'
          'updated_at,deleted_at,server_version',
        )
        .eq('user_id', userId);
    if (parsedCursor != null) {
      if (parsedCursor.isLegacy) {
        query = query.gte(
          'updated_at',
          parsedCursor.updatedAt.toIso8601String(),
        );
      } else {
        final timestamp = _postgrestLiteral(
          parsedCursor.updatedAt.toIso8601String(),
        );
        final entityType = _postgrestLiteral(parsedCursor.entityType);
        final entityId = _postgrestLiteral(parsedCursor.entityId);
        query = query.or(
          'updated_at.gt.$timestamp,'
          'and(updated_at.eq.$timestamp,entity_type.gt.$entityType),'
          'and(updated_at.eq.$timestamp,entity_type.eq.$entityType,'
          'entity_id.gt.$entityId)',
        );
      }
    }
    final response = await query
        .order('updated_at')
        .order('entity_type')
        .order('entity_id')
        .limit(safeLimit);
    final rows = List<Map<String, dynamic>>.from(response as List);
    final changes = rows.map((row) {
      final payload = Map<String, dynamic>.from(row['payload'] as Map);
      payload['userId'] = row['user_id'];
      payload['vehicleId'] = row['vehicle_id'];
      payload['deviceId'] = row['device_id'];
      payload['updatedAt'] = row['updated_at'];
      payload['deletedAt'] = row['deleted_at'];
      return RemoteChange(
        entityType: SyncEntityType.values.firstWhere(
          (value) => value.name == row['entity_type'],
        ),
        entityId: '${row['entity_id']}',
        userId: '${row['user_id']}',
        vehicleId: '${row['vehicle_id']}',
        updatedAt: DateTime.parse('${row['updated_at']}'),
        deletedAt: row['deleted_at'] == null
            ? null
            : DateTime.tryParse('${row['deleted_at']}'),
        deviceId: '${row['device_id'] ?? ''}',
        payload: payload,
        serverVersion: (row['server_version'] as num?)?.toInt(),
      );
    }).toList();
    return RemotePullResult(
      changes: changes,
      nextCursor: changes.isEmpty
          ? cursor
          : RemoteSyncCursor.fromChange(changes.last).encode(),
      hasMore: changes.length == safeLimit,
    );
  }

  static String _postgrestLiteral(String value) {
    final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    return '"$escaped"';
  }
}
