import 'dart:async';

import 'package:control_tuk_tuk/services/marketplace_operational_gps_io.dart';
import 'package:control_tuk_tuk/services/marketplace_operational_gps_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

Position fix({
  double latitude = 23.1136,
  double longitude = -82.3666,
  DateTime? capturedAt,
  double accuracy = 5,
  double heading = 90,
  double speed = 2,
}) =>
    Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: capturedAt ?? DateTime.now().toUtc(),
      accuracy: accuracy,
      altitude: 0,
      heading: heading,
      speed: speed,
      speedAccuracy: 1,
      isMocked: false,
    );

class FakeGpsDevice implements MarketplaceGpsDevice {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requestedPermission = LocationPermission.whileInUse;
  int permissionRequests = 0;
  int cachedReads = 0;
  int currentReads = 0;
  Position? cached;
  Position current = fix();
  Object? currentError;
  double simulatedDistance = 0;
  final streamController = StreamController<Position>.broadcast();
  LocationSettings? lastSettings;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return requestedPermission;
  }

  @override
  Future<Position?> lastKnownPosition() async {
    cachedReads++;
    return cached;
  }

  @override
  Future<Position> currentPosition(LocationSettings settings) async {
    lastSettings = settings;
    currentReads++;
    if (currentError != null) throw currentError!;
    return current;
  }

  @override
  Stream<Position> positionStream(LocationSettings settings) {
    lastSettings = settings;
    return streamController.stream;
  }

  @override
  double distanceBetween(Position previous, Position current) =>
      simulatedDistance;

  Future<void> close() => streamController.close();
}

void main() {
  late FakeGpsDevice device;
  late List<MarketplaceGpsPositionPayload> deliveries;
  late MarketplaceOperationalGpsIo io;

  setUp(() {
    device = FakeGpsDevice();
    deliveries = [];
    io = MarketplaceOperationalGpsIo(
      device: device,
      sender: (payload) async { deliveries.add(payload); },
    );
  });

  tearDown(() async => device.close());

  test('GPS apagado o sin permiso no se confunde con señal disponible', () async {
    device.enabled = false;
    expect(
      await io.checkAccess(requestPermission: true),
      MarketplaceGpsIssue.locationDisabled,
    );
    expect(device.permissionRequests, 0);
    device.enabled = true;
    device.permission = LocationPermission.denied;
    expect(
      await io.checkAccess(requestPermission: false),
      MarketplaceGpsIssue.permissionDenied,
    );
    expect(device.permissionRequests, 0);
    expect(await io.checkAccess(requestPermission: true), isNull);
    expect(device.permissionRequests, 1);
  });

  test('permiso permanente denegado no solicita otro diálogo', () async {
    device.permission = LocationPermission.deniedForever;
    expect(
      await io.checkAccess(requestPermission: true),
      MarketplaceGpsIssue.permissionDenied,
    );
    expect(device.permissionRequests, 0);
  });

  test('lectura web no utiliza GPS cacheado', () async {
    device.cached = fix();
    final position = await io.readPosition(activeService: false, isWeb: true);
    expect(position, same(device.current));
    expect(device.cachedReads, 0);
    expect(device.currentReads, 1);
    expect(device.lastSettings?.timeLimit, const Duration(seconds: 8));
  });

  test('Android disponible usa caché reciente y descarta la antigua', () async {
    final now = DateTime.now().toUtc();
    final recent = fix(capturedAt: now.subtract(const Duration(seconds: 20)));
    device.cached = recent;
    expect(
      await io.readPosition(activeService: false, isWeb: false),
      same(recent),
    );
    expect(device.currentReads, 0);
    device.cached = fix(capturedAt: now.subtract(const Duration(minutes: 4)));
    expect(
      await io.readPosition(activeService: false, isWeb: false),
      same(device.current),
    );
    expect(device.currentReads, 1);
  });

  test('error del sensor llega al controlador para reintentar', () async {
    device.currentError = StateError('GPS unavailable');
    await expectLater(
      io.readPosition(activeService: true, isWeb: true),
      throwsStateError,
    );
    expect(device.lastSettings?.timeLimit, const Duration(seconds: 10));
  });

  test('stream Android conserva heartbeat con vehículo quieto', () async {
    final received = <Position>[];
    final subscription = io
        .positionStream(isAndroid: true, activeService: false)
        .listen(received.add);
    expect(device.lastSettings, isA<AndroidSettings>());
    final settings = device.lastSettings! as AndroidSettings;
    expect(settings.distanceFilter, 0);
    device.streamController.add(fix());
    await Future<void>.delayed(Duration.zero);
    expect(received, hasLength(1));
    await subscription.cancel();
  });

  test('ignora coordenadas imposibles y evita duplicados sin movimiento', () {
    final now = DateTime.now().toUtc();
    final current = fix();
    expect(
      io.shouldPublish(
        position: fix(latitude: 100),
        lastPosition: null,
        lastSentAt: null,
        nowUtc: now,
        activeService: false,
      ),
      isFalse,
    );
    expect(
      io.shouldPublish(
        position: current,
        lastPosition: current,
        lastSentAt: now,
        nowUtc: now,
        activeService: false,
      ),
      isFalse,
    );
    device.simulatedDistance = 80;
    expect(
      io.shouldPublish(
        position: current,
        lastPosition: current,
        lastSentAt: now,
        nowUtc: now,
        activeService: false,
      ),
      isTrue,
    );
  });

  test('latido permite repetir una posición estacionaria cada 120 s', () {
    final now = DateTime.now().toUtc();
    final current = fix();
    expect(
      io.shouldPublish(
        position: current,
        lastPosition: current,
        lastSentAt: now.subtract(const Duration(seconds: 121)),
        nowUtc: now,
        activeService: false,
      ),
      isTrue,
    );
  });

  test('envío conserva conductor/vehículo, fecha y métricas saneadas', () async {
    final position = fix(heading: 400, speed: -1, accuracy: 12);
    await io.publishPosition(vehicleId: 'vehicle-test', position: position);
    expect(deliveries, hasLength(1));
    final payload = deliveries.single;
    expect(payload.vehicleId, 'vehicle-test');
    expect(payload.latitude, position.latitude);
    expect(payload.longitude, position.longitude);
    expect(payload.capturedAt, position.timestamp);
    expect(payload.accuracyM, 12);
    expect(payload.headingDegrees, isNull);
    expect(payload.speedMps, isNull);
  });
}
