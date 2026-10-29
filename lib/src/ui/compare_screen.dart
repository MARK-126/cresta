import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/trail_route.dart';
import '../routes/planned_route.dart';
import '../routes/route_compare.dart';
import 'format.dart';
import 'map_screen.dart';
import 'panels.dart';
import 'theme.dart';

/// Compara de 2 a 3 rutas guardadas: cifras lado a lado, perfiles superpuestos y mapa.
class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key, this.initial = const []});

  /// Rutas que ya vienen elegidas.
  final List<String> initial;

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  late final List<String> _picked = [...widget.initial.take(maxCompared)];

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: services.routes,
      builder: (context, _) {
        final all = services.routes.all;
        // Una ruta borrada mientras tanto sale de la selección
        final picked = [
          for (final id in _picked)
            if (services.routes.byId(id) != null) services.routes.byId(id)!,
        ];
        final muted = Theme.of(context).colorScheme.onSurfaceVariant;
        return Scaffold(
          appBar: AppBar(),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Text('COMPARAR', style: labelStyle(context, color: Andes.gold)),
              const SizedBox(height: 6),
              Text('Rutas', style: signage(context, size: 32)),
              const SizedBox(height: 6),
              Text(
                all.length < 2
                    ? 'Necesitas al menos dos rutas guardadas para compararlas.'
                    : 'Elige de 2 a $maxCompared rutas para ver sus cifras y perfiles lado a lado.',
                style: TextStyle(color: muted, fontSize: 13, height: 1.35),
              ),
              if (all.length >= 2) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in all)
                      _RouteChip(
                        route: r,
                        selected: _picked.contains(r.id),
                        color: _picked.contains(r.id)
                            ? compareColor(_picked.indexOf(r.id))
                            : null,
                        enabled:
                            _picked.contains(r.id) ||
                            _picked.length < maxCompared,
                        onChanged: (on) => setState(
                          () => on ? _picked.add(r.id) : _picked.remove(r.id),
                        ),
                      ),
                  ],
                ),
              ],
              if (picked.length >= 2) ...[
                const SectionTitle('Cifras'),
                _Table(routes: picked),
                const SectionTitle('Perfiles de elevación'),
                _OverlayProfile(routes: [for (final r in picked) r.profile]),
                const SizedBox(height: 24),
                GlowButton(
                  label: 'Ver en el mapa',
                  icon: Icons.map_outlined,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => MapScreen(
                        compareRouteIds: [for (final r in picked) r.id],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RouteChip extends StatelessWidget {
  const _RouteChip({
    required this.route,
    required this.selected,
    required this.color,
    required this.enabled,
    required this.onChanged,
  });
  final PlannedRoute route;
  final bool selected;
  final Color? color;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final exp = route.expeditionId == null
        ? null
        : services.expeditions.byId(route.expeditionId!);
    return FilterChip(
      avatar: selected
          ? CircleAvatar(backgroundColor: color, radius: 6)
          : const Icon(Icons.route_rounded, size: 16),
      showCheckmark: false,
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Text(
          exp == null ? route.name : '${route.name} · ${exp.name}',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      selected: selected,
      onSelected: enabled ? onChanged : null,
    );
  }
}

/// Cifras de cada ruta en columnas; la mejor de cada fila va en cian.
class _Table extends StatelessWidget {
  const _Table({required this.routes});
  final List<PlannedRoute> routes;

  @override
  Widget build(BuildContext context) {
    final stats = [for (final r in routes) RouteStats(r.profile)];
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    TableRow row(
      String label,
      String Function(RouteStats) text, {
      CompareMetric? metric,
      bool relief = false,
    }) {
      final best = metric == null ? <int>{} : bestRoutes(metric, stats);
      return TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Text(label, style: TextStyle(color: muted, fontSize: 12.5)),
          ),
          for (var i = 0; i < stats.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Text(
                relief && !stats[i].hasRelief ? '—' : text(stats[i]),
                style: dataStyle(
                  context,
                  size: 14,
                  weight: best.contains(i) ? FontWeight.w800 : FontWeight.w500,
                  color: best.contains(i) ? Andes.cyan : null,
                ),
              ),
            ),
        ],
      );
    }

    return TonalCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Table(
        columnWidths: const {0: FixedColumnWidth(96)},
        defaultColumnWidth: const FlexColumnWidth(),
        children: [
          TableRow(
            children: [
              const SizedBox.shrink(),
              for (var i = 0; i < routes.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, right: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 3, right: 6),
                        child: CircleAvatar(
                          backgroundColor: compareColor(i),
                          radius: 5,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          routes[i].name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          row(
            'Distancia',
            (s) => '${fmtKm(s.meters)} km',
            metric: CompareMetric.distance,
          ),
          row(
            'Subida',
            (s) => '+${fmtInt(s.gain)} m',
            metric: CompareMetric.gain,
            relief: true,
          ),
          row(
            'Bajada',
            (s) => '−${fmtInt(s.loss)} m',
            metric: CompareMetric.loss,
            relief: true,
          ),
          row(
            'Pendiente máx.',
            (s) => '${s.maxSlopePct.round()} %',
            metric: CompareMetric.maxSlope,
            relief: true,
          ),
          row(
            'Altitud máx.',
            (s) => '${fmtInt(s.maxElevation)} m',
            relief: true,
          ),
          row(
            'Altitud mín.',
            (s) => '${fmtInt(s.minElevation)} m',
            relief: true,
          ),
          row('Tiempo', (s) => fmtDuration(s.time), metric: CompareMetric.time),
        ],
      ),
    );
  }
}

/// Los perfiles de elevación de todas las rutas en los mismos ejes.
class _OverlayProfile extends StatelessWidget {
  const _OverlayProfile({required this.routes});
  final List<TrailRoute> routes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final withRelief = [
      for (final r in routes)
        if (RouteStats(r).hasRelief) r,
    ];
    if (withRelief.isEmpty) {
      return Text(
        'Ninguna de estas rutas tiene relieve descargado: descarga su zona para ver los perfiles.',
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomPaint(
          size: const Size(double.infinity, 170),
          painter: _OverlayPainter(
            routes: routes,
            grid: scheme.outlineVariant,
            text: scheme.onSurfaceVariant,
          ),
        ),
        if (withRelief.length < routes.length)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Las rutas sin relieve descargado no aparecen en el perfil.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.routes,
    required this.grid,
    required this.text,
  });
  final List<TrailRoute> routes;
  final Color grid;
  final Color text;

  void _label(Canvas canvas, String s, Offset at, {bool right = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: text, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.drawRect(Rect.zero, Paint());
    tp.paint(canvas, right ? Offset(at.dx - tp.width, at.dy) : at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 42.0, top = 6.0, bottom = 18.0;
    final plot = Rect.fromLTRB(left, top, size.width, size.height - bottom);
    final shown = [
      for (var i = 0; i < routes.length; i++)
        if (RouteStats(routes[i]).hasRelief) i,
    ];
    if (shown.isEmpty) return;
    var minE = shown
        .map((i) => routes[i].minElevation)
        .reduce((a, b) => a < b ? a : b);
    var maxE = shown
        .map((i) => routes[i].maxElevation)
        .reduce((a, b) => a > b ? a : b);
    if (maxE - minE < 50) {
      minE -= 25;
      maxE += 25;
    }
    final maxD = routes
        .map((r) => r.totalMeters)
        .reduce((a, b) => a > b ? a : b);

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var k = 0; k <= 2; k++) {
      final y = plot.top + plot.height * k / 2;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _label(
        canvas,
        '${fmtInt(maxE - (maxE - minE) * k / 2)} m',
        Offset(plot.left - 4, y - 6),
        right: true,
      );
    }
    _label(canvas, '0 km', Offset(plot.left, plot.bottom + 3));
    _label(
      canvas,
      '${fmtKm(maxD)} km',
      Offset(plot.right, plot.bottom + 3),
      right: true,
    );

    for (final i in shown) {
      final r = routes[i];
      final path = Path();
      for (var j = 0; j < r.distances.length; j++) {
        final x = plot.left + r.distances[j] / maxD * plot.width;
        final y =
            plot.bottom -
            (r.elevations[j] - minE) / (maxE - minE) * plot.height;
        j == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = compareColor(i)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      old.routes != routes || old.grid != grid || old.text != text;
}
