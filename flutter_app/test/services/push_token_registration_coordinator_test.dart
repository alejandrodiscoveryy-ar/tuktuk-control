import 'package:control_tuk_tuk/services/push_token_registration_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeRepository repository;
  late _MemoryState state;
  late String? currentToken;
  late PushTokenRegistrationCoordinator coordinator;

  setUp(() {
    repository = _FakeRepository();
    state = _MemoryState();
    currentToken = 'token-a';
    coordinator = PushTokenRegistrationCoordinator(
      repository: repository,
      state: state,
      tokenProvider: () async => currentToken,
      platform: 'android',
      clock: () => DateTime.utc(2026, 8, 21, 12),
    );
  });

  tearDown(() => coordinator.dispose());

  test('sin usuario autenticado conserva token pendiente y no registra',
      () async {
    await coordinator.handleTokenRefresh('token-a');

    expect(repository.registrations, isEmpty);
    expect(state.pendingToken, 'token-a');
  });

  test('usuario autenticado registra token con identidad actual', () async {
    await coordinator.handleAuthenticatedUser('user-1');

    expect(repository.registrations, [('user-1', 'token-a', 'android')]);
    expect(state.lastToken, 'token-a');
    expect(state.pendingToken, isNull);
  });

  test('mismo token actualiza sin generar identidad duplicada', () async {
    await coordinator.handleAuthenticatedUser('user-1');
    await coordinator.handleAuthenticatedUser('user-1');

    expect(repository.registrations, hasLength(2));
    expect(
      repository.registrations.toSet(),
      {('user-1', 'token-a', 'android')},
    );
    expect(state.lastToken, 'token-a');
  });

  test('refresh elimina token anterior antes de registrar el nuevo', () async {
    await coordinator.handleAuthenticatedUser('user-1');
    await coordinator.handleTokenRefresh('token-b');

    expect(repository.events, [
      'register:user-1:token-a',
      'delete:user-1:token-a',
      'register:user-1:token-b',
    ]);
    expect(state.lastToken, 'token-b');
  });

  test('logout elimina token mientras conserva el usuario indicado', () async {
    await coordinator.handleAuthenticatedUser('user-1');
    await coordinator.unregisterBeforeSignOut('user-1');

    expect(repository.deletions, [('user-1', 'token-a')]);
    expect(state.lastToken, isNull);
  });

  test('fallo de red conserva registro pendiente y no lanza error', () async {
    repository.failRegistration = true;

    await coordinator.handleAuthenticatedUser('user-1');

    expect(state.pendingToken, 'token-a');
    expect(state.lastToken, isNull);
  });

  test('selecciona plataforma android y web correctamente', () {
    expect(pushTokenPlatform(isWeb: false), 'android');
    expect(pushTokenPlatform(isWeb: true), 'web');
  });
}

class _FakeRepository implements PushDeviceTokenRepository {
  final List<(String, String, String)> registrations = [];
  final List<(String, String)> deletions = [];
  final List<String> events = [];
  bool failRegistration = false;

  @override
  Future<void> register({
    required String userId,
    required String token,
    required String platform,
    required DateTime now,
  }) async {
    if (failRegistration) throw const _NetworkError();
    registrations.add((userId, token, platform));
    events.add('register:$userId:$token');
  }

  @override
  Future<void> delete({required String userId, required String token}) async {
    deletions.add((userId, token));
    events.add('delete:$userId:$token');
  }
}

class _MemoryState implements PushTokenStateStore {
  @override
  String? lastToken;
  @override
  String? pendingToken;
  @override
  String? pendingDeleteToken;
  @override
  String? pendingDeleteUserId;

  @override
  Future<void> setLastToken(String? value) async => lastToken = value;

  @override
  Future<void> setPendingToken(String? value) async => pendingToken = value;

  @override
  Future<void> setPendingDelete({String? userId, String? token}) async {
    pendingDeleteUserId = userId;
    pendingDeleteToken = token;
  }
}

class _NetworkError implements Exception {
  const _NetworkError();
}
