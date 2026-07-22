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
      batteryVoltage: 77.5,
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
    expect(restored.batteryVoltage, 77.5);
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

  test('migra batteryPercent antiguo a batteryVoltage', () {
    final restored = DailyRecord.fromMap({
      'id': 'legacy-percent',
      'date': '2026-03-14',
      'earnings': 2900,
      'odometer': 526,
      'batteryPercent': 76,
      'note': 'Nota real del chofer',
      'updatedAt': '2026-03-14T10:00:00.000Z',
    });

    expect(restored.batteryVoltage, 76);
    expect(restored.note, 'Nota real del chofer');
    expect(restored.toMap(), containsPair('batteryVoltage', 76));
    expect(restored.toMap(), isNot(contains('batteryPercent')));
    expect(restored.toMap(), isNot(contains('chargeTo80v')));
  });

  test('extrae voltaje de una nota antigua y conserva la nota real', () {
    final restored = DailyRecord.fromMap({
      'id': 'legacy-note-voltage',
      'date': '2026-03-14',
      'earnings': 2900,
      'odometer': 526,
      'note': 'Trabajo normal\nVoltaje: 77.5V',
      'updatedAt': '2026-03-14T10:00:00.000Z',
    });

    expect(restored.batteryVoltage, 77.5);
    expect(restored.note, 'Trabajo normal');
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
      deviceId: 'device-1',
      syncStatus: SyncStatus.pending,
    );

    final restored = VehicleProfile.fromMap(vehicle.toMap());

    expect(restored.id, vehicle.id);
    expect(restored.userId, vehicle.userId);
    expect(restored.name, vehicle.name);
    expect(restored.registration, 'TT-001');
    expect(restored.initialOdometer, 526);
    expect(restored.deviceId, 'device-1');
    expect(restored.syncStatus, SyncStatus.pending);
    expect(restored.isDeleted, isFalse);
  });

  test('VehicleProfile anterior conserva compatibilidad al migrar', () {
    final restored = VehicleProfile.fromMap({
      'id': 'vehicle-legacy',
      'userId': 'local-owner',
      'name': 'Mi Tuk Tuk',
      'createdAt': '2026-07-15T00:00:00.000Z',
      'updatedAt': '2026-07-15T00:00:00.000Z',
    });

    expect(restored.id, 'vehicle-legacy');
    expect(restored.deviceId, isEmpty);
    expect(restored.syncStatus, SyncStatus.localOnly);
    expect(restored.schemaVersion, 1);
  });

  test('usuario y licencia local no exigen autenticación ni restringen',
      () async {
    final now = DateTime.utc(2026, 7, 15);
    final auth = LocalAuthService(
      AppUserProfile(
        id: 'local-owner-device-1',
        displayName: 'Propietario local',
        createdAt: now,
        updatedAt: now,
      ),
    );
    const licenses = LocalLicenseService();

    expect(auth.currentUser.isLocal, isTrue);
    expect(auth.requiresAuthentication, isFalse);
    expect(licenses.restrictionsEnabled, isFalse);
    expect(
      (await licenses.currentLicense(auth.currentUser.id)).licenseStatus,
      LicenseStatus.local,
    );
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

  test('OwnershipPolicy protege cuentas y permite respaldos portables', () {
    expect(OwnershipPolicy.canClaimLocalData(null, 'owner-1'), isTrue);
    expect(OwnershipPolicy.canClaimLocalData('owner-1', 'owner-1'), isTrue);
    expect(OwnershipPolicy.canClaimLocalData('owner-1', 'owner-2'), isFalse);
    expect(OwnershipPolicy.acceptsBackup('owner-1', null), isTrue);
    expect(OwnershipPolicy.acceptsBackup('owner-1', 'owner-1'), isTrue);
    expect(OwnershipPolicy.acceptsBackup('owner-1', 'owner-2'), isTrue);
  });

  test('los datos históricos no se cargan en una instalación nueva', () {
    expect(OwnershipPolicy.shouldLoadHistoricalSeed(null), isFalse);
    expect(
      OwnershipPolicy.shouldLoadHistoricalSeed('existing-seed-version'),
      isTrue,
    );
  });

  test('un conductor solo accede a vehículos asignados de su organización', () {
    const driver = AccountMembership(
      userId: 'driver-1',
      role: AccountRole.driver,
      organizationId: 'organization-1',
      vehicleIds: {'vehicle-1'},
    );

    expect(
      AccessPolicy.canReadVehicle(
        membership: driver,
        ownerUserId: 'owner-1',
        vehicleId: 'vehicle-1',
        organizationId: 'organization-1',
      ),
      isTrue,
    );
    expect(
      AccessPolicy.canReadVehicle(
        membership: driver,
        ownerUserId: 'owner-1',
        vehicleId: 'vehicle-2',
        organizationId: 'organization-1',
      ),
      isFalse,
    );
    expect(
      AccessPolicy.canReadVehicle(
        membership: driver,
        ownerUserId: 'owner-2',
        vehicleId: 'vehicle-1',
        organizationId: 'organization-2',
      ),
      isFalse,
    );
  });

  test('una membresía suspendida no accede aunque sea propietaria', () {
    const suspendedOwner = AccountMembership(
      userId: 'owner-1',
      role: AccountRole.owner,
      status: MembershipStatus.suspended,
    );

    expect(
      AccessPolicy.canWriteVehicle(
        membership: suspendedOwner,
        ownerUserId: 'owner-1',
        vehicleId: 'vehicle-1',
      ),
      isFalse,
    );
  });

  test('solo administradores autorizados gestionan su organización', () {
    const admin = AccountMembership(
      userId: 'admin-1',
      role: AccountRole.organizationAdmin,
      organizationId: 'organization-1',
    );

    expect(AccessPolicy.canManageOrganization(admin, 'organization-1'), isTrue);
    expect(
        AccessPolicy.canManageOrganization(admin, 'organization-2'), isFalse);
  });

  test('el plan gratuito limita vehículos y funciones', () {
    expect(SubscriptionAccess.free.allowsVehicleCount(1), isTrue);
    expect(SubscriptionAccess.free.allowsVehicleCount(2), isFalse);
    expect(
      LicensePolicy.allowsVehicleCount(SubscriptionAccess.free, 2),
      isTrue,
      reason: 'Las restricciones comerciales todavía no están activas.',
    );
    expect(
      SubscriptionAccess.free.isEnabled(ProductCapability.offlineOperation),
      isTrue,
    );
    expect(
      SubscriptionAccess.free.isEnabled(ProductCapability.cloudSync),
      isFalse,
    );
    expect(
      LicensePolicy.allowsCapability(
        SubscriptionAccess.free,
        ProductCapability.cloudSync,
      ),
      isTrue,
    );
  });
}
