import 'dart:io';

import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el splash web no oculta una verificación todavía pendiente', () {
    expect(
      shouldRevealTuktukWebStartup(
        initialized: false,
        accessGateVisible: true,
        accessState: ConductorAppAccessState.checking,
      ),
      isFalse,
    );
    expect(
      shouldRevealTuktukWebStartup(
        initialized: true,
        accessGateVisible: true,
        accessState: ConductorAppAccessState.checking,
      ),
      isFalse,
    );
  });

  test('el splash se retira al permitir acceso o mostrar error real', () {
    for (final status in [
      ConductorAppAccessState.allowed,
      ConductorAppAccessState.suspended,
      ConductorAppAccessState.unavailable,
    ]) {
      expect(
        shouldRevealTuktukWebStartup(
          initialized: true,
          accessGateVisible: true,
          accessState: status,
        ),
        isTrue,
      );
    }
    expect(
      shouldRevealTuktukWebStartup(
        initialized: true,
        accessGateVisible: false,
        accessState: ConductorAppAccessState.checking,
      ),
      isTrue,
    );
  });

  test('la página arranca oscura y mantiene el shell hasta el aviso Flutter', () {
    final html = File('web/index.html').readAsStringSync();
    final bridge = File(
      'lib/services/project_identity_runtime_web.dart',
    ).readAsStringSync();

    expect(html, contains('html, body { margin: 0;'));
    expect(html, contains('background: #080D14'));
    expect(html, contains('id="tuktuk-web-startup"'));
    expect(html, contains('icons/Icon-192.png'));
    expect(html, contains('window.tuktukFinishStartup'));
    expect(html, contains("splash.classList.add('is-ready')"));
    expect(bridge, contains('@JS('));
    expect(bridge, contains('tuktukFinishStartup'));
    expect(bridge, contains('_tuktukFinishStartup();'));
  });

  test('inicialización paralela y autorización prioritaria, sin bypass', () {
    final entry = File('lib/main.dart').readAsStringSync();
    final store = File('lib/data/record_store.dart').readAsStringSync();

    expect(entry, contains('await Future.wait<void>(['));
    expect(entry, contains('Hive.openBox(_recordsBox),'));
    expect(entry, contains('await Supabase.initialize('));
    expect(store, contains('_startupAccessFuture = _checkConductorAppAccess(restoredUser);'));
    expect(store, contains('final allowed = reuseStartupCheck'));
    expect(store, contains('if (!allowed ||'));
    expect(store, contains('ConductorAppAccessState.unavailable'));
    expect(store, contains('ConductorAppAccessState.suspended'));
    expect(store, contains('.timeout(const Duration(seconds: 10))'));
    expect(store, contains('_supabase.auth.currentUser?.id != authenticatedUser.id'));
  });
}
