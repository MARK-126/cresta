import 'package:flutter/material.dart';

import 'recording_panel.dart' show recordColor;
import 'theme.dart';

/// Barra flotante de abajo al explorar: Capas, Grabar (al centro, grande) y Ruta. Reemplaza
/// al panel fijo: el mapa queda a pantalla completa y las acciones, al alcance del pulgar.
class MapDock extends StatelessWidget {
  const MapDock({
    super.key,
    required this.onLayers,
    this.onRecord,
    this.onRoute,
    this.routeLabel = 'Ruta',
  });
  final VoidCallback onLayers;

  /// Null: no se ofrece (p. ej. comparando rutas).
  final VoidCallback? onRecord;
  final VoidCallback? onRoute;
  final String routeLabel;

  @override
  Widget build(BuildContext context) {
    return Glass(
      opacity: .94,
      radius: 22,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            Expanded(
              child: _DockItem(
                icon: Icons.layers_outlined,
                label: 'Capas',
                onTap: onLayers,
              ),
            ),
            if (onRecord != null)
              Tooltip(
                message: 'Grabar recorrido',
                child: Material(
                  color: recordColor,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onRecord,
                    child: const SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(
                        Icons.fiber_manual_record_rounded,
                        color: Andes.onTerracotta,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: onRoute == null
                  ? const SizedBox.shrink()
                  : _DockItem(
                      icon: Icons.route_rounded,
                      label: routeLabel,
                      color: Andes.gold,
                      onTap: onRoute!,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: SizedBox(
      height: 64,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color ?? Andes.onSurface),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color ?? Andes.onSurface,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Tarjeta de "vistazo" sobre el mapa (la ruta, protección civil, rutas comparadas): una
/// línea con lo esencial; tocarla abre el detalle.
class PeekCard extends StatelessWidget {
  const PeekCard({
    super.key,
    required this.title,
    required this.detail,
    this.icon,
    this.iconColor,
    this.leading,
    this.onTap,
  });
  final String title;
  final String detail;
  final IconData? icon;
  final Color? iconColor;

  /// En lugar del ícono (p. ej. la leyenda de colores al comparar).
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Glass(
      opacity: .94,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                if (leading != null)
                  leading!
                else if (icon != null)
                  Icon(icon, color: iconColor ?? Andes.cyan, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: dataStyle(context, size: 12.5, color: muted),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.expand_less_rounded, color: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hoja inferior para el detalle (capas, ruta, grabación…): se abre a pedido y se cierra
/// deslizando hacia abajo o tocando el mapa.
Future<void> showMapSheet(
  BuildContext context, {
  required Widget Function(BuildContext context, StateSetter setSheet) builder,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  // Sin oscurecer el mapa: se sigue viendo lo que cambia (capas, ruta)
  barrierColor: Colors.black.withValues(alpha: .15),
  builder: (sheet) => StatefulBuilder(
    builder: (context, setSheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: builder(context, setSheet),
        ),
      ),
    ),
  ),
);
