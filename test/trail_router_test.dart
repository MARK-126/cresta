import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cresta/src/data/trail_route.dart';
import 'package:cresta/src/offline/map_sources.dart';
import 'package:cresta/src/offline/tile_store.dart';
import 'package:cresta/src/routing/terrain_router.dart';
import 'package:cresta/src/routing/trail_router.dart';
import 'package:cresta/src/tracking/terrain_elevation.dart';
import 'package:flutter_test/flutter_test.dart';

double _m(LngLat a, LngLat b) {
  final dLat = (b.lat - a.lat) * 111320;
  final dLng = (b.lng - a.lng) * 111320 * math.cos(a.lat * math.pi / 180);
  return math.sqrt(dLat * dLat + dLng * dLng);
}

double _len(List<LngLat> l) {
  var s = 0.0;
  for (var i = 1; i < l.length; i++) {
    s += _m(l[i - 1], l[i]);
  }
  return s;
}

/// Distancia de [p] al vértice más cercano de [line] (la ruta real tiene puntos cada ~25 m).
double _near(LngLat p, List<LngLat> line) =>
    line.map((q) => _m(p, q)).reduce(math.min);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // decodificar PNG del relieve
  // Mosaicos topográficos del paquete del ejemplo (Izta–Popo): 78 de zoom 14 y 90 de 13
  final tiles = <(int, int, int), Uint8List>{};
  // Relieve del paquete en una carpeta temporal, como en el teléfono
  final demDir = Directory.systemTemp.createTempSync('cresta_dem');
  tearDownAll(() => demDir.deleteSync(recursive: true));
  final demStore = TileStore(demDir);
  final zip = ZipDecoder().decodeBytes(
    File('assets/packs/izta_popo.zip').readAsBytesSync(),
  );
  for (final f in zip.files) {
    final parts = f.name.split('/');
    if (!f.isFile || parts.length != 4 || parts[0] != 'topo') continue;
    tiles[(int.parse(parts[1]), int.parse(parts[2]), int.parse(parts[3]))] =
        Uint8List.fromList(f.content as List<int>);
  }
  for (final f in zip.files) {
    final parts = f.name.split('/');
    if (!f.isFile || parts.length != 4 || parts[0] != 'dem') continue;
    final file = demStore.file(
      MapSource.dem,
      int.parse(parts[1]),
      int.parse(parts[2]),
      int.parse(parts[3]),
    );
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(f.content as List<int>);
  }
  final terrain = TerrainElevation([demStore]);
  final router = TrailRouter((z, x, y) async => tiles[(z, x, y)]);

  final real = [
    for (final c
        in jsonDecode(
              File('assets/data/arista_del_sol.json').readAsStringSync(),
            )['coordinates']
            as List)
      LngLat.fromJson(c as List),
  ];

  test('Paso de Cortés → cumbre del Izta por senderos reales', () async {
    final path = await router.route(real.first, real.last);
    expect(path, isNotNull);
    final km = _len(path!) / 1000;
    // La ruta real mide 12.1 km; el experimento halló 11.8 km por otro sendero real
    expect(km, inInclusiveRange(10.5, 14));
    expect(path.first.lng, real.first.lng);
    expect(path.last.lat, real.last.lat);
    // La mitad de abajo coincide con la ruta real (la de arriba puede ir por el valle del oeste)
    final lower = path.where((p) => p.lat < 19.12).toList();
    final close = lower.where((p) => _near(p, real) < 60).length;
    expect(close / lower.length, greaterThan(0.8));
  });

  test('un tramo corto sobre el mismo sendero sigue la línea', () async {
    final a = real[40], b = real[80];
    final path = await router.route(a, b);
    expect(path, isNotNull);
    final along = _len(real.sublist(40, 81));
    expect(_len(path!), closeTo(along, along * 0.15));
  });

  test(
    'con relieve: la ruta más rápida a pie, también hasta la cumbre',
    () async {
      final withDem = TrailRouter(
        (z, x, y) async => tiles[(z, x, y)],
        dem: terrain.grid,
      );
      final path = await withDem.route(real.first, real.last);
      expect(path, isNotNull);
      expect(_len(path!) / 1000, inInclusiveRange(10.5, 14));
      expect((path.last.lng, path.last.lat), (real.last.lng, real.last.lat));
    },
  );

  test('a campo traviesa sobre el relieve real: sin pasar de 45°', () async {
    // Del collado de Paso de Cortés hacia el Popo, sin sendero: ~2 km
    const a = LngLat(-98.6447, 19.0866), b = LngLat(-98.6380, 19.0700);
    final grid = (await terrain.grid(boxAround(a, b, 800)))!;
    final path = findTerrainPath(grid, a, b);
    expect(path, isNotNull);
    expect(_len(path!), greaterThan(_m(a, b) * 0.99));
    expect(_len(path), lessThan(_m(a, b) * 1.6));
    for (var i = 1; i < path.length; i++) {
      final d = _m(path[i - 1], path[i]);
      if (d < 20) continue;
      final dh =
          grid.at(path[i].lng, path[i].lat)! -
          grid.at(path[i - 1].lng, path[i - 1].lat)!;
      expect((dh / d).abs(), lessThan(1.0), reason: 'tramo $i');
    }
    final router = TerrainRouter(terrain.grid);
    expect(await router.route(a, b), isNotNull);
  });

  test('lejos de todo sendero o sin mapas no inventa nada', () async {
    // En el Pacífico: no hay mosaicos
    expect(
      await router.route(const LngLat(-120, 10), const LngLat(-120.01, 10)),
      isNull,
    );
    // Sin mosaicos legibles: null y no falla
    final broken = TrailRouter((z, x, y) async => Uint8List.fromList([1, 2]));
    expect(await broken.route(real.first, real[30]), isNull);
  });

  test('se pueden pedir muchos mosaicos sin pasar del tope', () async {
    var asked = 0;
    final counting = TrailRouter((z, x, y) async {
      asked++;
      return null;
    });
    // ~200 km: reduce el margen y, si aún no cabe, no busca
    expect(
      await counting.route(const LngLat(-99.5, 18.5), const LngLat(-97.6, 20)),
      isNull,
    );
    expect(asked, lessThanOrEqualTo(TrailRouter.maxTiles * 2));
  });
}
