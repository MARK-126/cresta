import 'dart:math' as math;

import '../data/trail_route.dart';
import 'map_sources.dart';
import 'offline_region.dart';
import 'tile_math.dart';

/// Margen que se añade alrededor de la ruta al descargar su mapa (≈ 2 km).
const routeZoneMargin = 0.02;

/// La zona de mapa de una ruta: la caja que envuelve su trazo, con margen.
BBox routeZone(Iterable<LngLat> line, {double margin = routeZoneMargin}) {
  var west = 180.0, south = 90.0, east = -180.0, north = -90.0;
  for (final p in line) {
    west = math.min(west, p.lng);
    east = math.max(east, p.lng);
    south = math.min(south, p.lat);
    north = math.max(north, p.lat);
  }
  return BBox(
    math.max(west - margin, -180),
    math.max(south - margin, -85),
    math.min(east + margin, 180),
    math.min(north + margin, 85),
  );
}

enum RouteMapState {
  /// Sin zona que la cubra: se puede descargar.
  none,

  /// Una zona que la cubre se está descargando, en cola o en pausa.
  inProgress,

  /// Una zona completa la cubre.
  ready,

  /// La zona pasa del límite de mosaicos por descarga.
  tooLarge,
}

/// Qué falta para usar una ruta sin conexión y cómo se descargaría.
class RouteMapPlan {
  RouteMapPlan(
    this.state,
    this.zone, {
    this.region,
    this.detail,
    this.estimate,
  });

  final RouteMapState state;
  final BBox zone;

  /// La zona que ya la cubre (lista o en curso).
  final OfflineRegion? region;

  /// Nivel de detalle con el que se descargaría ([RouteMapState.none]).
  final DetailLevel? detail;
  final RegionEstimate? estimate;
}

bool _contains(BBox outer, BBox inner) =>
    outer.west <= inner.west &&
    outer.south <= inner.south &&
    outer.east >= inner.east &&
    outer.north >= inner.north;

/// Revisa si alguna zona descargada cubre la ruta y, si no, con qué detalle cabe en una descarga
/// (detallado si no pasa del límite; si no, básico).
RouteMapPlan planRouteMap(
  Iterable<LngLat> line,
  List<OfflineRegion> regions, {
  Set<MapSource> sources = const {MapSource.dem, MapSource.sat, MapSource.topo},
}) {
  final zone = routeZone(line);
  final covering = [
    for (final r in regions)
      if (_contains(r.bbox, zone)) r,
  ];
  final done = covering.where((r) => r.isComplete).firstOrNull;
  if (done != null) {
    return RouteMapPlan(RouteMapState.ready, zone, region: done);
  }
  final pending = covering
      .where((r) => r.status != RegionStatus.failed)
      .firstOrNull;
  if (pending != null) {
    return RouteMapPlan(RouteMapState.inProgress, zone, region: pending);
  }
  for (final detail in [DetailLevel.detailed, DetailLevel.basic]) {
    final estimate = OfflineRegion.estimate(zone, detail, sources);
    if (estimate.tiles <= maxTilesPerRegion) {
      return RouteMapPlan(
        RouteMapState.none,
        zone,
        detail: detail,
        estimate: estimate,
      );
    }
  }
  return RouteMapPlan(
    RouteMapState.tooLarge,
    zone,
    estimate: OfflineRegion.estimate(zone, DetailLevel.basic, sources),
  );
}
