part of '../main.dart';

/// Native Android: direct Settings shortcuts and observable recheck.
/// The driver must explicitly grant permissions; this screen never overrides them.
class MarketplaceAndroidAlertSetupDialog extends StatefulWidget {
  const MarketplaceAndroidAlertSetupDialog({
    required this.initialStatus,
    required this.recheck,
    required this.openSettings,
    super.key,
  });

  final AndroidDriverAlertStatus? initialStatus;
  final Future<bool> Function() recheck;
  final Future<bool> Function(String action) openSettings;

  @override
  State<MarketplaceAndroidAlertSetupDialog> createState() =>
      _MarketplaceAndroidAlertSetupDialogState();
}

class _MarketplaceAndroidAlertSetupDialogState
    extends State<MarketplaceAndroidAlertSetupDialog> with WidgetsBindingObserver {
  AndroidDriverAlertStatus? _status;
  bool _checking = false;
  String _feedback = 'Corrige el requisito y pulsa Comprobar de nuevo.';

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_checking) {
      unawaited(_refreshReadiness());
    }
  }

  Future<void> _refreshReadiness() async {
    if (_checking) return;
    setState(() => _checking = true);
    bool succeeded = false;
    try {
      succeeded = await widget.recheck();
    } catch (_) {
      succeeded = false;
    }
    if (!mounted) return;
    if (succeeded) {
      Navigator.of(context).pop(true);
      return;
    }
    final status = await AndroidDriverAlertBridge.inspect();
    if (!mounted) return;
    setState(() {
      _status = status;
      _checking = false;
      _feedback = status?.problem ??
          'No se pudo comprobar el dispositivo. Comprueba Internet e inténtalo otra vez.';
    });
  }

  Future<void> _open(String action) async {
    final opened = await widget.openSettings(action);
    if (!mounted) return;
    if (!opened) {
      setState(() => _feedback = 'Android no pudo abrir esos ajustes. Ábrelos desde Ajustes del teléfono.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return AlertDialog(
      title: const Text('Prepara las alertas para trabajar'),
      content: SizedBox(
        width: 350,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TUKTUK comprobará los avisos antes de declarar tu vehículo disponible.'),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.notifications_active_outlined,
                    color: status?.appNotifications == true ? const Color(0xFF43E4BB) : Colors.orange),
                title: const Text('Notificaciones'),
                subtitle: Text(status?.appNotifications == true ? 'Autorizadas' : 'Requieren revisión'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.campaign_outlined,
                    color: status?.channelAudible == true ? const Color(0xFF43E4BB) : Colors.orange),
                title: const Text('Canal Nuevas carreras'),
                subtitle: Text(status?.channelAudible == true ? 'Canal sonoro preparado' : 'Silenciado o sin verificar'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.volume_up_outlined,
                    color: status?.soundAudible == true ? const Color(0xFF43E4BB) : Colors.orange),
                title: const Text('Sonido del teléfono'),
                subtitle: Text(status?.soundAudible == true
                    ? 'Volumen y modo de sonido preparados'
                    : 'Comprueba volumen, silencio y No molestar'),
              ),
              const SizedBox(height: 6),
              Text(status?.problem ?? 'No fue posible leer la configuración de Android.'),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _checking ? null : () => unawaited(_open(status?.settingsAction ?? 'openAppNotifications')),
                icon: const Icon(Icons.settings_outlined),
                label: Text(status?.primaryAction ?? 'Abrir ajustes de notificaciones'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _checking ? null : () => unawaited(_open('openSoundSettings')),
                icon: const Icon(Icons.volume_up_outlined),
                label: const Text('Revisar volumen y No molestar'),
              ),
              const SizedBox(height: 12),
              Text(_feedback, style: const TextStyle(fontSize: 12, color: Color(0xFFFFC47B))),
              const SizedBox(height: 8),
              const Text('Ninguna comprobación garantiza la entrega de cada carrera. '
                  'La prueba de recepción real se hará con el Samsung bloqueado.',
                  style: TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.of(context).pop(false),
          child: const Text('Seguir descansando'),
        ),
        FilledButton(
          onPressed: _checking ? null : () => unawaited(_refreshReadiness()),
          child: _checking
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Comprobar de nuevo'),
        ),
      ],
    );
  }
}
