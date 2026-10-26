import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('boton flotante circular y controlado por actividad', () {
    final native = File(
      'android/app/src/main/kotlin/com/alejandrocruz/'
      'tuktukcontrol/DriverFloatingShortcut.kt',
    ).readAsStringSync();

    final activity = File(
      'android/app/src/main/kotlin/com/alejandrocruz/'
      'tuktukcontrol/MainActivity.kt',
    ).readAsStringSync();

    expect(native, contains('clipToOutline = true'));
    expect(native, contains('GradientDrawable.OVAL'));
    expect(native, contains('setBubbleVisible(shouldShow)'));
    expect(native, contains('removeBubble()'));

    expect(activity, contains('hostVisibilityChanged(true)'));
    expect(activity, contains('hostVisibilityChanged(false)'));
  });

  test('permisos con interfaz reducida y retorno automatico', () {
    final source = File(
      'lib/presentation/marketplace_android_alert_setup.dart',
    ).readAsStringSync();

    expect(source, contains('Activa las alertas de carreras'));
    expect(source, contains('Abrir ajustes'));
    expect(source, contains('didChangeAppLifecycleState'));
    expect(source, contains('widget.recheck()'));
    expect(source, isNot(contains('Ninguna comprobación garantiza')));
  });

  test('audio oficial protegido y canal anterior conservado', () {
    final keep = File(
      'android/app/src/main/res/raw/'
      'tuktuk_sound_keep.xml',
    ).readAsStringSync();

    final push = File(
      'lib/services/push_notification_service.dart',
    ).readAsStringSync();

    expect(keep, contains('@raw/tuktuk_nueva_carrera'));
    expect(push, contains('tuktuk_nuevas_carreras_v2'));
    expect(push, contains('tuktukJobNotificationChannelId'));
    expect(push, contains('createNotificationChannel(_jobChannelV2)'));
  });
}
