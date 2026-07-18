part of '../main.dart';

enum IdentityMode { local, authenticated }

class AppUserProfile {
  AppUserProfile({
    required this.id,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
    this.mode = IdentityMode.local,
    this.email,
    this.syncStatus = SyncStatus.localOnly,
    this.deletedAt,
  });

  final String id;
  final String displayName;
  final String? email;
  final IdentityMode mode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;
  final DateTime? deletedAt;

  bool get isLocal => mode == IdentityMode.local;
  bool get isDeleted => deletedAt != null;
}

enum LicenseStatus {
  local,
  trial,
  active,
  expiring,
  expired,
  suspended,
  pendingPayment,
  unknown,
}

class LicenseSnapshot {
  const LicenseSnapshot({
    required this.planId,
    required this.licenseStatus,
    this.trialStartsAt,
    this.trialEndsAt,
    this.paidUntil,
    this.lastServerValidation,
    this.offlineGraceUntil,
  });

  final String planId;
  final DateTime? trialStartsAt;
  final DateTime? trialEndsAt;
  final DateTime? paidUntil;
  final LicenseStatus licenseStatus;
  final DateTime? lastServerValidation;
  final DateTime? offlineGraceUntil;

  static const local = LicenseSnapshot(
    planId: 'local',
    licenseStatus: LicenseStatus.local,
  );
}

enum PlanId { personal, owner, fleet, enterprise }

class PlanDefinition {
  const PlanDefinition({
    required this.id,
    required this.maxVehicles,
    required this.maxDrivers,
    required this.reportsEnabled,
    required this.syncEnabled,
    required this.cloudBackupEnabled,
    this.premiumCapabilities = const <String>{},
  });

  final PlanId id;
  final int? maxVehicles;
  final int? maxDrivers;
  final bool reportsEnabled;
  final bool syncEnabled;
  final bool cloudBackupEnabled;
  final Set<String> premiumCapabilities;
}

abstract interface class AuthService {
  AppUserProfile get currentUser;
  bool get requiresAuthentication;
}

class LocalAuthService implements AuthService {
  LocalAuthService(this.currentUser);

  @override
  final AppUserProfile currentUser;

  @override
  bool get requiresAuthentication => false;
}

abstract interface class LicenseService {
  Future<LicenseSnapshot> currentLicense(String userId);
  bool get restrictionsEnabled;
}

class LocalLicenseService implements LicenseService {
  const LocalLicenseService();

  @override
  bool get restrictionsEnabled => false;

  @override
  Future<LicenseSnapshot> currentLicense(String userId) async =>
      LicenseSnapshot.local;
}

abstract interface class SyncService {
  bool get isConfigured;

  Future<SyncRunReport> synchronize({required String userId});
}

abstract interface class UserRepository {
  Future<AppUserProfile?> findById(String userId);

  Future<void> save(AppUserProfile user);
}

abstract interface class VehicleRepository {
  Future<List<VehicleProfile>> listForUser(String userId);

  Future<VehicleProfile?> findById(String vehicleId);

  Future<void> save(VehicleProfile vehicle);
}
