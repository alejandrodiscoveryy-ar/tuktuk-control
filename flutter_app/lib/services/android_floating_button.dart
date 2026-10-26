import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AndroidFloatingButtonBridge {
  static const MethodChannel _channel = MethodChannel(
    'com.alejandrocruz.tuktukcontrol/floating_shortcut',
  );

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> canDraw() async {
    if (!supported) return false;

    try {
      return await _channel.invokeMethod<bool>('canDraw') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openPermission() async {
    if (!supported) return false;

    try {
      return await _channel.invokeMethod<bool>('openPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> setVisible({
    required bool visible,
    int count = 0,
    bool attention = false,
  }) async {
    if (!supported) return false;

    try {
      return await _channel.invokeMethod<bool>(
            'setVisible',
            <String, dynamic>{
              'visible': visible,
              'count': count.clamp(0, 99),
              'attention': attention,
            },
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> acknowledgeJobs() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('acknowledgeJobs') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> consumeOpenJobs() async {
    if (!supported) return false;

    try {
      return await _channel.invokeMethod<bool>('consumeOpenJobs') ?? false;
    } catch (_) {
      return false;
    }
  }

  static void setOpenJobsHandler(VoidCallback? handler) {
    if (!supported) return;

    _channel.setMethodCallHandler(
      handler == null
          ? null
          : (call) async {
              if (call.method == 'openJobs') {
                handler();
              }
            },
    );
  }
}
