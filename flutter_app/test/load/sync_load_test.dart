import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('carga local de sincronización para 1000 usuarios', () {
    const userCount = 1000;
    const changesPerUser = 25;
    final stopwatch = Stopwatch()..start();
    final consolidated = <String, SyncOperation>{};

    for (var userIndex = 0; userIndex < userCount; userIndex++) {
      final userId = 'user-$userIndex';
      for (var changeIndex = 0; changeIndex < changesPerUser; changeIndex++) {
        final entityId = 'record-${changeIndex % 5}';
        final key = '$userId:$entityId';
        final timestamp = DateTime.utc(2026, 7, 27)
            .add(Duration(microseconds: userIndex * 100 + changeIndex));
        final incoming = SyncOperation(
          id: 'dailyRecord:$entityId',
          entityType: SyncEntityType.dailyRecord,
          entityId: entityId,
          action: SyncAction.upsert,
          userId: userId,
          vehicleId: 'vehicle-$userIndex',
          createdAt: timestamp,
          updatedAt: timestamp,
        );
        consolidated[key] = SyncQueuePolicy.consolidate(
          consolidated[key],
          incoming,
        );
      }
    }
    stopwatch.stop();

    expect(consolidated, hasLength(userCount * 5));
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
  });

  test('cursores de 100 páginas mantienen el último identificador', () {
    const pageSize = 250;
    const recordCount = 25000;
    String? cursor;

    for (var index = 0; index < recordCount; index += pageSize) {
      final lastIndex = index + pageSize - 1;
      cursor = RemoteSyncCursor(
        updatedAt:
            DateTime.utc(2026, 7, 27).add(Duration(microseconds: lastIndex)),
        entityType: SyncEntityType.dailyRecord.name,
        entityId: 'record-${lastIndex.toString().padLeft(5, '0')}',
      ).encode();
    }

    final restored = RemoteSyncCursor.tryParse(cursor);
    expect(restored?.entityId, 'record-24999');
    expect(
      restored?.updatedAt,
      DateTime.utc(2026, 7, 27).add(const Duration(microseconds: 24999)),
    );
  });
}
