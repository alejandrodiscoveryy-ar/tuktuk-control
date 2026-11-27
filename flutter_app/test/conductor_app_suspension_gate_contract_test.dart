import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('suspensión confirmada bloquea la aplicación completa, fallos de red no', () {
    final store = File('lib/data/record_store.dart').readAsStringSync();
    final ui = File('lib/presentation/screens.dart').readAsStringSync();
    final entry = File('lib/main.dart').readAsStringSync();
    final db = File(
      'supabase/migrations/20261121182500_conductor_app_access_suspension_gate.sql',
    ).readAsStringSync();

    expect(store, contains('get_my_tuktuk_conductor_app_access'));
    expect(store, contains('ConductorAppAccessState.suspended'));
    expect(store, contains('ConductorAppAccessState.unavailable'));
    expect(store, contains('conductorLocalAccessBlocked('));
    expect(ui, contains('if (localOnly)'));
    expect(ui, contains('Modo sin conexión'));
    expect(store, contains('_conductorAppBlockedUserKey'));
    expect(store, contains('await _supabase.auth.signOut();'));
    expect(store, contains('Timer.periodic(const Duration(seconds: 45)'));
    expect(store, contains('refreshConductorAppAccess()'));
    expect(store, contains('final allowed = accessAlreadyVerified'));
    expect(store, contains(': await _checkConductorAppAccess(authenticatedUser);'));
    expect(store, contains('if (!allowed ||'));
    expect(store, contains('_supabase.auth.currentUser?.id != authenticatedUser.id'));
    expect(store, contains('_startupAccessFuture = _checkConductorAppAccess(restoredUser);'));
    expect(store, contains('if (conductorAppAccessState != ConductorAppAccessState.allowed) return;'));

    expect(entry, contains('ConductorAppAccessGate('));
    expect(ui, contains('Acceso a TukTuk Conductor suspendido'));
    expect(ui, contains('No se pudo verificar la conexión'));
    expect(ui, contains('Comprobar acceso nuevamente'));
    expect(ui, contains('conductorAppAuthenticated'));

    expect(db, contains("p.slug='tuktuk-control' AND d.user_id=actor"));
    expect(db, contains("current_status='suspended' OR suspended_on IS NOT NULL"));
    expect(db, contains('REVOKE ALL ON FUNCTION'));
    expect(db, contains('TO authenticated;'));
    expect(db, isNot(contains('UPDATE auth.users')));
  });

  test('arranque rápido: splash oscuro, acceso limitado y push después del primer frame', () {
    final entry = File('lib/main.dart').readAsStringSync();
    final store = File('lib/data/record_store.dart').readAsStringSync();
    final ui = File('lib/presentation/screens.dart').readAsStringSync();
    final nativeTheme = File(
      'android/app/src/main/res/values/styles.xml',
    ).readAsStringSync();
    final nativeSplash = File(
      'android/app/src/main/res/values-v31/styles.xml',
    ).readAsStringSync();

    expect(entry, contains('WidgetsBinding.instance.addPostFrameCallback'));
    expect(entry, contains('retryForAuthenticatedUser('));
    expect(
      entry.indexOf('runApp(ControlTukTukApp(store: store));'),
      lessThan(entry.indexOf('await pushNotifications.initialize(')),
    );

    expect(store, contains('.timeout(const Duration(seconds: 10))'));
    expect(store, contains('ConductorAppAccessState.unavailable'));
    expect(store, contains('ConductorAppAccessState.suspended'));
    expect(ui, contains('Iniciando TukTuk'));
    expect(ui, contains('No se pudo verificar la conexión'));
    expect(ui, contains('registros locales'));
    expect(ui, contains('Por seguridad, no puedes recibir ni aceptar carreras'));
    expect(nativeTheme, contains('@color/brand_background'));
    expect(nativeTheme, isNot(contains('?android:colorBackground')));
    expect(nativeSplash, contains('android:windowSplashScreenBackground'));
    expect(nativeSplash, contains('@color/brand_background'));
  });

  test('temporary access failures retry without authorizing or signing out', () {
    final store = File('lib/data/record_store.dart').readAsStringSync();
    final start = store.indexOf('Future<bool> _fetchConductorAppAccess(');
    final end = store.indexOf('Future<void> refreshConductorAppAccess()', start);
    final access = store.substring(start, end);
    expect(access, contains('_scheduleConductorAccessRetry(target.id)'));
    expect(access, contains('ConductorAppAccessState.unavailable'));
    expect(access, contains('return false;'));
    expect(store, contains('if (_conductorAppAccessRequestUserId == target.id) return previous;'));
    expect(store, contains('_supabase.auth.currentUser?.id == userId'));
    expect(store, contains('const delays = [5, 15, 30, 45]'));
    expect(store, contains('_conductorAppAccessRequest = null;'));
    expect(store, contains('conductorAppAccessState == ConductorAppAccessState.allowed &&'));
    expect(store, contains('_resetConductorAccessRetry();'));
  });

}
