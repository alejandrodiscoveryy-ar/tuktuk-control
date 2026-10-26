import 'package:control_tuk_tuk/services/android_driver_alerts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object> soundOk() => {
    'appNotifications': true,
    'channelPresent': true,
    'channelImportance': 4,
    'channelHasSound': true,
    'notificationVolume': 8,
    'notificationMaxVolume': 15,
    'normalRinger': true,
    'dndAllows': true,
  };

  test('Android: permite continuar solo con todos los requisitos audibles', () {
    expect(AndroidDriverAlertStatus.fromMap(soundOk()).ready, isTrue);
  });

  test('Android: bloquea si las notificaciones están denegadas', () {
    final data = soundOk()..['appNotifications'] = false;
    final status = AndroidDriverAlertStatus.fromMap(data);
    expect(status.ready, isFalse);
    expect(status.settingsAction, 'openAppNotifications');
  });

  test('Android: dirige a ajustes del canal si está silenciado', () {
    final data = soundOk()..['channelHasSound'] = false;
    final status = AndroidDriverAlertStatus.fromMap(data);
    expect(status.ready, isFalse);
    expect(status.settingsAction, 'openJobChannel');
  });

  test('Android: detecta volumen cero, vibración y No molestar', () {
    for (final change in <Map<String, Object>>[
      {'notificationVolume': 0},
      {'normalRinger': false},
      {'dndAllows': false},
    ]) {
      final status = AndroidDriverAlertStatus.fromMap(soundOk()..addAll(change));
      expect(status.ready, isFalse);
      expect(status.settingsAction, 'openSoundSettings');
    }
  });

  test('Android: canal ausente no se considera preparado', () {
    final status = AndroidDriverAlertStatus.fromMap(soundOk()..['channelPresent'] = false);
    expect(status.ready, isFalse);
  });
}
