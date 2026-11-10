import 'package:geolocator/geolocator.dart';

import 'marketplace_operational_gps_policy.dart';

abstract class MarketplaceGpsDevice {
  Future<bool> isEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position?> lastKnownPosition();
  Future<Position> currentPosition(LocationSettings settings);
  Stream<Position> positionStream(LocationSettings settings);
  double distanceBetween(Position before, Position after);
}

class GeolocatorMarketplaceGpsDevice implements MarketplaceGpsDevice {
  const GeolocatorMarketplaceGpsDevice();

  @override
  Future<bool> isEnabled() => Geolocator.isLocationServiceEnabled();
  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();
  @override
  Future<LocationPermission> requestPermission() => Geolocator.requestPermission();
  @override
  Future<Position?> lastKnownPosition() => Geolocator.getLastKnownPosition();
  @override
  Future<Position> currentPosition(LocationSettings settings) =>
      Geolocator.getCurrentPosition(locationSettings: settings);
  @override
  Stream<Position> positionStream(LocationSettings settings) =>
      Geolocator.getPositionStream(locationSettings: settings);
  @override
  double distanceBetween(Position before, Position after) =>
      Geolocator.distanceBetween(
        before.latitude, before.longitude, after.latitude, after.longitude,
      );
}

class MarketplaceGpsPositionPayload {
  const MarketplaceGpsPositionPayload({
    required this.vehicleId,
    required this.position,
  });

  final String vehicleId;
  final Position position;

  double get latitude => position.latitude;
  double get longitude => position.longitude;
  DateTime get capturedAt => position.timestamp;
  double? get accuracyM => MarketplaceOperationalLocationPolicy.safeMetric(
        position.accuracy, min: 0, max: 5000,
      );
  double? get headingDegrees => MarketplaceOperationalLocationPolicy.safeMetric(
        position.heading, min: 0, max: 359.999,
      );
  double? get speedMps => MarketplaceOperationalLocationPolicy.safeMetric(
        position.speed, min: 0, max: 100,
      );
}

/// Aísla lectura y envío; las transiciones de jornada siguen en la pantalla.
class MarketplaceOperationalGpsIo {
  MarketplaceOperationalGpsIo({
    required Future<void> Function(MarketplaceGpsPositionPayload) sender,
    MarketplaceGpsDevice? device,
  })  : _sender = sender,
        _device = device ?? const GeolocatorMarketplaceGpsDevice();

  final Future<void> Function(MarketplaceGpsPositionPayload) _sender;
  final MarketplaceGpsDevice _device;

  Future<MarketplaceGpsIssue?> checkAccess({
    required bool requestPermission,
  }) async {
    if (!await _device.isEnabled()) return MarketplaceGpsIssue.locationDisabled;
    var permission = await _device.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await _device.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return MarketplaceGpsIssue.permissionDenied;
    }
    return null;
  }

  LocationSettings streamSettings({
    required bool isAndroid,
    required bool activeService,
  }) {
    if (isAndroid) {
      return AndroidSettings(
        accuracy: activeService ? LocationAccuracy.high : LocationAccuracy.medium,
        distanceFilter: activeService ? 10 : 0,
        intervalDuration: MarketplaceOperationalLocationPolicy.streamInterval(
          activeService: activeService,
        ),
        foregroundNotificationConfig: activeService
            ? const ForegroundNotificationConfig(
                notificationTitle: 'TUKTUK · servicio activo',
                notificationText:
                    'Compartiendo tu ubicación durante el servicio en curso.',
                notificationChannelName: 'Servicio activo TUKTUK',
                enableWakeLock: true,
                setOngoing: true,
              )
            : const ForegroundNotificationConfig(
                notificationTitle: 'TUKTUK · trabajando',
                notificationText:
                    'Compartiendo tu ubicación mientras estás en Trabajar.',
                notificationChannelName: 'Jornada activa TUKTUK',
                enableWakeLock: false,
                setOngoing: true,
              ),
      );
    }
    return LocationSettings(
      accuracy: activeService ? LocationAccuracy.high : LocationAccuracy.medium,
      distanceFilter: activeService ? 10 : 0,
    );
  }

  Stream<Position> positionStream({
    required bool isAndroid,
    required bool activeService,
  }) =>
      _device.positionStream(
        streamSettings(isAndroid: isAndroid, activeService: activeService),
      );

  Future<Position> readPosition({
    required bool activeService,
    required bool isWeb,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    if (MarketplaceOperationalLocationPolicy.shouldReadLastKnownPosition(
      activeService: activeService, isWeb: isWeb,
    )) {
      final cached = await _device.lastKnownPosition();
      if (cached != null &&
          MarketplaceOperationalLocationPolicy.cachedPositionUsable(
            cached, nowUtc,
          )) {
        return cached;
      }
    }
    return _device.currentPosition(LocationSettings(
      accuracy: MarketplaceOperationalLocationPolicy.accuracy(
        activeService: activeService,
      ),
      timeLimit: activeService
          ? const Duration(seconds: 10)
          : const Duration(seconds: 8),
    ));
  }

  bool validCoordinates(Position position) =>
      position.latitude.isFinite &&
      position.latitude >= -90 &&
      position.latitude <= 90 &&
      position.longitude.isFinite &&
      position.longitude >= -180 &&
      position.longitude <= 180;

  bool shouldPublish({
    required Position position,
    required Position? lastPosition,
    required DateTime? lastSentAt,
    required DateTime nowUtc,
    required bool activeService,
  }) {
    if (!validCoordinates(position)) return false;
    final distanceMeters = lastPosition == null
        ? double.infinity
        : _device.distanceBetween(lastPosition, position);
    final heartbeatDue = lastSentAt == null ||
        nowUtc.difference(lastSentAt) >=
            MarketplaceOperationalLocationPolicy.heartbeatInterval(
              activeService: activeService,
            );
    final movementDue = distanceMeters >=
        MarketplaceOperationalLocationPolicy.distanceThresholdMeters(
          activeService: activeService,
        );
    return lastPosition == null || heartbeatDue || movementDue;
  }

  Future<void> publishPosition({
    required String vehicleId,
    required Position position,
  }) =>
      _sender(MarketplaceGpsPositionPayload(
        vehicleId: vehicleId,
        position: position,
      ));
}
