part of '../main.dart';

class ReferralRemoteService {
  ReferralRemoteService(this._client);

  final SupabaseClient _client;

  Future<ReferralProgram?> loadProgram() async {
    final response = await _client.rpc(
      'get_my_referral_program',
      params: {'target_project_id': _projectId},
    );
    final map = _firstMap(response);
    return map == null ? null : ReferralProgram.fromMap(map);
  }

  Future<List<ReferralEntry>> loadReferrals() async {
    final response = await _client.rpc(
      'get_my_referrals',
      params: {'target_project_id': _projectId},
    );
    if (response is! List) return const [];
    return response
        .whereType<Map>()
        .map(ReferralEntry.fromMap)
        .toList(growable: false);
  }

  Future<void> claim(String code) async {
    await _client.rpc(
      'claim_referral_code',
      params: {
        'target_project_id': _projectId,
        'target_code': code,
      },
    );
  }

  Map<dynamic, dynamic>? _firstMap(dynamic response) {
    if (response is Map) return response;
    if (response is List && response.isNotEmpty && response.first is Map) {
      return response.first as Map;
    }
    return null;
  }
}

class HivePendingReferralCodeStore implements PendingReferralCodeStore {
  HivePendingReferralCodeStore(this._box);

  static const _codeKey = 'referral:pendingCode';
  static const _assignedUserKey = 'referral:assignedUserId';
  static const _attemptedUserKey = 'referral:attemptedUserId';

  final Box<dynamic> _box;

  @override
  String? get code => _text(_box.get(_codeKey));
  @override
  String? get assignedUserId => _text(_box.get(_assignedUserKey));
  @override
  String? get attemptedUserId => _text(_box.get(_attemptedUserKey));

  @override
  Future<void> saveCode(String value) async {
    await _box.put(_codeKey, value);
    await _box.delete(_assignedUserKey);
    await _box.delete(_attemptedUserKey);
  }

  @override
  Future<void> assignToUser(String userId) =>
      _box.put(_assignedUserKey, userId);

  @override
  Future<void> markAttempted(String userId) =>
      _box.put(_attemptedUserKey, userId);

  @override
  Future<void> resetAttempt() => _box.delete(_attemptedUserKey);

  @override
  Future<void> clear() async {
    await _box.deleteAll([_codeKey, _assignedUserKey, _attemptedUserKey]);
  }

  String? _text(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
