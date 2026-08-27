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
    ReferralQualificationMode.registration =>
      'Cuando tu invitado se registre',
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

  factory ReferralProgram.fromMap(Map<dynamic, dynamic> map) {
    String? optionalText(Object? value) {
      final text = value?.toString().trim();
      return text == null || text.isEmpty || text == 'null' ? null : text;
    }

    int count(Object? value) => value is num
        ? value.toInt()
        : int.tryParse('${value ?? ''}') ?? 0;

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
      rewardDays: reward is num
          ? reward.toInt()
          : int.tryParse('${reward ?? ''}') ?? 0,
      createdAt: DateTime.tryParse('${map['created_at'] ?? ''}'),
      qualifiedAt: DateTime.tryParse('${map['qualified_at'] ?? ''}'),
    );
  }
}

enum ReferralLoadState { idle, loading, loaded, error }

enum PendingReferralClaimResult {
  none,
  success,
  failed,
  alreadyAttempted,
  accountMismatch,
}

abstract interface class PendingReferralCodeStore {
  String? get code;
  String? get assignedUserId;
  String? get attemptedUserId;

  Future<void> saveCode(String value);
  Future<void> assignToUser(String userId);
  Future<void> markAttempted(String userId);
  Future<void> resetAttempt();
  Future<void> clear();
}

typedef ReferralClaimCall = Future<void> Function(String code);

class PendingReferralClaimController {
  PendingReferralClaimController(this._store);

  final PendingReferralCodeStore _store;

  Future<bool> capture(Uri uri) async {
    final raw = uri.queryParameters['ref']?.trim();
    if (raw == null || raw.isEmpty || raw.length > 128) return false;
    if (_store.code == raw) return true;
    await _store.saveCode(raw);
    return true;
  }

  Future<PendingReferralClaimResult> claimForUser({
    required String userId,
    required ReferralClaimCall claim,
  }) async {
    if (userId.trim().isEmpty) return PendingReferralClaimResult.none;
    final code = _store.code;
    if (code == null || code.isEmpty) return PendingReferralClaimResult.none;

    final assignedUserId = _store.assignedUserId;
    if (assignedUserId != null && assignedUserId != userId) {
      return PendingReferralClaimResult.accountMismatch;
    }
    if (assignedUserId == null) await _store.assignToUser(userId);
    if (_store.attemptedUserId == userId) {
      return PendingReferralClaimResult.alreadyAttempted;
    }

    await _store.markAttempted(userId);
    try {
      await claim(code);
      await _store.clear();
      return PendingReferralClaimResult.success;
    } catch (_) {
      return PendingReferralClaimResult.failed;
    }
  }

  Future<void> allowRetryForUser(String userId) async {
    if (_store.assignedUserId == userId) await _store.resetAttempt();
  }
}
