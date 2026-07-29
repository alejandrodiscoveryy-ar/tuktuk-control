part of '../main.dart';

abstract final class LicenseAccessEvaluator {
  static const trialDuration = Duration(days: 30);

  static LicenseSnapshot fromRemote({
    required Map<String, dynamic>? license,
    required DateTime? profileCreatedAt,
    required DateTime now,
    Map<String, dynamic>? deviceValidation,
  }) {
    if (license == null) {
      if (profileCreatedAt == null) {
        return const LicenseSnapshot(
          planId: 'unknown',
          licenseStatus: LicenseStatus.unknown,
          reason: 'profile_not_found',
        );
      }
      final trialEndsAt = profileCreatedAt.add(trialDuration);
      final active = trialEndsAt.isAfter(now);
      return LicenseSnapshot(
        planId: 'trial',
        licenseStatus: active ? LicenseStatus.trial : LicenseStatus.expired,
        trialStartsAt: profileCreatedAt,
        trialEndsAt: trialEndsAt,
        expiresAt: trialEndsAt,
        reason: active ? 'trial' : 'trial_expired',
        canWrite: active,
        validatedFromServer: true,
        lastServerValidation: now,
      );
    }

    final rawStatus = '${license['status'] ?? 'unknown'}';
    final expiresAt = DateTime.tryParse('${license['expires_at'] ?? ''}');
    final maxDevices = (license['max_devices'] as num?)?.toInt();
    final planId = '${license['plan'] ?? license['license_type'] ?? 'unknown'}';
    final status = switch (rawStatus) {
      'active' => LicenseStatus.active,
      'pending' => LicenseStatus.pending,
      'expired' => LicenseStatus.expired,
      'suspended' => LicenseStatus.suspended,
      'revoked' => LicenseStatus.revoked,
      _ => LicenseStatus.unknown,
    };
    if (status != LicenseStatus.active) {
      return LicenseSnapshot(
        planId: planId,
        licenseStatus: status,
        expiresAt: expiresAt,
        paidUntil: expiresAt,
        maxDevices: maxDevices,
        reason: rawStatus,
        validatedFromServer: true,
        lastServerValidation: now,
      );
    }
    if (expiresAt != null && !expiresAt.isAfter(now)) {
      return LicenseSnapshot(
        planId: planId,
        licenseStatus: LicenseStatus.expired,
        expiresAt: expiresAt,
        paidUntil: expiresAt,
        maxDevices: maxDevices,
        reason: 'expired',
        validatedFromServer: true,
        lastServerValidation: now,
      );
    }
    final validDevice = deviceValidation?['valid'] == true;
    final deviceReason = '${deviceValidation?['reason'] ?? 'unknown'}';
    if (!validDevice) {
      final rejectedStatus = switch (deviceReason) {
        'pending' => LicenseStatus.pending,
        'expired' => LicenseStatus.expired,
        'suspended' => LicenseStatus.suspended,
        'revoked' => LicenseStatus.revoked,
        'device_limit_reached' => LicenseStatus.deviceLimitReached,
        _ => LicenseStatus.unknown,
      };
      return LicenseSnapshot(
        planId: planId,
        licenseStatus: rejectedStatus,
        expiresAt: expiresAt,
        paidUntil: expiresAt,
        maxDevices: maxDevices,
        reason: deviceReason,
        validatedFromServer: true,
        lastServerValidation: now,
      );
    }
    return LicenseSnapshot(
      planId: planId,
      licenseStatus: LicenseStatus.active,
      expiresAt: expiresAt,
      paidUntil: expiresAt,
      maxDevices: maxDevices,
      reason: 'active',
      canWrite: true,
      validatedFromServer: true,
      lastServerValidation: now,
    );
  }

  static LicenseSnapshot revalidateCached(
    LicenseSnapshot cached,
    DateTime now,
  ) {
    final expiry = cached.expiresAt ?? cached.trialEndsAt;
    if (expiry != null && !expiry.isAfter(now)) {
      return LicenseSnapshot(
        planId: cached.planId,
        licenseStatus: LicenseStatus.expired,
        trialStartsAt: cached.trialStartsAt,
        trialEndsAt: cached.trialEndsAt,
        paidUntil: cached.paidUntil,
        expiresAt: expiry,
        maxDevices: cached.maxDevices,
        reason: 'expired_offline',
        validatedFromServer: false,
        lastServerValidation: cached.lastServerValidation,
      );
    }
    return cached;
  }
}

class SupabaseLicenseService implements LicenseService {
  SupabaseLicenseService({
    required SupabaseClient client,
    required Box cache,
  })  : _client = client,
        _cache = cache;

  static const _cachePrefix = 'licenseAccess:';

  final SupabaseClient _client;
  final Box _cache;

  @override
  bool get restrictionsEnabled => true;

  @override
  LicenseSnapshot cachedLicense(String userId) {
    final raw = _cache.get('$_cachePrefix$userId');
    if (raw is! Map) {
      return const LicenseSnapshot(
        planId: 'unknown',
        licenseStatus: LicenseStatus.unknown,
        reason: 'not_validated',
      );
    }
    return LicenseAccessEvaluator.revalidateCached(
      LicenseSnapshot.fromMap(raw),
      DateTime.now().toUtc(),
    );
  }

  @override
  Future<LicenseSnapshot> currentLicense(String userId) async =>
      cachedLicense(userId);

  @override
  Future<LicenseSnapshot> refresh({
    required String userId,
    required String deviceFingerprint,
  }) async {
    try {
      final licenseResponse = await _client
          .from('licenses')
          .select(
            'id,project_id,license_key,status,expires_at,license_type,'
            'plan,max_devices',
          )
          .eq('user_id', userId)
          .maybeSingle();
      final license = licenseResponse == null
          ? null
          : Map<String, dynamic>.from(licenseResponse);
      DateTime? profileCreatedAt;
      Map<String, dynamic>? deviceValidation;
      if (license == null) {
        final profile = await _client
            .from('profiles')
            .select('created_at')
            .eq('id', userId)
            .maybeSingle();
        profileCreatedAt =
            DateTime.tryParse('${profile?['created_at'] ?? ''}')?.toUtc();
      } else if ('${license['status']}' == 'active') {
        final result = await _client.rpc(
          'validate_license',
          params: {
            'target_project_id': license['project_id'],
            'target_license_key': license['license_key'],
            'target_device_fingerprint': deviceFingerprint,
          },
        );
        if (result is Map) {
          deviceValidation = Map<String, dynamic>.from(result);
        }
      }
      final snapshot = LicenseAccessEvaluator.fromRemote(
        license: license,
        profileCreatedAt: profileCreatedAt,
        now: DateTime.now().toUtc(),
        deviceValidation: deviceValidation,
      );
      await _cache.put('$_cachePrefix$userId', snapshot.toMap());
      return snapshot;
    } catch (error) {
      if (isSupabaseAuthorizationFailure(error)) {
        final cached = cachedLicense(userId);
        final denied = LicenseSnapshot(
          planId: cached.planId,
          licenseStatus: LicenseStatus.unknown,
          expiresAt: cached.expiresAt,
          maxDevices: cached.maxDevices,
          reason: 'authorization_failed',
          validatedFromServer: true,
          lastServerValidation: DateTime.now().toUtc(),
        );
        await _cache.put('$_cachePrefix$userId', denied.toMap());
        return denied;
      }
      return cachedLicense(userId);
    }
  }

  @override
  Future<void> markWriteRejected(String userId, Object error) async {
    final cached = cachedLicense(userId);
    final snapshot = LicenseSnapshot(
      planId: cached.planId,
      licenseStatus: LicenseStatus.unknown,
      expiresAt: cached.expiresAt,
      maxDevices: cached.maxDevices,
      reason: 'server_write_rejected',
      validatedFromServer: true,
      lastServerValidation: DateTime.now().toUtc(),
    );
    await _cache.put('$_cachePrefix$userId', snapshot.toMap());
  }
}

class LicenseWriteRejectedException implements Exception {
  const LicenseWriteRejectedException(this.cause);

  final Object cause;

  @override
  String toString() => 'LicenseWriteRejectedException($cause)';
}

bool isSupabaseAuthorizationFailure(Object error) {
  if (error is! PostgrestException) return false;
  return isAuthorizationFailureCode(
    code: error.code,
    message: error.message,
    details: error.details,
  );
}

bool isAuthorizationFailureCode({
  String? code,
  required String message,
  Object? details,
}) {
  final text = '$code $message $details'.toLowerCase();
  return code == '42501' ||
      code == '401' ||
      code == '403' ||
      code == 'PGRST301' ||
      text.contains('row-level security') ||
      text.contains('permission denied') ||
      text.contains('jwt') ||
      text.contains('license');
}
