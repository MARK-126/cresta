import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cresta/src/data/trail_route.dart';
import 'package:cresta/src/routing/trail_router.dart';
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
  // Mosaicos topográficos del paquete del ejemplo (Izta–Popo): 78 de zoom 14 y 90 de 13
  final tiles = <(int, int, int), Uint8List>{};
  final zip = ZipDecoder().decodeBytes(
    File('assets/packs/izta_popo.zip').readAsBytesSync(),
  );
  for (final f in zip.files) {
    final parts = f.name.split('/');
    if (!f.isFile || parts.length != 4 || parts[0] != 'topo') continue;
    tiles[(int.parse(parts[1]), int.parse(parts[2]), int.parse(parts[3]))] =
        Uint8List.fromList(f.content as List<int>);
  }
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
