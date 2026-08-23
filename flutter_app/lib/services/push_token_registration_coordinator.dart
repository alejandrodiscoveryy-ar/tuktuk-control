import 'dart:async';

import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const tuktukSupabaseProjectId = 'dfb41cea-a812-46f2-b511-7a60bd3d78af';

@visibleForTesting
String pushTokenPlatform({required bool isWeb}) => isWeb ? 'web' : 'android';

abstract interface class PushDeviceTokenRepository {
  Future<void> register({
    required String userId,
    required String token,
    required String platform,
    required DateTime now,
  });

  Future<void> delete({required String userId, required String token});
}

class SupabasePushDeviceTokenRepository implements PushDeviceTokenRepository {
  SupabasePushDeviceTokenRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> register({
    required String userId,
    required String token,
    required String platform,
    required DateTime now,
  }) async {
    final timestamp = now.toUtc().toIso8601String();
    await _client.from('push_device_tokens').upsert(
      {
        'project_id': tuktukSupabaseProjectId,
        'user_id': userId,
        'token': token,
        'platform': platform,
        'enabled': true,
        'last_seen_at': timestamp,
        'updated_at': timestamp,
      },
      onConflict: 'project_id,token',
    );
  }

  @override
  Future<void> delete({required String userId, required String token}) async {
    await _client
        .from('push_device_tokens')
        .delete()
        .eq('project_id', tuktukSupabaseProjectId)
        .eq('user_id', userId)
        .eq('token', token);
  }
}

abstract interface class PushTokenStateStore {
  String? get lastToken;
  String? get pendingToken;
  String? get pendingDeleteToken;
  String? get pendingDeleteUserId;

  Future<void> setLastToken(String? value);
  Future<void> setPendingToken(String? value);
  Future<void> setPendingDelete({String? userId, String? token});
}

class HivePushTokenStateStore implements PushTokenStateStore {
  HivePushTokenStateStore(this._box);

  static const _lastTokenKey = 'push:lastToken';
  static const _pendingTokenKey = 'push:pendingToken';
  static const _pendingDeleteTokenKey = 'push:pendingDeleteToken';
  static const _pendingDeleteUserKey = 'push:pendingDeleteUserId';

  final Box<dynamic> _box;

  @override
  String? get lastToken => _string(_box.get(_lastTokenKey));
  @override
  String? get pendingToken => _string(_box.get(_pendingTokenKey));
  @override
  String? get pendingDeleteToken => _string(_box.get(_pendingDeleteTokenKey));
  @override
  String? get pendingDeleteUserId => _string(_box.get(_pendingDeleteUserKey));

  @override
  Future<void> setLastToken(String? value) => _put(_lastTokenKey, value);
  @override
  Future<void> setPendingToken(String? value) => _put(_pendingTokenKey, value);

  @override
  Future<void> setPendingDelete({String? userId, String? token}) async {
    await _put(_pendingDeleteUserKey, userId);
    await _put(_pendingDeleteTokenKey, token);
  }

  String? _string(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  Future<void> _put(String key, String? value) =>
      value == null ? _box.delete(key) : _box.put(key, value);
}

typedef PushTokenProvider = Future<String?> Function();

class PushTokenRegistrationCoordinator {
  PushTokenRegistrationCoordinator({
    required PushDeviceTokenRepository repository,
    required PushTokenStateStore state,
    required PushTokenProvider tokenProvider,
    required String platform,
    DateTime Function()? clock,
  })  : _repository = repository,
        _state = state,
        _tokenProvider = tokenProvider,
        _platform = platform,
        _clock = clock ?? DateTime.now;

  factory PushTokenRegistrationCoordinator.supabase({
    required SupabaseClient client,
    required Box<dynamic> cache,
    required PushTokenProvider tokenProvider,
  }) =>
      PushTokenRegistrationCoordinator(
        repository: SupabasePushDeviceTokenRepository(client),
        state: HivePushTokenStateStore(cache),
        tokenProvider: tokenProvider,
        platform: pushTokenPlatform(isWeb: kIsWeb),
      );

  final PushDeviceTokenRepository _repository;
  final PushTokenStateStore _state;
  final PushTokenProvider _tokenProvider;
  final String _platform;
  final DateTime Function() _clock;
  String? _activeUserId;
  Future<void> _serial = Future<void>.value();
  StreamSubscription<String>? _tokenRefreshSubscription;

  void listenToTokenRefreshes(Stream<String> tokenRefreshes) {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = tokenRefreshes.listen(
      (token) => unawaited(handleTokenRefresh(token)),
      onError: (_) {},
    );
  }

  Future<void> handleAuthenticatedUser(String userId) => _enqueue(() async {
        _activeUserId = userId;
        await _retryPendingDelete(userId);
        final token = _state.pendingToken ?? await _tokenProvider();
        if (token != null && token.isNotEmpty) {
          await _register(userId, token);
        }
      });

  Future<void> handleTokenRefresh(String newToken) => _enqueue(() async {
        if (newToken.isEmpty) return;
        final userId = _activeUserId;
        if (userId == null) {
          await _state.setPendingToken(newToken);
          return;
        }
        final previous = _state.lastToken;
        if (previous != null && previous != newToken) {
          try {
            await _repository.delete(userId: userId, token: previous);
          } catch (_) {
            await _state.setPendingDelete(userId: userId, token: previous);
          }
        }
        await _register(userId, newToken);
      });

  Future<void> retryForAuthenticatedUser(String userId) =>
      handleAuthenticatedUser(userId);

  Future<void> unregisterBeforeSignOut(String userId) => _enqueue(() async {
        final tokens = <String>{
          if (_state.lastToken case final token?) token,
          if (_state.pendingToken case final token?) token,
        };
        for (final token in tokens) {
          try {
            await _repository.delete(userId: userId, token: token);
            if (_state.lastToken == token) {
              await _state.setLastToken(null);
            }
            if (_state.pendingToken == token) {
              await _state.setPendingToken(null);
            }
          } catch (_) {
            await _state.setPendingDelete(userId: userId, token: token);
          }
        }
        _activeUserId = null;
      });

  Future<void> _register(String userId, String token) async {
    try {
      await _repository.register(
        userId: userId,
        token: token,
        platform: _platform,
        now: _clock(),
      );
      await _state.setLastToken(token);
      await _state.setPendingToken(null);
    } catch (_) {
      await _state.setPendingToken(token);
    }
  }

  Future<void> _retryPendingDelete(String userId) async {
    final token = _state.pendingDeleteToken;
    if (token == null || _state.pendingDeleteUserId != userId) return;
    try {
      await _repository.delete(userId: userId, token: token);
      await _state.setPendingDelete();
    } catch (_) {
      // Keep the minimal pending state for the next authenticated retry.
    }
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _serial.then((_) => operation());
    _serial = result.catchError((_) {});
    return result;
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
  }
}
