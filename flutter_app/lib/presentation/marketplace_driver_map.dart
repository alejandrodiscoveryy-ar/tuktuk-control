part of '../main.dart';

class MarketplaceDriverMap extends StatefulWidget {
  const MarketplaceDriverMap({
    required this.job,
    super.key,
  });

  final MarketplaceJob job;

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

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant MarketplaceDriverMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.job.id != widget.job.id ||
        oldWidget.job.status != widget.job.status ||
        oldWidget.job.originLat != widget.job.originLat ||
        oldWidget.job.originLon != widget.job.originLon ||
        oldWidget.job.destinationLat != widget.job.destinationLat ||
        oldWidget.job.destinationLon != widget.job.destinationLon) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final pickup = widget.job.originPoint;
    final destination = widget.job.destinationPoint;

    if (pickup == null || destination == null) {
      if (!mounted) return;

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

    final maps = MarketplaceMapService(
      Supabase.instance.client,
    );

    try {
      final configuration =
          mapConfiguration ?? await maps.runtimeVisualConfiguration();

      if (configuration == null || configuration.token.isEmpty) {
        throw StateError('MAP_TOKEN_MISSING');
      }

      if (!mounted) return;

      mapConfiguration = configuration;

      MarketplaceRoutePath? destinationRoute;

      try {
        destinationRoute = await maps.driverRouteForJob(
          jobId: widget.job.id,
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
            jobId: widget.job.id,
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

      if (!mounted) return;

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
      if (!mounted) return;

      setState(() {
        loading = false;
        message = 'No pudimos cargar la ruta en este momento.';
      });
    }
  }

  Widget _legendItem(
    Color color,
    String text,
  ) {
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
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pickup = widget.job.originPoint;
    final destination = widget.job.destinationPoint;

    if (pickup == null || destination == null) {
      return const Center(
        child: Text('Mapa no disponible para este servicio.'),
      );
    }

    if (loading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      );
    }

    final configuration = mapConfiguration;

    if (configuration == null || configuration.token.isEmpty) {
      return const Center(
        child: Text('Mapa no disponible para este servicio.'),
      );
    }

    final goingToPickup = widget.job.status == 'accepted' ||
        widget.job.status == 'en_route' ||
        widget.job.status == 'pickup';

    final pickupColor = kTertiary.withValues(
      alpha: goingToPickup ? 1 : .35,
    );

    final destinationColor = kPrimary.withValues(
      alpha: goingToPickup ? .45 : 1,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: pickup.latLng,
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: configuration.tileUrlTemplate,
                userAgentPackageName: 'com.vrixora.tuktuk',
              ),
              PolylineLayer(
                polylines: [
                  if (toPickup != null)
                    Polyline(
                      points: toPickup!.points
                          .map((point) => point.latLng)
                          .toList(),
                      color: pickupColor,
                      strokeWidth: goingToPickup ? 6 : 3,
                    ),
                  if (toDestination != null)
                    Polyline(
                      points: toDestination!.points
                          .map((point) => point.latLng)
                          .toList(),
                      color: destinationColor,
                      strokeWidth: goingToPickup ? 3 : 6,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  if (driver != null)
                    Marker(
                      point: driver!.latLng,
                      child: const Icon(
                        Icons.navigation_rounded,
                        color: Colors.blue,
                        size: 34,
                      ),
                    ),
                  Marker(
                    point: pickup.latLng,
                    child: const Icon(
                      Icons.person_pin_circle_rounded,
                      color: kTertiary,
                      size: 40,
                    ),
                  ),
                  Marker(
                    point: destination.latLng,
                    child: const Icon(
                      Icons.location_pin,
                      color: kPrimary,
                      size: 40,
                    ),
                  ),
                ],
              ),
              marketplaceMapAttribution(pickup.latLng),
            ],
          ),
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: kSurfaceHigh.withValues(alpha: .92),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 5,
                children: [
                  _legendItem(
                    kTertiary,
                    'Hasta recogida',
                  ),
                  _legendItem(
                    kPrimary,
                    'Hasta destino',
                  ),
                ],
              ),
            ),
          ),
          if (message != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kSurfaceHigh.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
