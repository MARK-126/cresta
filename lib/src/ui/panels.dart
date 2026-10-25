import 'package:flutter/material.dart';

import '../data/civil_data.dart';
import '../data/trail_route.dart';
import '../group/group_simulator.dart';
import '../map/map_layers.dart';
import 'elevation_profile.dart';
import 'format.dart';
import 'theme.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Row(
      children: [
        Expanded(child: Text(text.toUpperCase(), style: labelStyle(context))),
        ?trailing,
      ],
    ),
  );
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          letterSpacing: .6,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Montaña

class RouteCard extends StatelessWidget {
  const RouteCard({
    super.key,
    required this.route,
    required this.cursorMeters,
    required this.flying,
    required this.onScrub,
    required this.onScrubEnd,
    required this.onFly,
    required this.onFit,
  });

  final TrailRoute route;
  final double? cursorMeters;
  final bool flying;
  final ValueChanged<double> onScrub;
  final VoidCallback onScrubEnd;
  final VoidCallback onFly;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final cursor = cursorMeters == null ? null : route.along(cursorMeters!);
    final slope = cursorMeters == null
        ? 0
        : route.slopeAt(cursorMeters!).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Ruta seleccionada', trailing: Tag('OSM')),
        Text(route.name, style: signage(context, size: 22)),
        const SizedBox(height: 2),
        Text(route.summary, style: TextStyle(color: muted, fontSize: 12.5)),
        const SizedBox(height: 12),
        Row(
          children: [
            _Stat(fmtKm(route.totalMeters), 'km'),
            _Stat(fmtInt(route.gain), 'desnivel +'),
            _Stat(fmtInt(route.maxElevation), 'máx. m'),
            _Stat(fmtDuration(route.estimatedTime), 'estimado'),
          ],
        ),
        const SizedBox(height: 10),
        ElevationProfile(
          route: route,
          cursorMeters: cursorMeters,
          onScrub: onScrub,
          onScrubEnd: onScrubEnd,
        ),
        const SizedBox(height: 4),
        Text(
          cursor == null
              ? 'Desliza el dedo por el perfil para ubicarte en el mapa.'
              : 'km ${fmtKm(cursor.meters, decimals: 2)} · ${fmtInt(cursor.elevation)} m · pendiente ${slope > 0 ? '+' : ''}$slope %',
          style: dataStyle(context, size: 12, color: muted),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: onFly,
              icon: Icon(
                flying ? Icons.stop_rounded : Icons.flight_takeoff_rounded,
                size: 18,
              ),
              label: Text(flying ? 'Detener recorrido' : 'Recorrer en 3D'),
            ),
            OutlinedButton(
              onPressed: onFit,
              child: const Text('Ver ruta completa'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: dataStyle(context, size: 15)),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            letterSpacing: .6,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class GroupList extends StatelessWidget {
  const GroupList({
    super.key,
    required this.route,
    required this.members,
    required this.onTap,
  });

  final TrailRoute route;
  final List<GroupMember> members;
  final ValueChanged<GroupMember> onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      children: [
        SectionTitle(
          'Mi grupo',
          trailing: Text(
            'en vivo · simulado',
            style: dataStyle(context, size: 11, color: muted),
          ),
        ),
        for (final m in members)
          Builder(
            builder: (context) {
              final p = route.along(m.meters);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                onTap: () => onTap(m),
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: m.color,
                  child: Text(
                    m.initials,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                title: Text(m.name),
                subtitle: Text(
                  '${fmtKm(m.meters)} de ${fmtKm(route.totalMeters)} km · faltan ${fmtInt(route.endElevation - p.elevation)} m',
                ),
                trailing: Text(
                  '${fmtInt(p.elevation)} m\nhace ${m.secondsSinceUpdate} s',
                  textAlign: TextAlign.right,
                  style: dataStyle(context, size: 11.5, color: muted),
                ),
              );
            },
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Protección civil

class VolcanoAlertCard extends StatelessWidget {
  const VolcanoAlertCard({super.key, required this.civil});
  final CivilData civil;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget light(Color c, bool on) => Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? c : c.withValues(alpha: .25),
        boxShadow: on ? [BoxShadow(color: c, blurRadius: 8)] : null,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Semáforo volcánico', trailing: Tag('ejemplo')),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1F20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    light(const Color(0xFF2FBF5B), false),
                    light(const Color(0xFFF5C518), true),
                    light(const Color(0xFFE5352B), false),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(civil.alertLabel, style: signage(context, size: 19)),
                    Text(
                      '${civil.volcanoName}. Dato de demostración: consulta siempre a CENAPRED.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ShelterList extends StatelessWidget {
  const ShelterList({super.key, required this.civil, required this.onTap});
  final CivilData civil;
  final ValueChanged<Shelter> onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      children: [
        SectionTitle(
          'Albergues',
          trailing: Text(
            '${fmtInt(civil.freeSpots)} lugares libres',
            style: dataStyle(context, size: 11, color: muted),
          ),
        ),
        for (final s in civil.shelters)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            onTap: () => onTap(s),
            leading: Icon(
              Icons.circle,
              size: 12,
              color: s.occupancy > .8
                  ? const Color(0xFFE5352B)
                  : s.occupancy > .5
                  ? const Color(0xFFF5C518)
                  : const Color(0xFF22C06A),
            ),
            title: Text(s.name),
            subtitle: Text(s.place),
            trailing: Text(
              '${fmtInt(s.free)} libres\n${(s.occupancy * 100).round()} % ocupado',
              textAlign: TextAlign.right,
              style: dataStyle(context, size: 11.5, color: muted),
            ),
          ),
      ],
    );
  }
}

class ReportList extends StatelessWidget {
  const ReportList({
    super.key,
    required this.civil,
    required this.onTap,
    required this.onSimulateAlert,
  });
  final CivilData civil;
  final ValueChanged<CitizenReport> onTap;
  final VoidCallback onSimulateAlert;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Reportes ciudadanos',
          trailing: Text(
            'últimas 6 h',
            style: dataStyle(context, size: 11, color: muted),
          ),
        ),
        for (final r in civil.reports)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            onTap: () => onTap(r),
            leading: Transform.rotate(
              angle: .785,
              child: Container(
                width: 10,
                height: 10,
                color: hexColor(r.colorHex),
              ),
            ),
            title: Text(r.type),
            subtitle: Text(r.by),
            trailing: Text(
              fmtAgo(r.minutesAgo),
              style: dataStyle(context, size: 11.5, color: muted),
            ),
          ),
        const SizedBox(height: 6),
        FilledButton.icon(
          onPressed: onSimulateAlert,
          icon: const Icon(Icons.campaign_rounded, size: 18),
          label: const Text('Simular alerta'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Vista y capas

class ViewControls extends StatelessWidget {
  const ViewControls({
    super.key,
    required this.base,
    required this.is3d,
    required this.exaggeration,
    required this.onBase,
    required this.on3d,
    required this.onExaggeration,
  });

  final MapBase base;
  final bool is3d;
  final double exaggeration;
  final ValueChanged<MapBase> onBase;
  final ValueChanged<bool> on3d;
  final ValueChanged<double> onExaggeration;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Vista'),
        SegmentedButton<MapBase>(
          segments: [
            for (final b in MapBase.values)
              ButtonSegment(value: b, label: Text(b.label)),
          ],
          selected: {base},
          showSelectedIcon: false,
          onSelectionChanged: (s) => onBase(s.first),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('3D')),
                ButtonSegment(value: false, label: Text('2D')),
              ],
              selected: {is3d},
              showSelectedIcon: false,
              onSelectionChanged: (s) => on3d(s.first),
            ),
            const SizedBox(width: 12),
            Text(
              'Relieve ×${exaggeration.toStringAsFixed(1)}',
              style: dataStyle(context, size: 12),
            ),
            Expanded(
              child: Slider(
                value: exaggeration,
                min: 1,
                max: 3,
                divisions: 20,
                label: '×${exaggeration.toStringAsFixed(1)}',
                onChanged: is3d ? onExaggeration : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class LayerList extends StatelessWidget {
  const LayerList({
    super.key,
    required this.layers,
    required this.states,
    required this.onChanged,
  });
  final List<MapLayer> layers;
  final Map<String, bool> states;
  final void Function(String id, bool on) onChanged;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    const groups = {
      LayerGroup.mountain: 'Montaña',
      LayerGroup.civil: 'Protección civil',
      LayerGroup.general: 'General',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Capas'),
        for (final g in groups.entries.where(
          (g) => layers.any((l) => l.group == g.key),
        )) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              g.value,
              style: dataStyle(context, size: 11, color: muted),
            ),
          ),
          for (final l in layers.where((l) => l.group == g.key))
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: states[l.id] ?? false,
              onChanged: (v) => onChanged(l.id, v ?? false),
              title: Text(l.name),
              subtitle: l.note == null ? null : Text(l.note!),
              secondary: Container(
                width: 22,
                height: 10,
                decoration: BoxDecoration(
                  color: l.color,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: Colors.black26),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

Color hexColor(String hex) =>
    Color(int.parse(hex.replaceFirst('#', ''), radix: 16) | 0xFF000000);
