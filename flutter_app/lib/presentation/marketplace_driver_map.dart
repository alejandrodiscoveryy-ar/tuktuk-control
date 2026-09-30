part of '../main.dart';

class MarketplaceDriverMap extends StatefulWidget {
  const MarketplaceDriverMap({
    required this.job,
    super.key,
  });

  final MarketplaceJob job;

  @override
  State<MarketplaceDriverMap> createState() =>
      _MarketplaceDriverMapState();
}

class _MarketplaceDriverMapState extends State<MarketplaceDriverMap> {
  MarketplaceRoutePath? toPickup;
  MarketplaceRoutePath? toDestination;
  MarketplaceMapPoint? driver;
  String? message;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final pickup = widget.job.originPoint;
    final destination = widget.job.destinationPoint;

    if (pickup == null || destination == null) {
      setState(
        () => message = 'Este servicio no tiene coordenadas disponibles.',
      );
      return;
    }

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

      final current = MarketplaceMapPoint(
        label: 'Tu ubicación',
        lat: position.latitude,
        lon: position.longitude,
      );

      final maps = MarketplaceMapService(Supabase.instance.client);

      final routes = await Future.wait([
        maps.driverRouteForJob(
          jobId: widget.job.id,
          stage: 'pickup',
          origin: current,
        ),
        maps.driverRouteForJob(
          jobId: widget.job.id,
          stage: 'destination',
        ),
      ]);

      if (!mounted) return;

      setState(() {
        driver = current;
        toPickup = routes[0];
        toDestination = routes[1];
      });
    } catch (_) {
      if (!mounted) return;

      setState(
        () => message = 'No pudimos cargar la ruta en este momento.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const token = MarketplaceMapService.publicToken;

    final pickup = widget.job.originPoint;
    final destination = widget.job.destinationPoint;

    if (token.isEmpty || pickup == null || destination == null) {
      return const Center(
        child: Text('Mapa no disponible para este servicio.'),
      );
    }

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
                urlTemplate:
                    'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/256/{z}/{x}/{y}?access_token=$token',
                userAgentPackageName: 'com.vrixora.tuktuk',
              ),
              PolylineLayer(
                polylines: [
                  if (toPickup != null)
                    Polyline(
                      points: toPickup!.points
                          .map((point) => point.latLng)
                          .toList(),
                      color: kTertiary,
                      strokeWidth: 5,
                    ),
                  if (toDestination != null)
                    Polyline(
                      points: toDestination!.points
                          .map((point) => point.latLng)
                          .toList(),
                      color: kPrimary,
                      strokeWidth: 4,
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
          if (message != null)
            Positioned.fill(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kSurfaceHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    message!,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}