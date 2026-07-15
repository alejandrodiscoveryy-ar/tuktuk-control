import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DailyRecord conserva todos sus campos al serializar', () {
    final createdAt = DateTime.utc(2026, 7, 15, 10, 30);
    final updatedAt = DateTime.utc(2026, 7, 15, 11, 45);
    final record = DailyRecord(
      id: 'record-1',
      date: DateTime(2026, 7, 15),
      earnings: 4250,
      odometer: 4300,
      batteryPercent: 82,
      chargeTo80v: true,
      note: 'Prueba de integridad',
      createdAt: createdAt,
      updatedAt: updatedAt,
      deviceId: 'device-1',
      userId: 'user-1',
      vehicleId: 'vehicle-1',
      syncStatus: SyncStatus.pending,
    );

    final restored = DailyRecord.fromMap(record.toMap());

    expect(restored.id, record.id);
    expect(restored.date, record.date);
    expect(restored.earnings, record.earnings);
    expect(restored.odometer, record.odometer);
    expect(restored.batteryPercent, record.batteryPercent);
    expect(restored.chargeTo80v, isTrue);
    expect(restored.note, record.note);
    expect(restored.createdAt, createdAt);
    expect(restored.updatedAt, updatedAt);
    expect(restored.deviceId, record.deviceId);
    expect(restored.userId, 'user-1');
    expect(restored.vehicleId, 'vehicle-1');
    expect(restored.syncStatus, SyncStatus.pending);
    expect(restored.isDeleted, isFalse);
  });

  test('MaintenanceRecord conserva el borrado lógico', () {
    final deletedAt = DateTime.utc(2026, 7, 15, 12);
    final record = MaintenanceRecord(
      id: 'maintenance-1',
      dateTime: DateTime.utc(2026, 3, 14, 9),
      odometer: 526,
      type: 'General',
      description: 'Mantenimiento general',
      cost: 15000,
      deletedAt: deletedAt,
      deviceId: 'device-1',
    );

    final restored = MaintenanceRecord.fromMap(record.toMap());

    expect(restored.id, record.id);
    expect(restored.deletedAt, deletedAt);
    expect(restored.isDeleted, isTrue);
    expect(restored.cost, 15000);
  });

  test('un registro anterior conserva compatibilidad al migrar', () {
    final restored = DailyRecord.fromMap({
      'id': 'legacy-record',
      'date': '2026-03-14',
      'earnings': 2900,
      'odometer': 526,
      'updatedAt': '2026-03-14T10:00:00.000Z',
    });

    expect(restored.id, 'legacy-record');
    expect(restored.userId, isEmpty);
    expect(restored.vehicleId, isEmpty);
    expect(restored.syncStatus, SyncStatus.localOnly);
    expect(restored.schemaVersion, 1);
  });

  test('VehicleProfile conserva propietario e identidad', () {
    final now = DateTime.utc(2026, 7, 15);
    final vehicle = VehicleProfile(
      id: 'vehicle-1',
      userId: 'user-1',
      name: 'Tuk Tuk principal',
      registration: 'TT-001',
      initialOdometer: 526,
      createdAt: now,
      updatedAt: now,
    );

    final restored = VehicleProfile.fromMap(vehicle.toMap());

    expect(restored.id, vehicle.id);
    expect(restored.userId, vehicle.userId);
    expect(restored.name, vehicle.name);
    expect(restored.registration, 'TT-001');
    expect(restored.initialOdometer, 526);
  });

  test('withSyncInfo asigna propietario sin alterar datos históricos', () {
    final legacy = DailyRecord(
      id: 'seed-historical',
      date: DateTime(2026, 3, 14),
      earnings: 2900,
      odometer: 526,
      note: 'Carga inicial de ganancias',
    );

    final migrated = legacy.withSyncInfo(
      deviceId: 'device-1',
      userId: 'user-owner',
      vehicleId: 'vehicle-primary',
      syncStatus: SyncStatus.pending,
    );

    expect(migrated.id, legacy.id);
    expect(migrated.date, legacy.date);
    expect(migrated.earnings, legacy.earnings);
    expect(migrated.odometer, legacy.odometer);
    expect(migrated.note, legacy.note);
    expect(migrated.userId, 'user-owner');
    expect(migrated.vehicleId, 'vehicle-primary');
    expect(migrated.syncStatus, SyncStatus.pending);
  });

  test('OwnershipPolicy bloquea otra cuenta y respaldos ajenos', () {
    expect(OwnershipPolicy.canClaimLocalData(null, 'owner-1'), isTrue);
    expect(OwnershipPolicy.canClaimLocalData('owner-1', 'owner-1'), isTrue);
    expect(OwnershipPolicy.canClaimLocalData('owner-1', 'owner-2'), isFalse);
    expect(OwnershipPolicy.acceptsBackup('owner-1', null), isTrue);
    expect(OwnershipPolicy.acceptsBackup('owner-1', 'owner-1'), isTrue);
    expect(OwnershipPolicy.acceptsBackup('owner-1', 'owner-2'), isFalse);
  });

  test('los datos históricos no se cargan en una instalación nueva', () {
    expect(OwnershipPolicy.shouldLoadHistoricalSeed(null), isFalse);
    expect(
      OwnershipPolicy.shouldLoadHistoricalSeed('existing-seed-version'),
      isTrue,
    );
  });
}
