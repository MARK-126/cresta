import 'package:cresta/src/data/trail_route.dart';
import 'package:cresta/src/offline/map_sources.dart';
import 'package:cresta/src/offline/offline_region.dart';
import 'package:cresta/src/offline/route_zone.dart';
import 'package:cresta/src/offline/tile_math.dart';
import 'package:flutter_test/flutter_test.dart';

OfflineRegion _region(
  BBox bbox, {
  RegionStatus status = RegionStatus.complete,
}) => OfflineRegion(
  id: 'r',
  name: 'Zona',
  bbox: bbox,
  detail: DetailLevel.detailed,
  sources: {MapSource.dem, MapSource.sat, MapSource.topo},
  status: status,
);

void main() {
  // Unos 3 km de ruta cerca del Izta
  const line = [LngLat(-98.65, 19.17), LngLat(-98.63, 19.19)];

  test('la zona de una ruta es su caja con margen', () {
    final z = routeZone(line);
    expect(z.west, closeTo(-98.65 - routeZoneMargin, 1e-9));
    expect(z.east, closeTo(-98.63 + routeZoneMargin, 1e-9));
    expect(z.south, closeTo(19.17 - routeZoneMargin, 1e-9));
    expect(z.north, closeTo(19.19 + routeZoneMargin, 1e-9));
    // Un solo punto también da una zona válida
    expect(routeZone(const [LngLat(-98.6, 19.1)]).widthKm, greaterThan(0));
  });

  test('sin zona descargada: se puede bajar con detalle y tamaño estimado', () {
    final p = planRouteMap(line, const []);
    expect(p.state, RouteMapState.none);
    expect(p.detail, DetailLevel.detailed);
    expect(p.estimate!.tiles, inInclusiveRange(1, maxTilesPerRegion));
  });

  test('una zona completa que la cubre la deja lista', () {
    final z = routeZone(line);
    final big = BBox(z.west - 0.1, z.south - 0.1, z.east + 0.1, z.north + 0.1);
    expect(planRouteMap(line, [_region(big)]).state, RouteMapState.ready);
    // Una zona que no la cubre del todo no cuenta
    final small = BBox(z.west + 0.01, z.south, z.east, z.north);
    expect(planRouteMap(line, [_region(small)]).state, RouteMapState.none);
  });

  test(
    'una zona en curso o en pausa se reporta; una fallida se puede repetir',
    () {
      final z = routeZone(line);
      expect(
        planRouteMap(line, [
          _region(z, status: RegionStatus.downloading),
        ]).state,
        RouteMapState.inProgress,
      );
      expect(
        planRouteMap(line, [_region(z, status: RegionStatus.paused)]).state,
        RouteMapState.inProgress,
      );
      expect(
        planRouteMap(line, [_region(z, status: RegionStatus.failed)]).state,
        RouteMapState.none,
      );
    },
  );

  test('una ruta enorme no cabe en una descarga', () {
    const huge = [LngLat(-103.0, 16.0), LngLat(-97.0, 22.0)];
    final p = planRouteMap(huge, const []);
    expect(p.state, RouteMapState.tooLarge);
    expect(p.estimate!.tiles, greaterThan(maxTilesPerRegion));
  });
}
