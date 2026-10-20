part of '../main.dart';

class MarketplaceDriverMap extends StatefulWidget {
  const MarketplaceDriverMap({
    this.job,
    this.showLegend = true,
    this.fullBleed = false,
    this.showIdleLocation = false,
    this.idleCenter = const LatLng(23.1136, -82.3666),
    this.idleZoom = 13.5,
    this.configuration,
    this.stylePath,
    super.key,
  });

  final MarketplaceJob? job;
  final bool showLegend;
  final bool fullBleed;
  final bool showIdleLocation;
  final LatLng idleCenter;
  final double idleZoom;
  final MarketplaceMapVisualConfiguration? configuration;
  final String? stylePath;

  @override
  State<MarketplaceDriverMap> createState() => _MarketplaceDriverMapState();
}

class _MarketplaceDriverMapState extends State<MarketplaceDriverMap> {
  MarketplaceRoutePath? toPickup;
  MarketplaceRoutePath? toDestination;
  MarketplaceMapPoint? driver;

  MarketplaceMapVisualConfiguration? mapConfiguration;
  String? message;

  bool loading = true;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    mapConfiguration = widget.configuration;
    if (widget.job != null) {
      unawaited(_load());
    } else {
      loading = false;
    }
  }

  @override
  void didUpdateWidget(covariant MarketplaceDriverMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    mapConfiguration = widget.configuration ?? mapConfiguration;
    if (oldWidget.job?.id != widget.job?.id ||
        oldWidget.job?.status != widget.job?.status ||
        oldWidget.job?.originLat != widget.job?.originLat ||
        oldWidget.job?.originLon != widget.job?.originLon ||
        oldWidget.job?.destinationLat != widget.job?.destinationLat ||
        oldWidget.job?.destinationLon != widget.job?.destinationLon) {
      if (widget.job == null) {
        ++_loadGeneration;
        setState(() {
          loading = false;
          toPickup = null;
          toDestination = null;
          driver = null;
          message = null;
        });
      } else {
        unawaited(_load());
      }
    }
  }

  Future<void> _load() async {
    final job = widget.job;
    if (job == null) return;
    final generation = ++_loadGeneration;
    final pickup = job.originPoint;
    final destination = job.destinationPoint;

    if (pickup == null || destination == null) {
      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        loading = false;
        toPickup = null;
        toDestination = null;
        driver = null;
        message = 'Este servicio no tiene coordenadas disponibles.';
      });

      return;
    }

    if (mounted) {
      setState(() {
        loading = true;
        toPickup = null;
        toDestination = null;
        driver = null;
        message = null;
      });
    }

    final maps = MarketplaceMapService(Supabase.instance.client);

    try {
      final configuration =
          mapConfiguration ?? await maps.runtimeVisualConfiguration();

      if (configuration == null || configuration.token.isEmpty) {
        throw StateError('MAP_TOKEN_MISSING');
      }

      if (!mounted || generation != _loadGeneration) return;

      mapConfiguration = configuration;
      // Solo token publico: rutas y sesiones siguen protegidas en el gateway.
      if (!configuration.token.startsWith('pk.')) {
        throw StateError('MAPBOX_PUBLIC_TOKEN_INVALID');
      }
      mbx.MapboxOptions.setAccessToken(configuration.token);

      MarketplaceRoutePath? destinationRoute;

      try {
        destinationRoute = await maps.driverRouteForJob(
          jobId: job.id,
          stage: 'destination',
        );
      } catch (_) {
        destinationRoute = null;
      }

      MarketplaceMapPoint? current;
      MarketplaceRoutePath? pickupRoute;
      String? routeMessage;

      try {
        var permission = await Geolocator.checkPermission();

        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw StateError('LOCATION_DENIED');
        }

        final position = await Geolocator.getCurrentPosition();

        current = MarketplaceMapPoint(
          label: 'Tu ubicación',
          lat: position.latitude,
          lon: position.longitude,
        );

        try {
          pickupRoute = await maps.driverRouteForJob(
            jobId: job.id,
            stage: 'pickup',
            origin: current,
          );
        } catch (_) {
          pickupRoute = null;
          routeMessage = 'No pudimos cargar el tramo hasta la recogida.';
        }
      } catch (error) {
        if (error.toString().contains('LOCATION_DENIED')) {
          routeMessage =
              'Activa la ubicación para mostrar el tramo hasta la recogida.';
        } else {
          routeMessage = 'No pudimos obtener tu ubicación actual.';
        }
      }

      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        driver = current;
        toPickup = pickupRoute;
        toDestination = destinationRoute;
        loading = false;

        if (pickupRoute == null && destinationRoute == null) {
          message = 'No pudimos cargar la ruta en este momento.';
        } else {
          message = routeMessage;
        }
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        loading = false;
        message = 'No pudimos cargar la ruta en este momento.';
      });
    }
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pickup = widget.job?.originPoint;
    final destination = widget.job?.destinationPoint;

    if (widget.job != null && (pickup == null || destination == null)) {
      return const Center(
          child: Text('Mapa no disponible para este servicio.'));
    }
    final configuration = widget.configuration ?? mapConfiguration;
    if (configuration == null || configuration.token.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final ride = widget.job;
    final goingToPickup =
        ride == null || marketplaceDriverGoingToPickup(ride.status);

    return ClipRRect(
      borderRadius:
          widget.fullBleed ? BorderRadius.zero : BorderRadius.circular(18),
      child: Stack(
        children: [
          MarketplaceDriverVectorMap(
            fullBleed: widget.fullBleed,
            pickup: pickup,
            destination: destination,
            driver: driver,
            toPickup: toPickup,
            toDestination: toDestination,
            goingToPickup: goingToPickup,
            stylePath: widget.stylePath ?? configuration.stylePath,
            idleCenter: widget.idleCenter,
            idleZoom: widget.idleZoom,
          ),
          if (widget.showIdleLocation && ride == null)
            const Center(
              child: IgnorePointer(
                child: Icon(
                  Icons.my_location_rounded,
                  color: Color(0xFF2DD4A3),
                  size: 36,
                ),
              ),
            ),
          if (widget.showLegend)
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: kSurfaceHigh.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 5,
                  children: [
                    _legendItem(const Color(0xFF28C7FF), 'Hasta recogida'),
                    _legendItem(kTertiary, 'Hasta destino'),
                  ],
                ),
              ),
            ),
          if (message != null)
            Positioned(
              left: 12,
              right: 12,
              top: ride != null ? 96 : null,
              bottom: ride == null ? 12 : null,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kSurfaceHigh.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        message!,
                        textAlign: TextAlign.left,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (ride != null)
                      IconButton(
                        tooltip: 'Reintentar cargar ruta',
                        onPressed: () => unawaited(_load()),
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
