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
  pending,
  expired,
  suspended,
  revoked,
  deviceLimitReached,
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
    this.expiresAt,
    this.maxDevices,
    this.licenseKey,
    this.reason,
    this.canWrite = false,
    this.validatedFromServer = false,
  });

  final String planId;
  final DateTime? trialStartsAt;
  final DateTime? trialEndsAt;
  final DateTime? paidUntil;
  final LicenseStatus licenseStatus;
  final DateTime? lastServerValidation;
  final DateTime? offlineGraceUntil;
  final DateTime? expiresAt;
  final int? maxDevices;
  final String? licenseKey;
  final String? reason;
  final bool canWrite;
  final bool validatedFromServer;

  bool get isReadOnly => !canWrite;
  bool get requiresAdministrator =>
      licenseStatus == LicenseStatus.suspended ||
      licenseStatus == LicenseStatus.revoked;

  String get statusLabel => switch (licenseStatus) {
        LicenseStatus.local => 'Local',
        LicenseStatus.trial => 'Periodo inicial',
        LicenseStatus.active => 'Activa',
        LicenseStatus.expiring => 'Próxima a vencer',
        LicenseStatus.pending => 'Pendiente',
        LicenseStatus.expired => 'Vencida',
        LicenseStatus.suspended => 'Suspendida',
        LicenseStatus.revoked => 'Revocada',
        LicenseStatus.deviceLimitReached => 'Límite de dispositivos',
        LicenseStatus.pendingPayment => 'Pago pendiente',
        LicenseStatus.unknown => 'No verificada',
      };

  Map<String, dynamic> toMap() => {
        'planId': planId,
        'licenseStatus': licenseStatus.name,
        'trialStartsAt': trialStartsAt?.toIso8601String(),
        'trialEndsAt': trialEndsAt?.toIso8601String(),
        'paidUntil': paidUntil?.toIso8601String(),
        'lastServerValidation': lastServerValidation?.toIso8601String(),
        'offlineGraceUntil': offlineGraceUntil?.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'maxDevices': maxDevices,
        'licenseKey': licenseKey,
        'reason': reason,
        'canWrite': canWrite,
        'validatedFromServer': validatedFromServer,
      };

  factory LicenseSnapshot.fromMap(Map<dynamic, dynamic> map) {
    final statusName = '${map['licenseStatus'] ?? 'unknown'}';
    return LicenseSnapshot(
      planId: '${map['planId'] ?? 'unknown'}',
      licenseStatus: LicenseStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => LicenseStatus.unknown,
      ),
      trialStartsAt: DateTime.tryParse('${map['trialStartsAt'] ?? ''}'),
      trialEndsAt: DateTime.tryParse('${map['trialEndsAt'] ?? ''}'),
      paidUntil: DateTime.tryParse('${map['paidUntil'] ?? ''}'),
      lastServerValidation:
          DateTime.tryParse('${map['lastServerValidation'] ?? ''}'),
      offlineGraceUntil: DateTime.tryParse('${map['offlineGraceUntil'] ?? ''}'),
      expiresAt: DateTime.tryParse('${map['expiresAt'] ?? ''}'),
      maxDevices: (map['maxDevices'] as num?)?.toInt(),
      licenseKey: map['licenseKey']?.toString(),
      reason: map['reason']?.toString(),
      canWrite: map['canWrite'] == true,
      validatedFromServer: map['validatedFromServer'] == true,
    );
  }

  static const local = LicenseSnapshot(
    planId: 'local',
    licenseStatus: LicenseStatus.local,
    canWrite: true,
  );
}

class ReadOnlyLicenseException implements Exception {
  const ReadOnlyLicenseException(this.snapshot);

  final LicenseSnapshot snapshot;

  @override
  String toString() => 'ReadOnlyLicenseException(${snapshot.reason})';
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
  LicenseSnapshot cachedLicense(String userId);
  Future<LicenseSnapshot> refresh({
    required String userId,
    required String deviceFingerprint,
  });
  Future<void> markWriteRejected(String userId, Object error);
  bool get restrictionsEnabled;
}

class LocalLicenseService implements LicenseService {
  const LocalLicenseService();

  @override
  bool get restrictionsEnabled => false;

  @override
  LicenseSnapshot cachedLicense(String userId) => LicenseSnapshot.local;

  @override
  Future<LicenseSnapshot> currentLicense(String userId) async =>
      LicenseSnapshot.local;

  @override
  Future<LicenseSnapshot> refresh({
    required String userId,
    required String deviceFingerprint,
  }) async =>
      LicenseSnapshot.local;

  @override
  Future<void> markWriteRejected(String userId, Object error) async {}
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
