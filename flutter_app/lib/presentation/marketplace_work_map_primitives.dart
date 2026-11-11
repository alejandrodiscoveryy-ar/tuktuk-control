part of '../main.dart';

/// Superficie de cristal comun para todas las tarjetas del mapa de Trabajo.
/// El contenido conserva su contraste y los botones mantienen sus colores.
class _WorkMapGlassPanel extends StatelessWidget {
  const _WorkMapGlassPanel({
    required this.child,
    this.margin = EdgeInsets.zero,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 13, sigmaY: 13),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xC00A2833), Color(0xD20B1925)],
              ),
              border: Border.all(color: const Color(0x804AE5D1), width: 1.1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// El marcador de la ficha utiliza el mismo recurso grafico que el mapa.
/// Su etiqueta y direccion se mantienen independientes de la cartografia.
class _WorkMapLocationRow extends StatelessWidget {
  const _WorkMapLocationRow({
    required this.pickup,
    required this.address,
    this.expanded = false,
  });

  final bool pickup;
  final String address;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final color = pickup ? const Color(0xFF58E6B3) : const Color(0xFFFF707C);
    final label = pickup ? 'Recogida' : 'Destino';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 36,
          height: 42,
          child: Image.asset(
            pickup
                ? 'assets/map_markers/pickup_green.png'
                : 'assets/map_markers/destination_red.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              pickup ? Icons.person_pin_circle_rounded : Icons.flag_rounded,
              size: 30,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                maxLines: expanded ? null : 2,
                overflow:
                    expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

