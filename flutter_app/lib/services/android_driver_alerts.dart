import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.alejandrocruz.tuktukcontrol/driver_alerts');

/// A diagnosis, not a guarantee that a particular FCM message will arrive.
@immutable
class AndroidDriverAlertStatus {
  const AndroidDriverAlertStatus({
    required this.appNotifications,
    required this.channelPresent,
    required this.channelImportance,
    required this.channelHasSound,
    required this.notificationVolume,
    required this.notificationMaxVolume,
    required this.normalRinger,
    required this.dndAllows,
  });

  final bool appNotifications;
  final bool channelPresent;
  final int channelImportance;
  final bool channelHasSound;
  final int notificationVolume;
  final int notificationMaxVolume;
  final bool normalRinger;
  final bool dndAllows;

  bool get channelAudible =>
      channelPresent && channelImportance >= 3 && channelHasSound;
  bool get soundAudible =>
      notificationVolume > 0 && normalRinger && dndAllows;
  bool get ready => appNotifications && channelAudible && soundAudible;

  String get problem {
    if (!appNotifications) return 'Las notificaciones de TUKTUK están bloqueadas.';
    if (!channelPresent) return 'No se encontró el canal Nuevas carreras.';
    if (!channelAudible) return 'El canal Nuevas carreras está silenciado o desactivado.';
    if (!normalRinger) return 'El teléfono está en silencio o vibración.';
    if (!dndAllows) return 'No molestar puede silenciar las carreras.';
    if (notificationVolume == 0) return 'El volumen de notificaciones está en cero.';
    return 'Los ajustes de avisos están preparados.';
  }

  String get primaryAction {
    if (!appNotifications) return 'Abrir permisos de notificaciones';
    if (!channelAudible) return 'Abrir canal Nuevas carreras';
    return 'Abrir ajustes de sonido';
  }

  String get settingsAction {
    if (!appNotifications) return 'openAppNotifications';
    if (!channelAudible) return 'openJobChannel';
    return 'openSoundSettings';
  }

  static AndroidDriverAlertStatus fromMap(Map<dynamic, dynamic> data) {
    int number(String key) => (data[key] as num?)?.toInt() ?? 0;
    bool flag(String key) => data[key] == true;
    return AndroidDriverAlertStatus(
      appNotifications: flag('appNotifications'),
      channelPresent: flag('channelPresent'),
      channelImportance: number('channelImportance'),
      channelHasSound: flag('channelHasSound'),
      notificationVolume: number('notificationVolume'),
      notificationMaxVolume: number('notificationMaxVolume'),
      normalRinger: flag('normalRinger'),
      dndAllows: flag('dndAllows'),
    );
  }
}

class AndroidDriverAlertBridge {
  const AndroidDriverAlertBridge._();

  static Future<AndroidDriverAlertStatus?> inspect() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final data = await _channel.invokeMapMethod<dynamic, dynamic>('inspect');
      if (data == null) return null;
      return AndroidDriverAlertStatus.fromMap(data);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<bool> openSettings(String action) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    if (!<String>{
      'openAppNotifications',
      'openJobChannel',
      'openSoundSettings',
      'openLocationSettings',
    }.contains(action)) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>(action) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
