import 'package:flutter/material.dart';

import '../routes/planned_route.dart';
import '../routes/route_planner.dart';
import 'elevation_profile.dart';
import 'format.dart';
import 'theme.dart';

/// Color e ícono de cada tipo de punto de interés (los mismos colores que en `map.js`).
Color poiColor(PoiKind k) => switch (k) {
  PoiKind.water => const Color(0xFF5AA9E6),
  PoiKind.camp => Andes.gold,
  PoiKind.shelter => const Color(0xFFD69A5C),
  PoiKind.summit => Andes.cyan,
  PoiKind.noReturn => Andes.terracottaContainer,
  PoiKind.danger => const Color(0xFFFF5F52),
  PoiKind.other => Andes.onSurfaceVariant,
};

IconData poiIcon(PoiKind k) => switch (k) {
  PoiKind.water => Icons.water_drop_rounded,
  PoiKind.camp => Icons.cabin_outlined,
  PoiKind.shelter => Icons.house_siding_rounded,
  PoiKind.summit => Icons.flag_rounded,
  PoiKind.noReturn => Icons.u_turn_left_rounded,
  PoiKind.danger => Icons.warning_amber_rounded,
  PoiKind.other => Icons.place_rounded,
};

/// Panel del modo planificar: instrucciones, cifras en vivo, perfil y acciones.
class PlannerPanel extends StatelessWidget {
  const PlannerPanel({
    super.key,
    required this.planner,
    required this.placingPoi,
    required this.onPlacePoi,
    required this.onSave,
    required this.onCancel,
  });

  final RoutePlanner planner;

  /// Tipo de punto de interés que se colocará con el siguiente toque (o null).
  final PoiKind? placingPoi;
  final ValueChanged<PoiKind?> onPlacePoi;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final p = planner;
    final route = p.preview;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final hint = p.waypoints.isEmpty
        ? 'Toca el mapa para marcar la salida.'
        : p.legs.isEmpty
        ? 'Toca el siguiente punto. Con el mapa cerca (zoom 13 o más) la ruta sigue los senderos.'
        : 'Sigue tocando el mapa para alargar la ruta.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PLANEANDO RUTA', style: labelStyle(context, color: Andes.gold)),
        const SizedBox(height: 4),
        Text(hint, style: TextStyle(color: muted, fontSize: 13, height: 1.35)),
        const SizedBox(height: 12),
        if (placingPoi != null)
          _Note(
            color: poiColor(placingPoi!),
            icon: poiIcon(placingPoi!),
            text: 'Toca el mapa donde está: ${placingPoi!.label}.',
            action: 'Cancelar',
            onAction: () => onPlacePoi(null),
          ),
        if (p.notice != null)
          _Note(
            color: Andes.gold,
            icon: Icons.alt_route_rounded,
            text: p.notice!,
          ),
        SizedBox(
          height: 3,
          child: p.busy ? const LinearProgressIndicator(minHeight: 3) : null,
        ),
        const SizedBox(height: 10),
        if (route != null) ...[
          TonalCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Figure(fmtKm(route.totalMeters), 'km', size: 20),
                ),
                Expanded(
                  child: Figure(
                    '+${fmtInt(route.gain)}',
                    'desnivel',
                    unit: 'm',
                    size: 20,
                  ),
                ),
                Expanded(
                  child: Figure(
                    fmtDuration(route.estimatedTime),
                    'estimado',
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          if (route.gain > 0 || route.maxElevation > 0) ...[
            const SizedBox(height: 12),
            ElevationProfile(route: route, height: 110),
          ],
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            const Icon(Icons.alt_route_rounded, size: 20, color: Andes.cyan),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Ajustar a senderos',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Switch(value: p.snapToTrails, onChanged: p.setSnap),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Action(
              icon: Icons.undo_rounded,
              label: 'Deshacer',
              onTap: p.canUndo && !p.busy ? p.undo : null,
            ),
            _Action(
              icon: Icons.add_location_alt_outlined,
              label: 'Punto de interés',
              onTap: () async {
                final kind = await _pickPoiKind(context);
                if (kind != null) onPlacePoi(kind);
              },
            ),
            _Action(
              icon: Icons.swap_vert_rounded,
              label: 'Invertir',
              onTap: p.legs.isNotEmpty && !p.busy ? p.reverse : null,
            ),
            _Action(
              icon: Icons.delete_outline_rounded,
              label: 'Borrar todo',
              onTap: p.isEmpty ? null : p.clear,
            ),
          ],
        ),
        if (p.pois.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('PUNTOS DE INTERÉS', style: labelStyle(context)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final poi in p.pois)
                InputChip(
                  avatar: Icon(
                    poiIcon(poi.kind),
                    color: poiColor(poi.kind),
                    size: 18,
                  ),
                  label: Text(poi.name),
                  onDeleted: () => p.removePoi(poi),
                ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: GlowButton(
                label: 'Guardar ruta',
                icon: Icons.check_rounded,
                onPressed: p.canSave ? onSave : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<PoiKind?> _pickPoiKind(BuildContext context) =>
      showModalBottomSheet<PoiKind>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('PUNTO DE INTERÉS', style: labelStyle(context)),
                const SizedBox(height: 4),
                Text('¿Qué hay ahí?', style: signage(context, size: 24)),
                const SizedBox(height: 12),
                for (final k in PoiKind.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(poiIcon(k), color: poiColor(k)),
                    title: Text(k.label),
                    onTap: () => Navigator.pop(context, k),
                  ),
              ],
            ),
          ),
        ),
      );
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
  );
}

class _Note extends StatelessWidget {
  const _Note({
    required this.color,
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
  });
  final Color color;
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TonalCard(
      color: color.withValues(alpha: .1),
      accent: color,
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    ),
  );
}
