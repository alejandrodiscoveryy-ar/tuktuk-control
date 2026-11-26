part of '../main.dart';

/// Da prioridad al nombre verificado del perfil operativo frente a Google.
@visibleForTesting
String marketplaceDriverHeaderName({
  String? registeredName,
  String? googleName,
}) {
  for (final value in [registeredName, googleName]) {
    final name = value?.trim();
    if (name != null && name.isNotEmpty) return name;
  }
  return 'Conductor sin nombre';
}

@visibleForTesting
String marketplaceDriverLocationPermissionLabel(
  LocationPermission? permission,
) => switch (permission) {
  LocationPermission.always => 'Permitida',
  LocationPermission.whileInUse => 'Permitida mientras usas la app',
  LocationPermission.denied => 'No permitida',
  LocationPermission.deniedForever => 'Bloqueada en ajustes',
  LocationPermission.unableToDetermine || null => 'No se pudo comprobar',
};

@visibleForTesting
String marketplaceDriverNotificationPermissionLabel(
  AuthorizationStatus? status,
) => switch (status) {
  AuthorizationStatus.authorized => 'Permitidas',
  AuthorizationStatus.provisional => 'Permiso provisional',
  AuthorizationStatus.denied => 'No permitidas',
  AuthorizationStatus.notDetermined => 'Sin configurar',
  null => 'No se pudo comprobar',
};

class MarketplaceDriverPermissionsScreen extends StatefulWidget {
  const MarketplaceDriverPermissionsScreen({super.key});

  @override
  State<MarketplaceDriverPermissionsScreen> createState() =>
      _MarketplaceDriverPermissionsScreenState();
}

class _MarketplaceDriverPermissionsScreenState
    extends State<MarketplaceDriverPermissionsScreen>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool? _gpsEnabled;
  LocationPermission? _locationPermission;
  AuthorizationStatus? _notifications;
  AndroidDriverAlertStatus? _androidAlerts;
  String? _installedVersionLabel;
  bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshPermissions());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshPermissions());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refreshPermissions() async {
    if (!mounted) return;
    setState(() => _checking = true);
    AndroidDriverAlertStatus? androidAlerts;
    String? installedVersionLabel;
    bool? gpsEnabled;
    LocationPermission? location;
    AuthorizationStatus? notifications;
    try {
      gpsEnabled = await Geolocator.isLocationServiceEnabled()
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // La plataforma puede no exponer el interruptor GPS.
    }
    try {
      location = await Geolocator.checkPermission()
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Se mantiene el estado indeterminado; no afirmar que está concedido.
    }
    try {
      notifications =
          (await FirebaseMessaging.instance.getNotificationSettings()
              .timeout(const Duration(seconds: 5)))
              .authorizationStatus;
    } catch (_) {
      // En navegadores sin mensajería no bloquea otros permisos.
    }
    if (_android) {
      try {
        androidAlerts = await AndroidDriverAlertBridge.inspect()
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // The installed native build may not support all diagnostics.
      }
      try {
        final version = await _appUpdateNativeChannel
            .invokeMapMethod<String, dynamic>('getInstalledVersion')
            .timeout(const Duration(seconds: 5));
        if (version != null && version['name'] is String && version['build'] is num) {
          installedVersionLabel = '${version['name']} · build ${version['build']}';
        }
      } catch (_) {
        // Version unknown; never substitute the repository's version.
      }
    }
    if (!mounted) return;
    setState(() {
      _androidAlerts = androidAlerts;
      _installedVersionLabel = installedVersionLabel;
      _gpsEnabled = gpsEnabled;
      _locationPermission = location;
      _notifications = notifications;
      _checking = false;
    });
  }

  Future<void> _requestLocation() async {
    try {
      if (_locationPermission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
      } else {
        await Geolocator.requestPermission();
      }
    } catch (_) {
      if (mounted) {
        toast(
          context,
          'Abre los ajustes del teléfono para autorizar la ubicación.',
        );
      }
    }
    await _refreshPermissions();
  }

  Future<void> _enableGps() async {
    try {
      final opened = await Geolocator.openLocationSettings();
      if (!opened && mounted) {
        toast(context, 'Activa el GPS desde los ajustes del teléfono.');
      }
    } catch (_) {
      if (mounted) {
        toast(context, 'Activa el GPS desde los ajustes del teléfono.');
      }
    }
    await _refreshPermissions();
  }

  Future<void> _openApplicationSettings() async {
    try {
      final opened = await Geolocator.openAppSettings();
      if (!opened && mounted) {
        toast(context, 'Abre los ajustes de TUKTUK en tu dispositivo.');
      }
    } catch (_) {
      if (mounted) {
        toast(context, 'Abre los ajustes de TUKTUK en tu dispositivo.');
      }
    }
    await _refreshPermissions();
  }

  Future<void> _requestNotifications() async {
    try {
      if (_notifications == AuthorizationStatus.denied) {
        await Geolocator.openAppSettings();
      } else {
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (_) {
      if (mounted) {
        toast(
          context,
          'Revisa el permiso de notificaciones en los ajustes del teléfono.',
        );
      }
    }
    await _refreshPermissions();
  }

  Widget _permissionItem({
    required IconData icon,
    required String title,
    required String description,
    required String status,
    required bool enabled,
    required VoidCallback onEnable,
    required Key key,
  }) => GlassCard(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: enabled ? kPrimary : kTertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(description),
                const SizedBox(height: 5),
                Text(
                  status,
                  style: TextStyle(
                    color: enabled ? kPrimary : kMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          enabled
              ? const Icon(Icons.check_circle, color: kPrimary)
              : IconButton(
                  tooltip: 'Revisar $title',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: _checking ? null : onEnable,
                ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final locationOk =
        _locationPermission == LocationPermission.always ||
        _locationPermission == LocationPermission.whileInUse;
    final notificationsOk = _notifications == AuthorizationStatus.authorized;
    final alerts = _androidAlerts;
    final batterySaver = alerts?.batterySaver;
    final batteryOptimizationIgnored = alerts?.batteryOptimizationIgnored;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Permisos para trabajar',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Consulta el estado real de tu teléfono y habilita lo necesario para usar Trabajo.',
        ),
        const SizedBox(height: 16),
        _permissionItem(
          key: const ValueKey('driver-permission-gps'),
          icon: Icons.gps_fixed_rounded,
          title: 'GPS del teléfono',
          description: 'Permite localizarte y situarte en el mapa.',
          status: _gpsEnabled == null
              ? 'No se pudo comprobar'
              : _gpsEnabled!
              ? 'Activado'
              : 'Desactivado',
          enabled: _gpsEnabled == true,
          onEnable: () => unawaited(_enableGps()),
        ),
        const SizedBox(height: 12),
        _permissionItem(
          key: const ValueKey('driver-permission-location'),
          icon: Icons.location_on_outlined,
          title: 'Acceso a la ubicación',
          description: 'Necesario para obtener tu ubicación mientras trabajas.',
          status: marketplaceDriverLocationPermissionLabel(_locationPermission),
          enabled: locationOk,
          onEnable: () => unawaited(_requestLocation()),
        ),
        const SizedBox(height: 12),
        _permissionItem(
          key: const ValueKey('driver-permission-notifications'),
          icon: Icons.notifications_active_outlined,
          title: 'Notificaciones',
          description: 'Ayudan a enterarte de nuevas solicitudes y novedades.',
          status: marketplaceDriverNotificationPermissionLabel(_notifications),
          enabled: notificationsOk,
          onEnable: () => unawaited(_requestNotifications()),
        ),
        if (_android) ...[
          const SizedBox(height: 12),
          _permissionItem(
            key: const ValueKey('driver-permission-native-sound'),
            icon: Icons.volume_up_outlined,
            title: 'Sonido de nuevas carreras',
            description: 'Canal de carreras, volumen y No molestar.',
            status: alerts?.problem ?? 'No se pudo comprobar',
            enabled: alerts?.ready == true,
            onEnable: () => unawaited(AndroidDriverAlertBridge
                .openSettings(alerts?.settingsAction ?? 'openAppNotifications')
                .then((_) => _refreshPermissions())),
          ),
          if (_installedVersionLabel != null) ...[
            const SizedBox(height: 12),
            Text('APK instalada: $_installedVersionLabel',
                style: TextStyle(color: appMutedColor(context), fontSize: 12)),
          ],
        ],
        const SizedBox(height: 12),
        GlassCard(
          child: ListTile(
            leading: const Icon(Icons.battery_saver_outlined, color: kPrimary),
            title: const Text(
              'Funcionamiento en segundo plano',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              (_android
                  ? 'Ahorro de batería: ${batterySaver == null ? 'sin comprobar' : batterySaver ? 'activo' : 'desactivado'}. '
                    'Optimización Android: ${batteryOptimizationIgnored == null ? 'sin comprobar' : batteryOptimizationIgnored ? 'exenta' : 'aplicada'}.\n'
                  : '') +
              'Revisa las restricciones de batería desde los ajustes del teléfono si las notificaciones llegan tarde. '
              'Esta versión no solicita acceso permanente a la ubicación: no se muestra como permiso concedido.',
            ),
            trailing: IconButton(
              tooltip: 'Abrir ajustes de la aplicación',
              onPressed: () => unawaited(_openApplicationSettings()),
              icon: const Icon(Icons.open_in_new_rounded),
            ),
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _checking ? null : () => unawaited(_refreshPermissions()),
          icon: _checking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          label: const Text('Comprobar permisos'),
        ),
      ],
    );
  }
}
