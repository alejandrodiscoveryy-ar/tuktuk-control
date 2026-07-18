part of '../main.dart';

enum AccountRole { owner, driver, organizationAdmin, platformAdmin }

enum MembershipStatus { invited, active, suspended }

enum SubscriptionPlan { free, professional, business }

enum ProductCapability {
  offlineOperation,
  cloudSync,
  advancedReports,
  organizationManagement,
}

class AccountMembership {
  const AccountMembership({
    required this.userId,
    required this.role,
    this.organizationId,
    this.vehicleIds = const <String>{},
    this.status = MembershipStatus.active,
  });

  final String userId;
  final AccountRole role;
  final String? organizationId;
  final Set<String> vehicleIds;
  final MembershipStatus status;

  bool get isActive => status == MembershipStatus.active;
}

class SubscriptionAccess {
  const SubscriptionAccess({
    required this.plan,
    required this.capabilities,
    required this.vehicleLimit,
    this.expiresAt,
  });

  final SubscriptionPlan plan;
  final Set<ProductCapability> capabilities;
  final int vehicleLimit;
  final DateTime? expiresAt;

  bool isEnabled(ProductCapability capability, {DateTime? now}) {
    final expiration = expiresAt;
    if (expiration != null && !expiration.isAfter(now ?? DateTime.now())) {
      return false;
    }
    return capabilities.contains(capability);
  }

  bool allowsVehicleCount(int count) => count >= 0 && count <= vehicleLimit;

  static const free = SubscriptionAccess(
    plan: SubscriptionPlan.free,
    capabilities: {ProductCapability.offlineOperation},
    vehicleLimit: 1,
  );
}

/// Punto único para activar licencias en el futuro.
///
/// Mientras [restrictionsEnabled] sea falso ninguna función ni vehículo queda
/// bloqueado por el plan. Las pantallas no conocen reglas comerciales.
abstract final class LicensePolicy {
  static const bool restrictionsEnabled = false;

  static bool allowsCapability(
    SubscriptionAccess access,
    ProductCapability capability,
  ) {
    return !restrictionsEnabled || access.isEnabled(capability);
  }

  static bool allowsVehicleCount(SubscriptionAccess access, int count) {
    return !restrictionsEnabled || access.allowsVehicleCount(count);
  }
}

abstract final class AccessPolicy {
  static bool canReadVehicle({
    required AccountMembership membership,
    required String ownerUserId,
    required String vehicleId,
    String? organizationId,
  }) {
    if (!membership.isActive) return false;
    if (membership.role == AccountRole.platformAdmin) return true;
    if (membership.userId == ownerUserId) return true;
    if (!_sameOrganization(membership.organizationId, organizationId)) {
      return false;
    }
    if (membership.role == AccountRole.organizationAdmin) return true;
    return membership.role == AccountRole.driver &&
        membership.vehicleIds.contains(vehicleId);
  }

  static bool canWriteVehicle({
    required AccountMembership membership,
    required String ownerUserId,
    required String vehicleId,
    String? organizationId,
  }) {
    return canReadVehicle(
      membership: membership,
      ownerUserId: ownerUserId,
      vehicleId: vehicleId,
      organizationId: organizationId,
    );
  }

  static bool canManageOrganization(
    AccountMembership membership,
    String organizationId,
  ) {
    if (!membership.isActive) return false;
    if (membership.role == AccountRole.platformAdmin) return true;
    return membership.role == AccountRole.organizationAdmin &&
        membership.organizationId == organizationId;
  }

  static bool _sameOrganization(String? membershipId, String? resourceId) {
    return membershipId != null &&
        membershipId.isNotEmpty &&
        membershipId == resourceId;
  }
}
