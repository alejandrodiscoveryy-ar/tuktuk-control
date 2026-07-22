part of '../main.dart';

typedef SyncPayloadResolver = Map<String, dynamic>? Function(
  SyncOperation operation,
);

class SupabaseSyncGateway implements RemoteSyncGateway {
  SupabaseSyncGateway({
    required SupabaseClient client,
    required SyncPayloadResolver payloadFor,
  })  : _client = client,
        _payloadFor = payloadFor;

  static const tableName = 'sync_entities';

  final SupabaseClient _client;
  final SyncPayloadResolver _payloadFor;

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
      });
      accepted.add(operation.id);
    }

    if (rows.isNotEmpty) {
      await _client.from(tableName).upsert(
            rows,
            onConflict: 'user_id,entity_type,entity_id',
          );
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
  }) async {
    dynamic query = _client.from(tableName).select().eq('user_id', userId);
    if (cursor != null && cursor.isNotEmpty) {
      query = query.gte('updated_at', cursor);
    }
    final response = await query.order('updated_at').limit(1000);
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
      );
    }).toList();
    return RemotePullResult(
      changes: changes,
      nextCursor: changes.isEmpty
          ? cursor
          : changes.last.updatedAt.toUtc().toIso8601String(),
    );
  }
}
