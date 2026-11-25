import 'package:geolocator/geolocator.dart' show LocationAccuracy, Position;

// Contrato GPS independiente de widgets, servicios y datos del conductor.
// Mantiene los umbrales existentes; no cambia frecuencia, permisos o llamadas.
enum MarketplaceGpsIssue { locationDisabled, permissionDenied, permissionDeniedForever, deliveryFailed }

bool marketplaceGpsNeedsAttention({
  required bool locationExpected,
  required DateTime? lastConfirmedAt,
  required DateTime nowUtc,
  required bool hasFailure,
  bool activeService = false,
}) {
  if (!locationExpected) return false;
  if (hasFailure || lastConfirmedAt == null) return true;
  final age = nowUtc.toUtc().difference(lastConfirmedAt.toUtc());
  // En una carrera, el pasajero deja de tener posicion GPS en vivo al
  // minuto. Avisar al conductor antes de los 5 minutos de la jornada idle.
  final maxAge = activeService
      ? const Duration(seconds: 75)
      : const Duration(minutes: 5);
  return age.isNegative || age > maxAge;
}

/// Reiniciar solamente un flujo GPS bloqueado, sin bucles ni reinicios
/// repetidos. Esta funcion NO autoriza servicios desde segundo plano.
bool marketplaceGpsForegroundRecoveryDue({
  required bool foreground,
  required bool locationExpected,
  required bool activeService,
  required bool permissionOrSensorBlocked,
  required DateTime? lastConfirmedAt,
  required DateTime? lastAttemptAt,
  required DateTime nowUtc,
}) {
  if (!foreground || !locationExpected || permissionOrSensorBlocked) {
    return false;
  }
  final now = nowUtc.toUtc();
  final maxAge = activeService
      ? const Duration(seconds: 90)
      : const Duration(minutes: 6);
  if (lastConfirmedAt != null) {
    final age = now.difference(lastConfirmedAt.toUtc());
    if (age < maxAge) return false;
  }
  if (lastAttemptAt != null) {
    final elapsed = now.difference(lastAttemptAt.toUtc());
    if (elapsed < (activeService
        ? const Duration(minutes: 2)
        : const Duration(minutes: 6))) {
      return false;
    }
  }
  return true;
}

class MarketplaceOperationalLocationPolicy {
  static const availableSampleInterval = Duration(minutes: 2);
  static const availableHeartbeatInterval = Duration(seconds: 120);
  static const activeSampleInterval = Duration(seconds: 15);
  static const availableStreamInterval = Duration(seconds: 60);
  static const activeHeartbeatInterval = Duration(seconds: 30);

  static const availableDistanceMeters = 75.0;
  static const activeDistanceMeters = 15.0;

  static bool isActiveServiceStatus(String status) {
    return status == 'accepted' ||
        status == 'en_route' ||
        status == 'pickup' ||
        status == 'in_progress' ||
        status == 'incident';
  }

  static Duration sampleInterval({required bool activeService}) =>
      activeService ? activeSampleInterval : availableSampleInterval;

  static Duration streamInterval({required bool activeService}) =>
      activeService ? activeSampleInterval : availableStreamInterval;

  // El navegador solo se actualiza mientras esta vivo; Android usa servicio GPS.
  static bool usesContinuousStream({
    required bool isAndroid,
    required bool activeService,
  }) => isAndroid || activeService;

  static Duration heartbeatInterval({required bool activeService}) =>
      activeService ? activeHeartbeatInterval : availableHeartbeatInterval;

  static Duration failureRetryDelay({required bool activeService}) =>
      activeService ? const Duration(seconds: 30) : const Duration(minutes: 1);

  static double distanceThresholdMeters({required bool activeService}) =>
      activeService ? activeDistanceMeters : availableDistanceMeters;

  static bool shouldReadLastKnownPosition({
    required bool activeService,
    required bool isWeb,
  }) =>
      !activeService && !isWeb;

  static LocationAccuracy accuracy({required bool activeService}) =>
      activeService ? LocationAccuracy.high : LocationAccuracy.medium;

  // No enviar coordenadas atrasadas por cortes de red, cache o sensores.
  // El margen de 5 s tolera pequeñas diferencias de reloj entre capas.
  static bool isFreshStreamFix({
    required DateTime capturedAt,
    required DateTime nowUtc,
    required bool activeService,
  }) {
    final age = nowUtc.toUtc().difference(capturedAt.toUtc());
    final maxAge = activeService
        ? const Duration(seconds: 45)
        : const Duration(minutes: 2);
    return age >= const Duration(seconds: -5) && age <= maxAge;
  }

  // Validaciones puras reutilizables por el muestreo web y Android.
  static double? safeMetric(
    double value, {
    required double min,
    required double max,
  }) {
    if (!value.isFinite || value < min || value > max) return null;
    return value;
  }

  static bool cachedPositionUsable(Position position, DateTime nowUtc) {
    final timestamp = position.timestamp.toUtc();
    final age = nowUtc.difference(timestamp);
    return !age.isNegative &&
        age <= const Duration(seconds: 90) &&
        position.accuracy.isFinite &&
        position.accuracy >= 0 &&
        position.accuracy <= 500;
  }
}

// El texto permanece fuera de la pantalla; no modifica el estado GPS.
String marketplaceGpsWarningMessage(MarketplaceGpsIssue? issue) => switch (issue) {
  MarketplaceGpsIssue.locationDisabled =>
    'GPS desactivado. Activa la ubicación y toca para comprobar.',
  MarketplaceGpsIssue.permissionDenied =>
    'TUKTUK no tiene permiso GPS. Autorízalo para compartir tu ubicación.',
  MarketplaceGpsIssue.permissionDeniedForever =>
    'Permiso GPS bloqueado. Toca para abrir los ajustes del teléfono.',
  MarketplaceGpsIssue.deliveryFailed =>
    'Ubicación sin confirmar. Comprueba tu conexión y toca para reintentar.',
  null => 'GPS sin confirmar. Toca para comprobar la ubicación.',
};
