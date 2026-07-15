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
}
