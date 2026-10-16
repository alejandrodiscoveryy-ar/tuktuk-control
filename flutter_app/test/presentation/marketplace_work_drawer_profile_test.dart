import 'dart:io';

import 'package:control_tuk_tuk/main.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  test('la cabecera prefiere el nombre del conductor al de Google', () {
    expect(
      marketplaceDriverHeaderName(
        registeredName: '  Ana Pérez  ',
        googleName: 'Ana Google',
      ),
      'Ana Pérez',
    );
    expect(
      marketplaceDriverHeaderName(
        registeredName: ' ',
        googleName: '  Carlos  ',
      ),
      'Carlos',
    );
    expect(marketplaceDriverHeaderName(), 'Conductor sin nombre');
  });

  test('la ubicación distingue un permiso real de uno bloqueado', () {
    expect(
      marketplaceDriverLocationPermissionLabel(LocationPermission.whileInUse),
      'Permitida mientras usas la app',
    );
    expect(
      marketplaceDriverLocationPermissionLabel(
        LocationPermission.deniedForever,
      ),
      'Bloqueada en ajustes',
    );
    expect(
      marketplaceDriverLocationPermissionLabel(null),
      'No se pudo comprobar',
    );
  });

  test(
    'las notificaciones no se presentan como activas si fueron denegadas',
    () {
      expect(
        marketplaceDriverNotificationPermissionLabel(
          AuthorizationStatus.authorized,
        ),
        'Permitidas',
      );
      expect(
        marketplaceDriverNotificationPermissionLabel(
          AuthorizationStatus.denied,
        ),
        'No permitidas',
      );
      expect(
        marketplaceDriverNotificationPermissionLabel(null),
        'No se pudo comprobar',
      );
    },
  );

  test('Trabajo reutiliza referidos y conserva rutas operativas', () {
    final source = File(
      'lib/presentation/marketplace_jobs.dart',
    ).readAsStringSync();
    final permissions = File(
      'lib/presentation/marketplace_driver_permissions.dart',
    ).readAsStringSync();
    expect(source, contains("ValueKey('work-drawer-driver-name')"));
    expect(source, contains("ValueKey('work-drawer-driver-phone')"));
    expect(source, contains("ValueKey('work-drawer-google-email')"));
    expect(source, contains("ValueKey('work-drawer-referrals')"));
    expect(source, contains("ValueKey('work-drawer-permissions')"));
    expect(source, contains('_ReferralCard(store: widget.store)'));
    expect(source, contains('_workMenuItem(Icons.event_outlined'));
    expect(source, contains("'Mi actividad', 6"));
    expect(permissions, contains('Geolocator.checkPermission()'));
    expect(permissions, contains('getNotificationSettings()'));
    expect(permissions, contains('didChangeAppLifecycleState'));
    expect(permissions, isNot(contains('requestAlways')));
  });
}
