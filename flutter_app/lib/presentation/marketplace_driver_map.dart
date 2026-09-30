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

  String? mapToken;
  String? message;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final pickup = widget.job.originPoint;
    final destination = widget.job.destinationPoint;

    if (pickup == null || destination == null) {
      setState(() {
        loading = false;
        message = 'Este servicio no tiene coordenadas disponibles.';
      });
      return;
    }

    final maps = MarketplaceMapService(
      Supabase.instance.client,
    );

    try {
      final token = await maps.runtimePublicToken();

      if (token == null || token.isEmpty) {
        throw StateError('MAP_TOKEN_MISSING');
      }

      if (!mounted) return;

      setState(() {
        mapToken = token;
        loading = false;
      });

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
        message = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        loading = false;

        if (error.toString().contains('LOCATION_DENIED')) {
          message =
              'Activa la ubicación para mostrar tu ruta hasta el cliente.';
        } else {
          message = 'No pudimos cargar la ruta en este momento.';
        }
      });
    }
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

    final token = mapToken;

    if (token == null || token.isEmpty) {
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
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kSurfaceHigh.withValues(alpha: 0.94),
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
