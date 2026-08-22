import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const tuktukNotificationChannelId = 'tuktuk_general';
const tuktukNotificationChannelName = 'TukTuk Control';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

typedef PushMessageOpenedCallback = FutureOr<void> Function(
  Map<String, dynamic> data,
);

@visibleForTesting
Future<void> requestPushPermissionSafely(
  Future<void> Function() requestPermission,
) async {
  try {
    await requestPermission();
  } catch (_) {
    // Permission and platform failures cannot prevent local app usage.
  }
}

class PushNotificationService {
  PushNotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _messagingOverride = messaging,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    tuktukNotificationChannelId,
    tuktukNotificationChannelName,
    description: 'Notificaciones generales de TukTuk Control',
    importance: Importance.high,
  );

  final FirebaseMessaging? _messagingOverride;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final StreamController<String> _tokenRefreshController =
      StreamController<String>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _initialized = false;

  bool get isInitialized => _initialized;
  Stream<String> get tokenRefreshes => _tokenRefreshController.stream;
  FirebaseMessaging get _messaging =>
      _messagingOverride ?? FirebaseMessaging.instance;

  Future<void> initialize({PushMessageOpenedCallback? onMessageOpened}) async {
    if (_initialized || kIsWeb) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (_) {},
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // A denied permission is a valid user choice and never blocks the app.
      await requestPushPermissionSafely(() async {
        await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      });

      _subscriptions.add(
        _messaging.onTokenRefresh.listen(
          _tokenRefreshController.add,
          onError: (_) {},
        ),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessage.listen(
          _showForegroundMessage,
          onError: (_) {},
        ),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen(
          (message) => _handleOpenedMessage(message, onMessageOpened),
          onError: (_) {},
        ),
      );

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        await _handleOpenedMessage(initialMessage, onMessageOpened);
      }
      _initialized = true;
    } catch (_) {
      // Firebase delivery is optional infrastructure; local app startup wins.
      _initialized = false;
    }
  }

  Future<String?> getToken() async {
    if (!_initialized || kIsWeb) return null;
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> _showForegroundMessage(RemoteMessage message) async {
    final title =
        message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }
    await _localNotifications.show(
      id: message.messageId?.hashCode ?? message.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          tuktukNotificationChannelId,
          tuktukNotificationChannelName,
          channelDescription: 'Notificaciones generales de TukTuk Control',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: message.data['kind']?.toString(),
    );
  }

  Future<void> _handleOpenedMessage(
    RemoteMessage message,
    PushMessageOpenedCallback? callback,
  ) async {
    // daily_exchange_rate intentionally opens the normal app shell for now.
    if (callback != null) await callback(message.data);
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _tokenRefreshController.close();
  }
}
