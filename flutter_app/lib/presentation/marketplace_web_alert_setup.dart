part of '../main.dart';

/// Guides the driver back to a working browser notification configuration.
/// The browser cannot directly change Android system volume or site settings.
class MarketplaceWebAlertSetupDialog extends StatefulWidget {
  const MarketplaceWebAlertSetupDialog({
    required this.initialStatus,
    required this.recheck,
    required this.playSound,
    super.key,
  });

  final MarketplaceWebAlertReadiness initialStatus;
  final Future<MarketplaceWebAlertReadiness> Function() recheck;
  final VoidCallback playSound;

  @override
  State<MarketplaceWebAlertSetupDialog> createState() =>
      _MarketplaceWebAlertSetupDialogState();
}

class _MarketplaceWebAlertSetupDialogState
    extends State<MarketplaceWebAlertSetupDialog> {
  late MarketplaceWebAlertReadiness _status;
  bool _checking = false;
  String? _retryFeedback;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
  }

  String get _problem => switch (_status) {
    MarketplaceWebAlertReadiness.notificationsBlocked =>
      'Las notificaciones de este sitio estan bloqueadas.',
    MarketplaceWebAlertReadiness.tokenUnavailable =>
      'El navegador no pudo activar las notificaciones push.',
    MarketplaceWebAlertReadiness.registrationFailed =>
      'No se pudo registrar este dispositivo en TUKTUK.',
    MarketplaceWebAlertReadiness.ready => 'Alertas verificadas.',
  };

  String get _instructions => switch (_status) {
    MarketplaceWebAlertReadiness.notificationsBlocked =>
      '1. Si usas Chrome en Samsung, abre Ajustes del telefono > Aplicaciones > Chrome > Notificaciones y activa Permitir. '
          'Si instalaste la webapp, revisa tambien TukTuk Conductor en esa lista.\n\n'
          '2. En Chrome, abre Configuracion > Configuracion de sitios > Notificaciones, busca www.vrixora.com y selecciona Permitir.\n\n'
          '3. Regresa aqui y pulsa Comprobar de nuevo.',
    MarketplaceWebAlertReadiness.tokenUnavailable =>
      'Comprueba que tienes Internet, que el navegador es compatible y que las notificaciones del sitio estan autorizadas. '
          'Vuelve a esta pantalla y pulsa Comprobar de nuevo.',
    MarketplaceWebAlertReadiness.registrationFailed =>
      'El permiso existe, pero el servidor no confirmo el registro. '
          'Comprueba tu conexion e inicia sesion nuevamente si fuera necesario. '
          'Despues pulsa Comprobar de nuevo.',
    MarketplaceWebAlertReadiness.ready => 'Ya puedes activar Trabajar.',
  };

  Future<void> _recheck() async {
    if (_checking) return;
    setState(() => _checking = true);
    MarketplaceWebAlertReadiness next;
    try {
      next = await widget.recheck();
    } catch (_) {
      next = MarketplaceWebAlertReadiness.registrationFailed;
    }
    if (!mounted) return;
    if (next == MarketplaceWebAlertReadiness.ready) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _status = next;
      _checking = false;
      _retryFeedback = switch (next) {
        MarketplaceWebAlertReadiness.notificationsBlocked =>
          'Las notificaciones siguen bloqueadas. Abre los ajustes de Chrome, permite www.vrixora.com y comprueba otra vez.',
        MarketplaceWebAlertReadiness.tokenUnavailable =>
          'No se obtuvo el token de notificaciones. Comprueba la conexion y vuelve a intentar.',
        MarketplaceWebAlertReadiness.registrationFailed =>
          'No se confirmo el registro del dispositivo. Comprueba Internet e intenta de nuevo.',
        MarketplaceWebAlertReadiness.ready => null,
      };
    });
  }

  Widget _statusRow({
    required IconData icon,
    required String label,
    required String value,
    required bool verified,
  }) {
    final color = verified ? const Color(0xFF43E4BB) : const Color(0xFFFFC47B);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(value, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationsOk =
        _status != MarketplaceWebAlertReadiness.notificationsBlocked;
    final registrationOk = _status == MarketplaceWebAlertReadiness.ready;
    return AlertDialog(
      title: const Text('Prepara las alertas de trabajo'),
      content: SizedBox(
        width: 350,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Para estar disponible debes poder recibir avisos de nuevas carreras.',
              ),
              const SizedBox(height: 16),
              _statusRow(
                icon: Icons.notifications_active_outlined,
                label: 'Permiso de notificaciones',
                value: notificationsOk ? 'Permitido' : 'Bloqueado',
                verified: notificationsOk,
              ),
              _statusRow(
                icon: Icons.cloud_done_outlined,
                label: 'Registro del dispositivo',
                value: registrationOk ? 'Verificado' : 'Pendiente',
                verified: registrationOk,
              ),
              const Divider(),
              Text(
                _problem,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_instructions),
              if (_status == MarketplaceWebAlertReadiness.notificationsBlocked)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Importante: la webapp no puede abrir ni conceder un permiso ya bloqueado por Chrome. Debes autorizarlo en los ajustes y regresar.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 14),
              const Text(
                'Sonido del telefono: comprueba que no esta en silencio, '
                'que No molestar este desactivado y que el volumen de '
                'Notificaciones sea audible. La webapp no puede comprobar '
                'estos ajustes de Android automaticamente.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: widget.playSound,
                icon: const Icon(Icons.volume_up_outlined),
                label: const Text('Probar sonido'),
              ),
              const SizedBox(height: 6),
              const Text(
                'Esta prueba reproduce audio con la webapp abierta. '
                'No garantiza avisos audibles con el telefono bloqueado.',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (_retryFeedback != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _retryFeedback!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFFFFC47B)),
            ),
          ),
        TextButton(
          onPressed: _checking ? null : () => Navigator.of(context).pop(false),
          child: const Text('Seguir descansando'),
        ),
        FilledButton(
          onPressed: _checking ? null : () => unawaited(_recheck()),
          child: _checking
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Comprobar de nuevo'),
        ),
      ],
    );
  }
}
