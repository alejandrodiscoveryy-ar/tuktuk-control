import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_web_options.dart';
import 'web_foreground_notification.dart';

// Web only: Android conserva su canal actual hasta la fase APK autorizada.
void configureMarketplaceWebJobAlerts(bool enabled) =>
    setWebJobAlertEnabled(enabled);

void prepareMarketplaceWebJobAlertActivation() =>
    prepareWebJobAlertFromGesture();

// A voluntary audible preview: never a guarantee of background sound on Android.
void playMarketplaceWebJobSoundTest() => playWebJobSoundTest();

// Recovered offers use the same web alert path and job-id deduplication as FCM.
void notifyMarketplaceRecoveredWebJob(String jobId) {
  if (!kIsWeb) return;
  if (marketplaceJobIdFromPush({
        'kind': 'marketplace_job_available',
        'job_id': jobId,
      }) == null) {
    return;
  }
  showWebForegroundNotification(
    title: 'Nueva solicitud disponible',
    body: 'Abre Trabajos para ver una solicitud disponible.',
    marketplaceJobId: jobId,
  );
}

// Foreground recovery reuses the native notification service; it never
// claims a server dispatch was received/read when no FCM payload exists.
Future<void> Function(String)? _nativeRecoveredOffer;

bool notifyMarketplaceRecoveredAndroidJob(String jobId) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android ||
      marketplaceJobIdFromPush({
        'kind': 'marketplace_job_available',
        'job_id': jobId,
      }) == null) {
    return false;
  }
  final show = _nativeRecoveredOffer;
  if (show == null) return false;
  unawaited(show(jobId).catchError((_) {}));
  return true;
}

@visibleForTesting
int marketplaceNativeOfferNotificationId(String jobId) {
  var hash = 17;
  for (final unit in jobId.toLowerCase().codeUnits) {
    hash = (hash * 31 + unit) & 0x3fffffff;
  }
  // Reserve a distinct positive range for ride notifications.
  return hash | 0x40000000;
}

const tuktukNotificationChannelId = 'tuktuk_general';
const tuktukNotificationChannelName = 'TukTuk Conductor';
const tuktukJobNotificationChannelId = 'tuktuk_nuevas_carreras_v1';
const tuktukJobNotificationChannelName = 'Nuevas carreras';
const tuktukJobNotificationChannelV2Id = 'tuktuk_nuevas_carreras_v2';
const tuktukJobNotificationChannelV2Name =
    'Nuevas carreras (sonido oficial)';
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

// Receiving a push requests a refresh; opening it remains a separate action.
final marketplaceJobRefreshRequests = ValueNotifier<int>(0);
final marketplaceJobPushPending = ValueNotifier<bool>(false);

void handleForegroundPushData(Map<String, dynamic> data) {
  // A cancellation invalidates the active trip, but is never a new offer.
  if (data['kind'] == 'marketplace_job_cancelled') {
    final id = marketplaceJobIdFromPush({...data, 'kind': 'marketplace_job_available'});
    if (id != null) marketplaceJobRefreshRequests.value++;
    return;
  }
  if (marketplaceJobIdFromPush(data) == null) return;
  marketplaceJobPushPending.value = true;
  marketplaceJobRefreshRequests.value++;
}

String? marketplaceJobIdFromPush(Map<String, dynamic> data) {
  if (data['kind']?.toString() != 'marketplace_job_available') return null;
  final jobId = data['job_id']?.toString();
  return jobId != null &&
          RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
                  caseSensitive: false)
              .hasMatch(jobId)
      ? jobId
      : null;
}

// Una apertura real (tap), no recepción garantizada por FCM.
@visibleForTesting
int? marketplaceOpenedOfferNotificationId(Map<String, dynamic> data) {
  if (marketplaceJobIdFromPush(data) == null) {
    return null;
  }
  final raw = data['notification_id']?.toString();
  if (raw == null) {
    return null;
  }
  final id = int.tryParse(raw);
  if (id == null || id <= 0 || id > 9007199254740991 ||
      raw != id.toString()) {
    return null;
  }
  return id;
}

Future<void> markMarketplaceOpenedOffer(
  Map<String, dynamic> data, {
  required Future<void> Function(int notificationId) markRead,
}) async {
  final id = marketplaceOpenedOfferNotificationId(data);
  if (id == null) {
    return;
  }
  try {
    await markRead(id).timeout(const Duration(seconds: 5));
  } catch (_) {
    // No bloquear navegación ni aceptación ante una caída de internet.
  }
}

@visibleForTesting
String notificationChannelForPush(Map<String, dynamic> data) =>
    marketplaceJobIdFromPush(data) == null
        ? tuktukNotificationChannelId
        : tuktukJobNotificationChannelV2Id;

String? marketplaceJobIdFromUrl(Uri uri) => marketplaceJobIdFromPush({
      'kind': 'marketplace_job_available',
      'job_id': uri.queryParameters['marketplace_job_id'],
    });

int appShellIndexAfterAuthentication({
  required int currentIndex,
  required String? marketplaceJobId,
  bool returnToJobs = false,
}) =>
    returnToJobs ? 2 : (marketplaceJobId == null ? 0 : currentIndex);

@visibleForTesting
Uri? appUpdateUri(Map<String, dynamic> data) {
  if (data['kind']?.toString() != 'app_update') return null;
  final actionUrl = data['action_url']?.toString().trim();
  final configuredUri =
      actionUrl == null || actionUrl.isEmpty ? null : Uri.tryParse(actionUrl);
  // Nunca abrir protocolos arbitrarios procedentes de un payload push.
  // Ante un enlace no HTTPS, mantener la ficha oficial como salida segura.
  final safeHttpsUrl = configuredUri != null &&
      configuredUri.scheme == 'https' &&
      configuredUri.host.isNotEmpty &&
      configuredUri.userInfo.isEmpty;
  return safeHttpsUrl ? configuredUri : Uri.parse(tuktukGooglePlayUrl);
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

enum MarketplaceWebAlertReadiness {
  ready,
  notificationsBlocked,
  tokenUnavailable,
  registrationFailed,
}

Future<MarketplaceWebAlertReadiness> verifyMarketplaceWebAlertReadiness({
  required Future<AuthorizationStatus> Function() checkPermission,
  required Future<String?> Function() requestToken,
  required Future<void> Function(String token) registerToken,
}) async {
  try {
    if (await checkPermission() != AuthorizationStatus.authorized) {
      return MarketplaceWebAlertReadiness.notificationsBlocked;
    }
  } catch (_) {
    return MarketplaceWebAlertReadiness.notificationsBlocked;
  }

  String? token;
  try {
    token = await requestToken();
  } catch (_) {
    return MarketplaceWebAlertReadiness.tokenUnavailable;
  }
  if (token == null || token.trim().isEmpty) {
    return MarketplaceWebAlertReadiness.tokenUnavailable;
  }
  try {
    await registerToken(token);
  } catch (_) {
    return MarketplaceWebAlertReadiness.registrationFailed;
  }
  return MarketplaceWebAlertReadiness.ready;
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
    description: 'Notificaciones generales de TukTuk Conductor',
    importance: Importance.high,
  );
  static const _jobChannel = AndroidNotificationChannel(
    tuktukJobNotificationChannelId,
    tuktukJobNotificationChannelName,
    description: 'Avisos audibles de nuevas carreras disponibles',
    importance: Importance.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('tuktuk_nueva_carrera'),
    enableVibration: true,
  );

  // Canal nuevo para no reutilizar una configuracion sonora antigua.
  // El backend debe migrarse de forma coordinada antes de emplearlo
  // para las notificaciones recibidas con la app bloqueada.
  static const _jobChannelV2 = AndroidNotificationChannel(
    tuktukJobNotificationChannelV2Id,
    tuktukJobNotificationChannelV2Name,
    description: 'Avisos de nuevas carreras con sonido TukTuk',
    importance: Importance.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('tuktuk_nueva_carrera'),
    enableVibration: true,
  );

  static const _nativeJobDetails = AndroidNotificationDetails(
    tuktukJobNotificationChannelV2Id,
    tuktukJobNotificationChannelV2Name,
    channelDescription: 'Avisos audibles de nuevas carreras disponibles',
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_stat_tuktuk',
    playSound: true,
    sound: RawResourceAndroidNotificationSound('tuktuk_nueva_carrera'),
    enableVibration: true,
    onlyAlertOnce: true,
  );

  final FirebaseMessaging? _messagingOverride;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final StreamController<String> _tokenRefreshController =
      StreamController<String>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Set<String> _nativeForegroundOfferIds = <String>{};
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
          android: AndroidInitializationSettings('ic_stat_tuktuk'),
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
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_jobChannel);
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_jobChannelV2);
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
      } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android &&
          onMessageOpened != null) {
        // Local notifications (including recovered offers) can open a cold app.
        try {
          final launch = await _localNotifications.getNotificationAppLaunchDetails();
          if (launch?.didNotificationLaunchApp == true) {
            final data = decodePushMessageData(launch?.notificationResponse?.payload);
            if (data.isNotEmpty) await onMessageOpened(data);
          }
        } catch (_) {
          // An unavailable native launch detail must not block initialization.
        }
      }
      _initialized = true;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        _nativeRecoveredOffer = _showRecoveredOffer;
      }
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

  Future<void> _showRecoveredOffer(String jobId) async {
    if (!_initialized || _nativeForegroundOfferIds.contains(jobId.toLowerCase())) {
      return;
    }
    await _localNotifications.show(
      id: marketplaceNativeOfferNotificationId(jobId),
      title: 'Nueva solicitud disponible',
      body: 'Abre Trabajos para ver una solicitud disponible.',
      notificationDetails: const NotificationDetails(android: _nativeJobDetails),
      payload: encodePushMessageData({
        'kind': 'marketplace_job_available',
        'job_id': jobId,
      }),
    );
  }

  Future<void> _showForegroundMessage(RemoteMessage message) async {
    final jobId = marketplaceJobIdFromPush(message.data);
    if (!kIsWeb && jobId != null) {
      // Mark before refresh so a recovered offer cannot overwrite the real
      // FCM payload (including its notification_id) during the race.
      _nativeForegroundOfferIds.add(jobId.toLowerCase());
      if (_nativeForegroundOfferIds.length > 256) {
        _nativeForegroundOfferIds.remove(_nativeForegroundOfferIds.first);
      }
    }
    handleForegroundPushData(message.data);
    final title = message.notification?.title ?? message.data['title']?.toString()
        ?? (jobId == null ? null : 'Nueva solicitud disponible');
    final body = message.notification?.body ?? message.data['body']?.toString()
        ?? (jobId == null ? null : 'Abre Trabajos para ver una solicitud disponible.');
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }
    if (kIsWeb) {
      showWebForegroundNotification(
        title: title ?? tuktukNotificationChannelName,
        body: body ?? '',
        marketplaceJobId: marketplaceJobIdFromPush(message.data),
      );
      return;
    }
    await _localNotifications.show(
      id: jobId == null
          ? (message.messageId?.hashCode ?? message.hashCode) & 0x3fffffff
          : marketplaceNativeOfferNotificationId(jobId),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: notificationChannelForPush(message.data) ==
                tuktukJobNotificationChannelV2Id
            ? _nativeJobDetails
            : const AndroidNotificationDetails(
                tuktukNotificationChannelId,
                tuktukNotificationChannelName,
                channelDescription:
                    'Notificaciones generales de TukTuk Conductor',
                importance: Importance.high,
                priority: Priority.high,
                icon: 'ic_stat_tuktuk',
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
    if (_nativeRecoveredOffer == _showRecoveredOffer) {
      _nativeRecoveredOffer = null;
    }
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _tokenRefreshController.close();
  }
}
