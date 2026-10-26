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

  test('halo cambia con las notificaciones nativas', () {
    final native = File(
      'android/app/src/main/kotlin/com/alejandrocruz/'
      'tuktukcontrol/DriverFloatingShortcut.kt',
    ).readAsStringSync();
    final bridge =
        File('lib/services/android_floating_button.dart').readAsStringSync();
    final jobs =
        File('lib/presentation/marketplace_jobs.dart').readAsStringSync();
    final shell = File('lib/presentation/screens.dart').readAsStringSync();

    expect(native, contains('inspectOwnJobNotifications()'));
    expect(native, contains('nm.activeNotifications.count'));
    expect(native, contains('tuktuk_nuevas_carreras_v1'));
    expect(native, contains('tuktuk_nuevas_carreras_v2'));
    expect(native, contains('Color.rgb(48, 217, 200)'));
    expect(native, contains('Color.rgb(255, 195, 76)'));
    expect(native, contains('Color.rgb(255, 107, 75)'));
    expect(native, contains('ObjectAnimator.ofFloat'));
    expect(native, contains('handler.removeCallbacks(checkNotifications)'));
    expect(bridge, contains("'attention': attention"));
    expect(jobs, contains('attention: marketplaceJobPushPending.value'));
    expect(
        shell,
        contains(
          '_marketplaceJobsNeedAttention.addListener(_refreshFloatingShortcut)',
        ));
  });
}
