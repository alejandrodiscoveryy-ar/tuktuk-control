part of '../main.dart';

// Vector map used exclusively by the driver for an assigned active job.
// Coordinates and route geometries come from the existing protected gateway.
@visibleForTesting
String marketplaceDriverPointGeoJson(MarketplaceMapPoint? point) => jsonEncode({
      'type': 'FeatureCollection',
      'features': point == null
          ? <Object>[]
          : <Object>[
              {
                'type': 'Feature',
                'geometry': {
                  'type': 'Point',
                  'coordinates': [point.lon, point.lat],
                },
                'properties': <String, Object>{},
              },
            ],
    });

@visibleForTesting
String marketplaceDriverLineGeoJson(List<MarketplaceMapPoint> points) =>
    jsonEncode({
      'type': 'FeatureCollection',
      'features': points.length < 2
          ? <Object>[]
          : <Object>[
              {
                'type': 'Feature',
                'geometry': {
                  'type': 'LineString',
                  'coordinates': points
                      .map((point) => <double>[point.lon, point.lat])
                      .toList(growable: false),
                },
                'properties': <String, Object>{},
              },
            ],
    });

@visibleForTesting
bool marketplaceDriverGoingToPickup(String status) =>
    status == 'accepted' || status == 'en_route' || status == 'pickup';

@visibleForTesting
LatLng marketplaceDriverMapCenter({
  required MarketplaceMapPoint pickup,
  required MarketplaceMapPoint destination,
  required MarketplaceMapPoint? driver,
  required List<MarketplaceMapPoint> activeRoute,
}) {
  final pts = <MarketplaceMapPoint>[
    pickup,
    destination,
    if (driver != null) driver,
    ...activeRoute,
  ];
  final minLat = pts.map((p) => p.lat).reduce(min);
  final maxLat = pts.map((p) => p.lat).reduce(max);
  final minLon = pts.map((p) => p.lon).reduce(min);
  final maxLon = pts.map((p) => p.lon).reduce(max);
  return LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);
}

@visibleForTesting
double marketplaceDriverMapZoom({
  required MarketplaceMapPoint pickup,
  required MarketplaceMapPoint destination,
  required MarketplaceMapPoint? driver,
  required List<MarketplaceMapPoint> activeRoute,
}) {
  final pts = <MarketplaceMapPoint>[
    pickup,
    destination,
    if (driver != null) driver,
    ...activeRoute,
  ];
  final spanLat =
      pts.map((p) => p.lat).reduce(max) - pts.map((p) => p.lat).reduce(min);
  final spanLon =
      pts.map((p) => p.lon).reduce(max) - pts.map((p) => p.lon).reduce(min);
  final span = max(spanLat * 2.4, spanLon * 1.8);
  if (span > 0.2) return 9;
  if (span > 0.08) return 10;
  if (span > 0.035) return 11;
  if (span > 0.014) return 12;
  if (span > 0.005) return 13;
  return 14;
}

class MarketplaceDriverVectorMap extends StatefulWidget {
  const MarketplaceDriverVectorMap({
    required this.pickup,
    required this.destination,
    required this.driver,
    required this.toPickup,
    required this.toDestination,
    required this.goingToPickup,
    required this.stylePath,
    this.fullBleed = false,
    required this.idleCenter,
    required this.idleZoom,
    super.key,
  });

  final MarketplaceMapPoint? pickup;
  final MarketplaceMapPoint? destination;
  final MarketplaceMapPoint? driver;
  final MarketplaceRoutePath? toPickup;
  final MarketplaceRoutePath? toDestination;
  final bool goingToPickup;
  final bool fullBleed;
  final String stylePath;
  final LatLng idleCenter;
  final double idleZoom;

  @override
  State<MarketplaceDriverVectorMap> createState() =>
      _MarketplaceDriverVectorMapState();
}

class _MarketplaceDriverVectorMapState
    extends State<MarketplaceDriverVectorMap> {
  static const _pickupSource = 'tuktuk-driver-v1-pickup';
  static const _destinationSource = 'tuktuk-driver-v1-destination';
  static const _driverSource = 'tuktuk-driver-v1-position';
  static const _pickupRouteSource = 'tuktuk-driver-v1-route-to-pickup';
  static const _destinationRouteSource =
      'tuktuk-driver-v1-route-to-destination';
  mbx.MapboxMap? _map;
  bool _ready = false;
  String? _message;

  List<MarketplaceMapPoint> get _activeRoute =>
      (widget.goingToPickup ? widget.toPickup : widget.toDestination)?.points ??
      const <MarketplaceMapPoint>[];

  @override
  void didUpdateWidget(covariant MarketplaceDriverVectorMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pickup != widget.pickup ||
        oldWidget.destination != widget.destination ||
        oldWidget.driver != widget.driver ||
        oldWidget.toPickup != widget.toPickup ||
        oldWidget.toDestination != widget.toDestination ||
        oldWidget.goingToPickup != widget.goingToPickup ||
        oldWidget.idleCenter != widget.idleCenter ||
        oldWidget.idleZoom != widget.idleZoom) {
      unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    _map = null;
    super.dispose();
  }

  Future<void> _onStyleLoaded() async {
    final map = _map;
    if (map == null || _ready) return;
    try {
      await map.addSource(
        mbx.GeoJsonSource(
          id: _pickupSource,
          data: marketplaceDriverPointGeoJson(widget.pickup),
        ),
      );
      await map.addSource(
        mbx.GeoJsonSource(
          id: _destinationSource,
          data: marketplaceDriverPointGeoJson(widget.destination),
        ),
      );
      await map.addSource(
        mbx.GeoJsonSource(
          id: _driverSource,
          data: marketplaceDriverPointGeoJson(widget.driver),
        ),
      );
      await map.addSource(
        mbx.GeoJsonSource(
          id: _pickupRouteSource,
          data: marketplaceDriverLineGeoJson(
            widget.toPickup?.points ?? const [],
          ),
        ),
      );
      await map.addSource(
        mbx.GeoJsonSource(
          id: _destinationRouteSource,
          data: marketplaceDriverLineGeoJson(
            widget.toDestination?.points ?? const [],
          ),
        ),
      );
      for (final source in [_pickupRouteSource, _destinationRouteSource]) {
        await map.addLayer(
          mbx.LineLayer(
            id: '$source-outline',
            sourceId: source,
            lineColor: 0xFF07131A,
            lineWidth: 9,
            lineOpacity: source == _pickupRouteSource
                ? (widget.goingToPickup ? 1.0 : 0.25)
                : (widget.goingToPickup ? 0.25 : 1.0),
            slot: 'top',
          ),
        );
        await map.addLayer(
          mbx.LineLayer(
            id: '$source-line',
            sourceId: source,
            lineColor: source == _pickupRouteSource ? 0xFF28C7FF : 0xFFFFC400,
            lineWidth: source == _pickupRouteSource
                ? (widget.goingToPickup ? 6.0 : 3.0)
                : (widget.goingToPickup ? 3.0 : 6.0),
            lineOpacity: source == _pickupRouteSource
                ? (widget.goingToPickup ? 1.0 : 0.45)
                : (widget.goingToPickup ? 0.45 : 1.0),
            slot: 'top',
          ),
        );
      }

      final assets = rootBundle;
      final pickupIcon = await assets.load(
        'assets/map_markers/pickup_green.png',
      );
      final destinationIcon = await assets.load(
        'assets/map_markers/destination_red.png',
      );
      if (!mounted || map != _map) return;
      await map.addImage(
        'tuktuk-driver-pickup-green-v1',
        2.0,
        mbx.StyleImage.bytes(
          pickupIcon.buffer.asUint8List(
            pickupIcon.offsetInBytes,
            pickupIcon.lengthInBytes,
          ),
        ),
      );
      await map.addImage(
        'tuktuk-driver-destination-red-v1',
        2.0,
        mbx.StyleImage.bytes(
          destinationIcon.buffer.asUint8List(
            destinationIcon.offsetInBytes,
            destinationIcon.lengthInBytes,
          ),
        ),
      );
      await map.addLayer(
        mbx.SymbolLayer(
          id: 'tuktuk-driver-v1-pickup-pin',
          sourceId: _pickupSource,
          iconImage: 'tuktuk-driver-pickup-green-v1',
          iconAnchor: mbx.IconAnchor.BOTTOM,
          iconSize: 1,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          slot: 'top',
        ),
      );
      await map.addLayer(
        mbx.SymbolLayer(
          id: 'tuktuk-driver-v1-destination-pin',
          sourceId: _destinationSource,
          iconImage: 'tuktuk-driver-destination-red-v1',
          iconAnchor: mbx.IconAnchor.BOTTOM,
          iconSize: 1,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          slot: 'top',
        ),
      );
      await map.addLayer(
        mbx.CircleLayer(
          id: 'tuktuk-driver-v1-location',
          sourceId: _driverSource,
          circleColor: 0xFF278BFF,
          circleRadius: 9,
          circleStrokeColor: 0xFFFFFFFF,
          circleStrokeWidth: 3,
          slot: 'top',
        ),
      );
      if (!mounted || map != _map) return;
      setState(() {
        _ready = true;
        _message = null;
      });
      await _refresh();
    } catch (_) {
      if (mounted && map == _map) {
        setState(() => _message = 'No pudimos dibujar el mapa vectorial.');
      }
    }
  }

  Future<void> _refresh() async {
    final map = _map;
    if (!_ready || map == null) return;
    try {
      final sources = <String, String>{
        _pickupSource: marketplaceDriverPointGeoJson(widget.pickup),
        _destinationSource: marketplaceDriverPointGeoJson(widget.destination),
        _driverSource: marketplaceDriverPointGeoJson(widget.driver),
        _pickupRouteSource: marketplaceDriverLineGeoJson(
          widget.toPickup?.points ?? const [],
        ),
        _destinationRouteSource: marketplaceDriverLineGeoJson(
          widget.toDestination?.points ?? const [],
        ),
      };
      for (final item in sources.entries) {
        final s = await map.getSource(item.key);
        if (s is! mbx.GeoJsonSource) return;
        await s.updateGeoJSON(item.value);
      }
      // Una sola instancia de mapa: actualizar tambiÃ©n el tramo destacado.
      for (final source in [_pickupRouteSource, _destinationRouteSource]) {
        final highlighted =
            (source == _pickupRouteSource) == widget.goingToPickup;
        await map.setStyleLayerProperty(
          '$source-outline',
          'line-opacity',
          highlighted ? 1.0 : 0.25,
        );
        await map.setStyleLayerProperty(
          '$source-line',
          'line-opacity',
          highlighted ? 1.0 : 0.45,
        );
        await map.setStyleLayerProperty(
          '$source-line',
          'line-width',
          highlighted ? 6.0 : 3.0,
        );
      }
      final pickup = widget.pickup;
      final destination = widget.destination;
      final center = pickup != null && destination != null
          ? marketplaceDriverMapCenter(
              pickup: pickup,
              destination: destination,
              driver: widget.driver,
              activeRoute: _activeRoute)
          : widget.idleCenter;
      final zoom = pickup != null && destination != null
          ? marketplaceDriverMapZoom(
              pickup: pickup,
              destination: destination,
              driver: widget.driver,
              activeRoute: _activeRoute)
          : widget.idleZoom;
      await map.setCamera(mbx.CameraOptions(
        center: mbx.Point(
            coordinates: mbx.Position(center.longitude, center.latitude)),
        zoom: zoom,
      ));
    } catch (_) {
      if (mounted && map == _map) {
        setState(() => _message = 'No pudimos actualizar la ruta.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickup = widget.pickup;
    final destination = widget.destination;
    final center = pickup != null && destination != null
        ? marketplaceDriverMapCenter(
            pickup: pickup,
            destination: destination,
            driver: widget.driver,
            activeRoute: _activeRoute)
        : widget.idleCenter;
    final zoom = pickup != null && destination != null
        ? marketplaceDriverMapZoom(
            pickup: pickup,
            destination: destination,
            driver: widget.driver,
            activeRoute: _activeRoute)
        : widget.idleZoom;
    return Stack(
      fit: StackFit.expand,
      children: [
        mbx.MapWidget(
          styleUri: 'mapbox://styles/${widget.stylePath}',
          viewport: mbx.CameraViewportState(
            center: mbx.Point(
              coordinates: mbx.Position(center.longitude, center.latitude),
            ),
            zoom: zoom,
            bearing: 0,
            pitch: 0,
          ),
          onMapCreated: (map) {
            _map = map;
            if (widget.fullBleed) {
              // El mapa permanece bajo la navegación; los elementos legales de
              // Mapbox se sitúan POR ENCIMA de la barra, sin duplicarlos ni ocultarlos.
              final bottomMargin =
                  max(MediaQuery.paddingOf(context).bottom, 104.0) + 8;
              unawaited(map.logo.updateSettings(mbx.LogoSettings(
                marginLeft: 12,
                marginBottom: bottomMargin,
              )));
              unawaited(map.attribution.updateSettings(mbx.AttributionSettings(
                marginRight: 12,
                marginBottom: bottomMargin,
              )));
            }
            unawaited(
              map.scaleBar.updateSettings(mbx.ScaleBarSettings(enabled: false)),
            );
          },
          onStyleLoadedListener: (_) => unawaited(_onStyleLoaded()),
          onMapLoadErrorListener: (_) {
            if (mounted) {
              setState(() => _message = 'El mapa no pudo cargar.');
            }
          },
        ),
        if (_message != null)
          Positioned(
            bottom: 8,
            left: 10,
            right: 10,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xE5222732),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Text(_message!, textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
