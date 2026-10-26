part of '../main.dart';

/// Pantalla breve: solo se muestra el requisito pendiente.
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
    extends State<MarketplaceAndroidAlertSetupDialog>
    with WidgetsBindingObserver {
  AndroidDriverAlertStatus? _status;
  bool _checking = false;
  String? _feedback;

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

    bool ready = false;
    try {
      ready = await widget.recheck();
    } catch (_) {
      ready = false;
    }

    if (!mounted) return;

    if (ready) {
      Navigator.of(context).pop(true);
      return;
    }

    final status = await AndroidDriverAlertBridge.inspect();
    if (!mounted) return;

    setState(() {
      _status = status;
      _checking = false;
      _feedback = status?.ready == true
          ? 'No pudimos conectar las alertas. Revisa Internet y reintenta.'
          : null;
    });
  }

  Future<void> _resolve() async {
    if (_status?.ready == true) {
      await _refreshReadiness();
      return;
    }

    final opened = await widget.openSettings(
      _status?.settingsAction ?? 'openAppNotifications',
    );

    if (!mounted) return;

    if (!opened) {
      setState(() {
        _feedback = 'Abre los ajustes de notificaciones del teléfono.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = _feedback ??
        (_status?.ready == true
            ? 'Revisa la conexión y vuelve a intentarlo.'
            : _status?.problem ??
                'Activa las notificaciones para recibir carreras.');

    return AlertDialog(
      title: const Text('Activa las alertas de carreras'),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.notifications_active_outlined,
            color: Colors.orange,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.of(context).pop(false),
          child: const Text('Ahora no'),
        ),
        FilledButton.icon(
          onPressed: _checking ? null : () => unawaited(_resolve()),
          icon: _checking
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.settings_outlined),
          label: Text(
            _checking
                ? 'Comprobando'
                : _status?.ready == true
                    ? 'Reintentar'
                    : 'Abrir ajustes',
          ),
        ),
      ],
    );
  }
}
