import 'package:flutter/material.dart';

import '../app_services.dart';
import '../offline/offline_region.dart';
import '../offline/route_zone.dart';
import '../routes/planned_route.dart';
import '../routes/route_ledger.dart';
import '../routes/route_profile.dart';
import '../weather/weather_service.dart' show routeWeatherKey;
import 'compare_screen.dart';
import 'elevation_profile.dart';
import 'format.dart';
import 'map_screen.dart';
import 'offline_widgets.dart';
import 'panels.dart';
import 'planner_panel.dart';
import 'route_actions.dart';
import 'route_destination.dart';
import 'theme.dart';
import 'weather_widgets.dart' show WeatherCard;

/// Detalle de la ruta de una expedición (diseño "Route Details" de Stitch): cifras,
/// perfil y la bitácora de paradas con su hora estimada desde la salida.
class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key, required this.routeId});
  final String routeId;

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  double? _cursor;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: services.routes,
      builder: (context, _) {
        final route = services.routes.byId(widget.routeId);
        if (route == null) {
          return const Scaffold(body: SizedBox.shrink()); // se acaba de borrar
        }
        final r = route.profile;
        final scheme = Theme.of(context).colorScheme;
        final muted = scheme.onSurfaceVariant;
        final loss = elevationLoss(r.elevations);
        final hasRelief = r.gain > 0 || loss > 0;
        final stops = routeLedger(route);

        return Scaffold(
          appBar: AppBar(
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) => switch (v) {
                  'rename' => _rename(route),
                  'move' => _move(route),
                  'compare' => _compare(route),
                  'delete' => _delete(),
                  _ => null,
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Cambiar nombre')),
                  PopupMenuItem(
                    value: 'compare',
                    child: Text('Comparar con otra ruta'),
                  ),
                  PopupMenuItem(
                    value: 'move',
                    child: Text('Guardar en una expedición'),
                  ),
                  PopupMenuItem(value: 'delete', child: Text('Borrar ruta')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Text(
                'RUTA · ${r.source.toUpperCase()}',
                style: labelStyle(context, color: Andes.gold),
              ),
              const SizedBox(height: 6),
              Text(route.name, style: signage(context, size: 30)),
              const SizedBox(height: 4),
              Text(
                route.expeditionId == null
                    ? 'Ruta suelta, sin expedición'
                    : 'Expedición: ${services.expeditions.byId(route.expeditionId!)?.name ?? ''}',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              if (!hasRelief) ...[
                const SizedBox(height: 6),
                Text(
                  'Sin relieve descargado para esta zona: descárgala para ver el desnivel y el tiempo real.',
                  style: TextStyle(color: Andes.gold, fontSize: 12.5),
                ),
              ],
              _SafetyNotes(
                straight: route.straightMeters,
                straightLegs: route.straightLegs,
                steep: steepStretches(r),
              ),
              const SizedBox(height: 20),
              Figure(
                fmtKm(r.totalMeters),
                'kilómetros',
                size: 56,
                labelColor: scheme.primary,
              ),
              const SizedBox(height: 18),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.3,
                children: [
                  _Tile(
                    '+${fmtInt(r.gain)}',
                    'subida',
                    unit: 'm',
                    accent: scheme.primary,
                  ),
                  _Tile('−${fmtInt(loss)}', 'bajada', unit: 'm'),
                  _Tile(
                    fmtInt(r.maxElevation),
                    'altitud máx.',
                    unit: 'm',
                    accent: Andes.gold,
                  ),
                  _Tile(fmtDuration(r.estimatedTime), 'tiempo estimado'),
                  _Tile('${maxSlope(r).round()}', 'pendiente máx.', unit: '%'),
                  _Tile(fmtInt(r.minElevation), 'altitud mín.', unit: 'm'),
                ],
              ),
              if (hasRelief) ...[
                const SectionTitle('Perfil de elevación'),
                ElevationProfile(
                  route: r,
                  cursorMeters: _cursor,
                  onScrub: (m) => setState(() => _cursor = m),
                  onScrubEnd: () {},
                ),
                Text(
                  _cursor == null
                      ? 'Desliza el dedo por el perfil.'
                      : 'km ${fmtKm(_cursor!, decimals: 2)} · ${fmtInt(r.along(_cursor!).elevation)} m · pendiente ${r.slopeAt(_cursor!).round()} %',
                  style: dataStyle(context, size: 12, color: muted),
                ),
              ],
              _OfflineSection(route: route),
              const SectionTitle('Bitácora de la ruta'),
              TonalCard(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                child: Column(
                  children: [
                    for (var i = 0; i < stops.length; i++)
                      _Stop(stop: stops[i], last: i == stops.length - 1),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Tiempos desde la salida: 4 km/h más 1 h por cada 400 m de subida, sin contar descansos.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
              const SizedBox(height: 24),
              GlowButton(
                label: 'Abrir en el mapa',
                icon: Icons.map_outlined,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => MapScreen(
                      expeditionId: route.expeditionId,
                      routeId: route.id,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => MapScreen(
                            expeditionId: route.expeditionId,
                            routeId: route.id,
                            plan: true,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.edit_road_rounded),
                      label: const Text('Editar'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Builder(
                      builder: (context) => OutlinedButton.icon(
                        onPressed: () => exportRouteGpx(context, route),
                        icon: const Icon(Icons.ios_share_rounded),
                        label: const Text('Exportar GPX'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _rename(PlannedRoute route) async {
    final services = AppScope.of(context);
    final name = await askRouteName(context, route.name);
    if (name == null) return;
    await services.routes.save(route.withName(name));
  }

  void _compare(PlannedRoute route) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => CompareScreen(initial: [route.id])),
  );

  Future<void> _move(PlannedRoute route) async {
    final services = AppScope.of(context);
    final dest = await askRouteDestination(
      context,
      current: route.expeditionId,
    );
    if (dest == null) return;
    await services.routes.save(route.linkedTo(dest.expeditionId));
  }

  Future<void> _delete() async {
    final services = AppScope.of(context);
    final navigator = Navigator.of(context);
    final ok = await confirmDialog(
      context,
      title: 'Borrar la ruta',
      body: 'Se borra la ruta. Los recorridos grabados no se tocan.',
      action: 'Borrar',
    );
    if (!ok) return;
    navigator.pop();
    await services.weather.delete(routeWeatherKey(widget.routeId));
    await services.routes.delete(widget.routeId);
  }
}

/// Lo que falta para usar la ruta sin señal: su clima y la zona de mapa.
class _OfflineSection extends StatelessWidget {
  const _OfflineSection({required this.route});
  final PlannedRoute route;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([services.maps, services.weather]),
      builder: (context, _) {
        final plan = planRouteMap(
          route.profile.coordinates,
          services.maps.regions,
        );
        final hasWeather =
            services.weather.forExpedition(routeWeatherKey(route.id)) != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle('Preparar sin conexión'),
            WeatherCard(
              expedition: routeWeatherSubject(services, route),
              route: route.profile,
            ),
            const SizedBox(height: 14),
            _MapCoverage(plan: plan, route: route),
            if (!hasWeather && plan.state == RouteMapState.none) ...[
              const SizedBox(height: 14),
              GlowButton(
                label: 'Consultar clima y descargar mapa',
                icon: Icons.cloud_download_outlined,
                onPressed: () => prepareRouteOffline(context, route),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Estado del mapa sin conexión de la ruta y cómo descargarlo.
class _MapCoverage extends StatelessWidget {
  const _MapCoverage({required this.plan, required this.route});
  final RouteMapPlan plan;
  final PlannedRoute route;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final r = plan.region;
    switch (plan.state) {
      case RouteMapState.ready:
        return Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Andes.cyan, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Mapa descargado: ${r!.name} · ${fmtBytes(r.bytes)}. La ruta funciona sin señal.',
                style: const TextStyle(fontSize: 13.5, height: 1.35),
              ),
            ),
          ],
        );
      case RouteMapState.inProgress:
        final paused = r!.status == RegionStatus.paused;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              paused
                  ? 'Descarga del mapa en pausa (${(r.progress * 100).round()} %).'
                  : 'Descargando el mapa de la ruta: ${(r.progress * 100).round()} %. Mantén la app abierta.',
              style: const TextStyle(fontSize: 13.5, height: 1.35),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: r.progress),
            if (paused) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => services.maps.resume(r.id),
                child: const Text('Reanudar descarga'),
              ),
            ],
          ],
        );
      case RouteMapState.tooLarge:
        return Text(
          'La zona de esta ruta es demasiado grande para una sola descarga (${plan.estimate!.tiles} mosaicos; el máximo es $maxTilesPerRegion). Elige zonas más pequeñas en la pestaña Mapas.',
          style: TextStyle(color: muted, fontSize: 13, height: 1.35),
        );
      case RouteMapState.none:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Mapa sin descargar. Para usar la ruta sin señal hay que bajar su zona: unos ${fmtBytes(plan.estimate!.bytes)} (${plan.estimate!.tiles} mosaicos, detalle ${plan.detail!.label.toLowerCase()}). Mejor con Wi-Fi.',
              style: TextStyle(color: muted, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => downloadRouteMap(context, route),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Descargar mapa de esta ruta'),
            ),
          ],
        );
    }
  }
}

/// Avisos de seguridad de la ruta: tramos sin sendero y tramos muy empinados.
class _SafetyNotes extends StatelessWidget {
  const _SafetyNotes({
    required this.straight,
    required this.straightLegs,
    required this.steep,
  });
  final double straight;
  final int straightLegs;
  final List<Stretch> steep;

  @override
  Widget build(BuildContext context) {
    if (straight <= 0 && steep.isEmpty) return const SizedBox.shrink();
    final steepTotal = steep.fold<double>(0, (a, t) => a + t.length);
    final steepPeak = steep.fold<double>(
      0,
      (a, t) => t.maxPct > a ? t.maxPct : a,
    );
    String plural(int n, String one, String many) => n == 1 ? one : many;
    const style = TextStyle(fontSize: 13, height: 1.4);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: TonalCard(
        accent: Andes.terracottaContainer,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Andes.terracottaContainer,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Revisa antes de salir',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
              ],
            ),
            if (straight > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Sin sendero: ${fmtKm(straight)} km ($straightLegs ${plural(straightLegs, 'tramo', 'tramos')}) van en línea recta porque no hay un sendero conocido ahí. El terreno real puede ser muy distinto; en el mapa van punteados.',
                style: style,
              ),
            ],
            if (steep.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Muy empinado: ${steep.length} ${plural(steep.length, 'tramo', 'tramos')} de más de ${steepThresholdPct.round()} % (${fmtInt(steepTotal)} m en total, hasta ${steepPeak.round()} %). Van en rojo en el perfil. El relieve descargado suaviza: en la realidad pueden ser peores.',
                style: style,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.value, this.label, {this.unit, this.accent});
  final String value;
  final String label;
  final String? unit;
  final Color? accent;

  @override
  Widget build(BuildContext context) => TonalCard(
    accent: accent,
    padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Figure(value, label, unit: unit, size: 20),
    ),
  );
}

/// Una parada de la bitácora, con su punto y la línea que la une con la siguiente.
class _Stop extends StatelessWidget {
  const _Stop({required this.stop, required this.last});
  final LedgerStop stop;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final poi = stop.poi;
    final color = poi == null
        ? (stop.meters == 0 ? Andes.cyan : Andes.terracottaContainer)
        : poiColor(poi.kind);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: .16),
                  ),
                  child: Icon(
                    poi == null
                        ? (stop.meters == 0
                              ? Icons.trip_origin_rounded
                              : Icons.sports_score_rounded)
                        : poiIcon(poi.kind),
                    size: 15,
                    color: color,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: Andes.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'km ${fmtKm(stop.meters)} · ${fmtInt(stop.elevation)} m'
                    '${stop.offRoute > 150 ? ' · a ${fmtInt(stop.offRoute)} m de la ruta' : ''}',
                    style: dataStyle(
                      context,
                      size: 12,
                      color: muted,
                      weight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              stop.meters == 0 ? '0:00' : '+${fmtDuration(stop.eta)}',
              style: dataStyle(
                context,
                size: 13,
                weight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
