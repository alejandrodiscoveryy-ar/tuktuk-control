part of '../main.dart';

enum ReferralQualificationMode { registration, firstPayment, unknown }

ReferralQualificationMode referralQualificationModeFromValue(Object? value) {
  return switch ('$value') {
    'registration' => ReferralQualificationMode.registration,
    'first_payment' => ReferralQualificationMode.firstPayment,
    _ => ReferralQualificationMode.unknown,
  };
}

String referralQualificationLabel(ReferralQualificationMode mode) {
  return switch (mode) {
    ReferralQualificationMode.registration => 'Cuando tu invitado se registre',
    ReferralQualificationMode.firstPayment =>
      'Cuando tu invitado realice su primer pago',
    ReferralQualificationMode.unknown => 'Condición definida por la campaña',
  };
}

class ReferralProgram {
  const ReferralProgram({
    required this.enabled,
    required this.campaignId,
    required this.campaignName,
    required this.qualificationMode,
    required this.rewardDays,
    required this.code,
    required this.link,
    required this.referredCount,
    required this.qualifiedCount,
    required this.earnedRewards,
    required this.appliedRewards,
    required this.earnedDays,
    required this.appliedDays,
  });

  final bool enabled;
  final String? campaignId;
  final String? campaignName;
  final ReferralQualificationMode qualificationMode;
  final int rewardDays;
  final String? code;
  final String? link;
  final int referredCount;
  final int qualifiedCount;
  final int earnedRewards;
  final int appliedRewards;
  final int earnedDays;
  final int appliedDays;

  String? get shareLink {
    final value = normalizeReferralCode(code);
    final uri = Uri.tryParse(link ?? '');
    if (value == null ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      return null;
    }
    return Uri.https('www.vrixora.com', '/ref/$value').toString();
  }

  factory ReferralProgram.fromMap(Map<dynamic, dynamic> map) {
    String? optionalText(Object? value) {
      final text = value?.toString().trim();
      return text == null || text.isEmpty || text == 'null' ? null : text;
    }

    int count(Object? value) =>
        value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;

    return ReferralProgram(
      enabled: map['enabled'] == true,
      campaignId: optionalText(map['campaign_id']),
      campaignName: optionalText(map['campaign_name']),
      qualificationMode:
          referralQualificationModeFromValue(map['qualification_mode']),
      rewardDays: count(map['reward_days']),
      code: optionalText(map['code']),
      link: optionalText(map['link']),
      referredCount: count(map['referred_count']),
      qualifiedCount: count(map['qualified_count']),
      earnedRewards: count(map['earned_rewards']),
      appliedRewards: count(map['applied_rewards']),
      earnedDays: count(map['earned_days']),
      appliedDays: count(map['applied_days']),
    );
  }
}

enum ReferralEntryStatus { registered, qualified, rewarded, unknown }

ReferralEntryStatus referralEntryStatusFromValue(Object? value) {
  return switch ('$value') {
    'registered' => ReferralEntryStatus.registered,
    'qualified' => ReferralEntryStatus.qualified,
    'rewarded' => ReferralEntryStatus.rewarded,
    _ => ReferralEntryStatus.unknown,
  };
}

String referralEntryStatusLabel(ReferralEntryStatus status) {
  return switch (status) {
    ReferralEntryStatus.registered => 'Registrado',
    ReferralEntryStatus.qualified => 'Cumplió la condición',
    ReferralEntryStatus.rewarded => 'Recompensa aplicada',
    ReferralEntryStatus.unknown => 'En revisión',
  };
}

class ReferralEntry {
  const ReferralEntry({
    required this.relationshipId,
    required this.name,
    required this.status,
    required this.rewardDays,
    required this.createdAt,
    required this.qualifiedAt,
  });

  final String relationshipId;
  final String name;
  final ReferralEntryStatus status;
  final int rewardDays;
  final DateTime? createdAt;
  final DateTime? qualifiedAt;

  factory ReferralEntry.fromMap(Map<dynamic, dynamic> map) {
    final reward = map['reward_days'];
    return ReferralEntry(
      relationshipId: '${map['relationship_id'] ?? ''}',
      name: '${map['name'] ?? ''}'.trim().isEmpty
          ? 'Usuario invitado'
          : '${map['name']}'.trim(),
      status: referralEntryStatusFromValue(map['status']),
      rewardDays:
          reward is num ? reward.toInt() : int.tryParse('${reward ?? ''}') ?? 0,
      createdAt: DateTime.tryParse('${map['created_at'] ?? ''}'),
      qualifiedAt: DateTime.tryParse('${map['qualified_at'] ?? ''}'),
    );
  }
}

enum ReferralLoadState { idle, loading, loaded, error }

typedef ForcedReferralRefresh = Future<void> Function({required bool force});
typedef ForcedLicenseRefresh = Future<LicenseSnapshot> Function({
  required bool force,
});

class ReferralLicenseRefreshCoordinator {
  const ReferralLicenseRefreshCoordinator({
    required this.refreshReferrals,
    required this.refreshLicense,
  });

  final ForcedReferralRefresh refreshReferrals;
  final ForcedLicenseRefresh refreshLicense;

  Future<void> refresh() async {
    await refreshReferrals(force: true);
    await refreshLicense(force: true);
  }
}

abstract final class LicenseResumeRefreshPolicy {
  static bool requiresImmediateValidation(LicenseSnapshot license) =>
      license.licenseStatus == LicenseStatus.expired;
}

enum PendingReferralClaimResult {
  none,
  success,
  failed,
  alreadyAttempted,
  accountMismatch,
  deferred,
  rejected,
}

abstract interface class PendingReferralCodeStore {
  String? get code;
  String? get assignedUserId;
  String? get attemptedUserId;
  Map<dynamic, dynamic>? get failure;
  Future<void> saveFailure(Map<String, dynamic> value);

  Future<void> saveCode(String value);
  Future<void> assignToUser(String userId);
  Future<void> markAttempted(String userId);
  Future<void> resetAttempt();
  bool wasClaimedByUser(String userId, String code);
  Future<void> markClaimed(String userId, String code);
  Future<void> clear();
}

typedef ReferralClaimCall = Future<void> Function(String code);

class PendingReferralClaimController {
  PendingReferralClaimController(this._store, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final PendingReferralCodeStore _store;
  final DateTime Function() _now;
  Future<void> _tail = Future.value();

  Future<T> _serialize<T>(Future<T> Function() action) {
    final future = _tail.then((_) => action());
    _tail = future.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return future;
  }

  DateTime? get nextAttemptAt =>
      DateTime.tryParse('${_store.failure?['nextAttemptAt'] ?? ''}');
  String? get rejection => _store.failure?['rejection'] as String?;
  bool get hasPending => _store.code != null;
  String? get assignedUserId => _store.assignedUserId;

  Future<bool> capture(Uri uri) => captureCode(referralCodeFromUri(uri));

  Future<bool> captureCode(String? value) => _serialize(() async {
        final code = normalizeReferralCode(value);
        if (code == null) return false;
        if (_store.code == code) return true;
        // A pending code may already be assigned or attempted for another account.
        // Never replace it implicitly, because doing so would break account isolation.
        if (_store.code != null) return false;
        await _store.saveCode(code);
        return true;
      });

  Future<PendingReferralClaimResult> claimForUser({
    required String userId,
    required ReferralClaimCall claim,
  }) =>
      _serialize(() async {
        if (userId.trim().isEmpty) return PendingReferralClaimResult.none;
        final code = _store.code;
        if (code == null || code.isEmpty) {
          return PendingReferralClaimResult.none;
        }
        final assignedUserId = _store.assignedUserId;
        if (assignedUserId != null && assignedUserId != userId) {
          return PendingReferralClaimResult.accountMismatch;
        }
        if (assignedUserId == null) await _store.assignToUser(userId);
        if (_store.wasClaimedByUser(userId, code)) {
          await _store.clear();
          return PendingReferralClaimResult.alreadyAttempted;
        }
        if (rejection != null) return PendingReferralClaimResult.rejected;
        if (nextAttemptAt?.isAfter(_now()) == true) {
          return PendingReferralClaimResult.deferred;
        }

        // Legacy attemptedUserId is evidence of an attempt, never of success.
        try {
          await claim(code);
          await _store.markClaimed(userId, code);
          await _store.clear();
          return PendingReferralClaimResult.success;
        } catch (error) {
          final reason = referralRejection(error);
          final attempts =
              ((_store.failure?['attempts'] as num?)?.toInt() ?? 0) + 1;
          await _store.saveFailure({
            'attempts': attempts,
            'rejection': reason,
            'nextAttemptAt': reason == null
                ? _now().add(referralRetryDelay(attempts)).toIso8601String()
                : null,
          });
          if (reason != null) return PendingReferralClaimResult.rejected;
          return PendingReferralClaimResult.failed;
        }
      });

  Future<void> allowRetryForUser(String userId) => _serialize(() async {
        if (_store.assignedUserId == userId && rejection == null) {
          await _store.resetAttempt();
        }
      });
}

Duration referralRetryDelay(int attempts) => Duration(
      seconds: [5, 15, 30, 60, 120, 300, 900][(attempts - 1).clamp(0, 6)],
    );

String? referralRejection(Object error) {
  if (error is! PostgrestException) return null;
  return switch (error.message) {
    'REFERRAL_CODE_NOT_FOUND' => 'El código de invitación no existe.',
    'SELF_REFERRAL_NOT_ALLOWED' =>
      'No puedes usar tu propio código de invitación.',
    'REFERRAL_RELATIONSHIP_LOCKED' =>
      'Tu cuenta ya tiene una atribución fijada o no es elegible.',
    'REFERRAL_PROGRAM_NOT_ACTIVE' => 'La campaña de referidos no está activa.',
    _ => null,
  };
}

String? referralCodeFromUri(Uri uri) {
  final queryCode = normalizeReferralCode(uri.queryParameters['ref']);
  if (queryCode != null) return queryCode;

  final segments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);

  if (uri.scheme.toLowerCase() != 'https' ||
      uri.host.toLowerCase() != 'www.vrixora.com' ||
      segments.length != 2 ||
      segments.first.toLowerCase() != 'ref') {
    return null;
  }

  return normalizeReferralCode(segments[1]);
}

String? normalizeReferralCode(String? value) {
  final code = value?.trim().toUpperCase();
  if (code == null || code.isEmpty || code.length > 128) return null;
  return code;
}

String? parseInstallReferrerCode(String? installReferrer) {
  final value = installReferrer?.trim();
  if (value == null || value.isEmpty) return null;
  try {
    return normalizeReferralCode(Uri.splitQueryString(value)['ref']);
  } on FormatException {
    return null;
  }
}
