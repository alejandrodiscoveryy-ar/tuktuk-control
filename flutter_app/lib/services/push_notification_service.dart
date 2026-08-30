import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_web_options.dart';
import 'web_foreground_notification.dart';

const tuktukNotificationChannelId = 'tuktuk_general';
const tuktukNotificationChannelName = 'TukTuk Control';
const tuktukWebVapidKey =
    'BF-az4NW8nREYEw-RvnBOfQ2wrJGttOjBhR_PD0SKWEKDHWqWvFBLdmka5e_0d-_Mptdrpxxfy1aF-FFPQpvfEE';
const tuktukWebMessagingServiceWorker = 'firebase-messaging-sw.js';
const tuktukGooglePlayUrl =
    'https://play.google.com/store/apps/details?id=com.alejandrocruz.tuktukcontrol';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

typedef PushMessageOpenedCallback = FutureOr<void> Function(
  Map<String, dynamic> data,
);

typedef ExternalUrlLauncher = Future<bool> Function(Uri uri);

@visibleForTesting
Uri? appUpdateUri(Map<String, dynamic> data) {
  if (data['kind']?.toString() != 'app_update') return null;
  final actionUrl = data['action_url']?.toString().trim();
  final configuredUri =
      actionUrl == null || actionUrl.isEmpty ? null : Uri.tryParse(actionUrl);
  return configuredUri?.hasScheme == true
      ? configuredUri
      : Uri.parse(tuktukGooglePlayUrl);
}

Future<void> openPushMessageAction(
  Map<String, dynamic> data, {
  ExternalUrlLauncher? launcher,
}) async {
  final uri = appUpdateUri(data);
  if (uri == null) return;
  try {
    await (launcher ?? _launchExternalUrl)(uri);
  } catch (_) {
    // Opening an optional external action must never interrupt the app.
  }
}

Future<bool> _launchExternalUrl(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

@visibleForTesting
String encodePushMessageData(Map<String, dynamic> data) => jsonEncode(
      data.map((key, value) => MapEntry(key, value?.toString())),
    );

@visibleForTesting
Map<String, dynamic> decodePushMessageData(String? payload) {
  if (payload == null || payload.isEmpty) return const {};
  try {
    final decoded = jsonDecode(payload);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : const <String, dynamic>{};
  } catch (_) {
    return const {};
  }
}

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

typedef PushTokenGetter = Future<String?> Function({
  String? vapidKey,
  String? serviceWorkerScriptPath,
});

@visibleForTesting
Future<String?> getPushTokenSafely({
  required bool isWeb,
  required PushTokenGetter getToken,
}) async {
  try {
    return await getToken(
      vapidKey: isWeb ? tuktukWebVapidKey : null,
      serviceWorkerScriptPath: isWeb ? tuktukWebMessagingServiceWorker : null,
    );
  } catch (_) {
    return null;
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
    if (_initialized) return;
    try {
      await Firebase.initializeApp(
        options: kIsWeb ? tuktukFirebaseWebOptions : null,
      );
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );

        const initializationSettings = InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        );
        await _localNotifications.initialize(
          settings: initializationSettings,
          onDidReceiveNotificationResponse: (response) {
            final data = decodePushMessageData(response.payload);
            if (data.isNotEmpty && onMessageOpened != null) {
              unawaited(Future.sync(() => onMessageOpened(data)));
            }
          },
        );
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_channel);
      }

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
    if (!_initialized) return null;
    return getPushTokenSafely(
      isWeb: kIsWeb,
      getToken: ({vapidKey, serviceWorkerScriptPath}) => _messaging.getToken(
        vapidKey: vapidKey,
        serviceWorkerScriptPath: serviceWorkerScriptPath,
      ),
    );
  }

  Future<void> _showForegroundMessage(RemoteMessage message) async {
    final title =
        message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }
    if (kIsWeb) {
      showWebForegroundNotification(
        title: title ?? tuktukNotificationChannelName,
        body: body ?? '',
      );
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
      payload: encodePushMessageData(message.data),
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
