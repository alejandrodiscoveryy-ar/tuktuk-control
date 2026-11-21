import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('suspensión de conductor bloquea la aplicación completa', () {
    final store = File('lib/data/record_store.dart').readAsStringSync();
    final ui = File('lib/presentation/screens.dart').readAsStringSync();
    final entry = File('lib/main.dart').readAsStringSync();
    final db = File(
      'supabase/migrations/20261121182500_conductor_app_access_suspension_gate.sql',
    ).readAsStringSync();

    expect(store, contains('get_my_tuktuk_conductor_app_access'));
    expect(store, contains('ConductorAppAccessState.suspended'));
    expect(store, contains('ConductorAppAccessState.unavailable'));
    expect(store, contains('_conductorAppBlockedUserKey'));
    expect(store, contains('Timer.periodic(const Duration(seconds: 45)'));
    expect(store, contains('refreshConductorAppAccess()'));
    expect(store, contains('if (!await _checkConductorAppAccess(authenticatedUser)) return;'));
    expect(store, contains('if (conductorAppAccessState != ConductorAppAccessState.allowed) return;'));

    expect(entry, contains('ConductorAppAccessGate('));
    expect(ui, contains('Acceso a TukTuk Conductor suspendido'));
    expect(ui, contains('No se pudo verificar el acceso'));
    expect(ui, contains('Comprobar acceso nuevamente'));
    expect(ui, contains('conductorAppAuthenticated'));

    expect(db, contains("p.slug='tuktuk-control' AND d.user_id=actor"));
    expect(db, contains("current_status='suspended' OR suspended_on IS NOT NULL"));
    expect(db, contains('REVOKE ALL ON FUNCTION'));
    expect(db, contains('TO authenticated;'));
    expect(db, isNot(contains('UPDATE auth.users')));
  });
}
