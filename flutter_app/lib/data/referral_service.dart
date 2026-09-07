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

  Future<void> claim(String code, {required String userId}) async {
    final session = _client.auth.currentSession;
    if (session == null || session.user.id != userId) {
      throw StateError('La cuenta cambió antes del claim');
    }
    // Bind this request to the intended account even if auth changes while
    // the HTTP client is preparing the request. Never log this header.
    final response = await _client.rpc(
      'claim_referral_code',
      params: {
        'target_project_id': _projectId,
        'target_code': code,
      },
    ).setHeader('Authorization', 'Bearer ${session.accessToken}');
    if (response is! String || response.isEmpty) {
      throw const FormatException('Claim sin confirmación de relación');
    }
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
  static const _claimedCodesKey = 'referral:claimedCodesByUser';
  static const _failureKey = 'referral:failure';
  static const _stateKey = 'referral:pendingV2';

  final Box<dynamic> _box;

  Map<dynamic, dynamic> get _state {
    final value = _box.get(_stateKey);
    if (value is Map) return value;
    return {
      _codeKey: _box.get(_codeKey),
      _assignedUserKey:
          _box.get(_assignedUserKey) ?? _box.get(_attemptedUserKey),
      _attemptedUserKey: _box.get(_attemptedUserKey),
      _failureKey: _box.get(_failureKey),
    };
  }

  Future<void> _update(String key, Object? value) =>
      _box.put(_stateKey, {..._state, key: value});

  @override
  String? get code => normalizeReferralCode(_text(_state[_codeKey]));
  @override
  String? get assignedUserId => _text(_state[_assignedUserKey]);
  @override
  String? get attemptedUserId => _text(_state[_attemptedUserKey]);

  @override
  Map<dynamic, dynamic>? get failure {
    final value = _state[_failureKey];
    return value is Map ? value : null;
  }

  @override
  Future<void> saveFailure(Map<String, dynamic> value) =>
      _update(_failureKey, value);

  @override
  Future<void> saveCode(String value) async {
    await _box.put(_stateKey, {_codeKey: value});
  }

  @override
  Future<void> assignToUser(String userId) => _update(_assignedUserKey, userId);

  @override
  Future<void> markAttempted(String userId) =>
      _update(_attemptedUserKey, userId);

  @override
  Future<void> resetAttempt() => _box
      .put(_stateKey, {..._state, _attemptedUserKey: null, _failureKey: null});

  @override
  bool wasClaimedByUser(String userId, String code) {
    final values = _box.get(_claimedCodesKey);
    if (values is! Map) return false;
    return normalizeReferralCode(values[userId]?.toString()) == code;
  }

  @override
  Future<void> markClaimed(String userId, String code) async {
    final existing = _box.get(_claimedCodesKey);
    final values = existing is Map
        ? Map<String, String>.fromEntries(existing.entries.map(
            (entry) => MapEntry('${entry.key}', '${entry.value}'),
          ))
        : <String, String>{};
    values[userId] = code;
    await _box.put(_claimedCodesKey, values);
  }

  @override
  Future<void> clear() async {
    // A single Hive value keeps code and account ownership consistent on crash.
    // The tombstone prevents a previously migrated legacy code resurfacing.
    await _box.put(_stateKey, <String, dynamic>{});
  }

  String? _text(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
