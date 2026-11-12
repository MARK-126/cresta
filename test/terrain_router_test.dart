import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cresta/src/data/trail_route.dart';
import 'package:cresta/src/routing/dem_grid.dart';
import 'package:cresta/src/routing/terrain_router.dart';
import 'package:flutter_test/flutter_test.dart';

/// Relieve sintético de 120 × 120 píxeles de zoom 12 cerca del Izta (~36 m por píxel).
DemGrid _grid(double Function(int c, int r) ele) {
  const w = 120, h = 120;
  final e = Float32List(w * h);
  for (var r = 0; r < h; r++) {
    for (var c = 0; c < w; c++) {
      e[r * w + c] = ele(c, r);
    }
  }
  return DemGrid(zoom: 12, x0: 236900, y0: 467300, width: w, height: h, ele: e);
}

LngLat _at(DemGrid g, double c, double r) {
  final (lng, lat) = g.toLngLat(c, r);
  return LngLat(lng, lat);
}

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

void main() {
  test('Tobler: más rápido bajando suave, lento en lo empinado', () {
    expect(toblerKmh(-0.05), closeTo(6, 1e-9));
    expect(toblerKmh(0), closeTo(5.04, .01));
    expect(toblerKmh(0.3), lessThan(2.5));
    expect(toblerKmh(-0.3), greaterThan(toblerKmh(0.3)));
  });

  test('la cuadrícula convierte ida y vuelta entre píxel y coordenadas', () {
    final g = _grid((c, r) => 3000);
    final p = _at(g, 10.5, 20.5);
    final (x, y) = g.toPixel(p.lng, p.lat);
    expect(x, closeTo(10.5, 1e-6));
    expect(y, closeTo(20.5, 1e-6));
    expect(g.metersPerPixel(0), closeTo(36, 1.5));
    expect(g.at(p.lng, p.lat), 3000);
  });

  test('en lo plano va casi en línea recta', () {
    final g = _grid((c, r) => 3000);
    final a = _at(g, 10.5, 60.5), b = _at(g, 110.5, 60.5);
    final path = findTerrainPath(g, a, b)!;
    expect(path.first, a);
    expect(path.last, b);
    expect(_len(path), closeTo(_m(a, b), _m(a, b) * 0.02));
  });

  test('rodea un cerro en vez de subirlo', () {
    // Cono de 500 m de alto y ~1 km de radio entre a y b
    final g = _grid((c, r) {
      final d = math.sqrt(math.pow(c - 60, 2) + math.pow(r - 60, 2));
      return 3000 + math.max(0, 500 - d * 18);
    });
    final a = _at(g, 10.5, 60.5), b = _at(g, 110.5, 60.5);
    final path = findTerrainPath(g, a, b)!;
    final top = path.map((p) => g.at(p.lng, p.lat)!).reduce(math.max);
    expect(top, lessThan(3200), reason: 'no sube a la cima (3,500 m)');
    expect(_len(path), greaterThan(_m(a, b)));
  });

  test('cruza una pared solo por su paso', () {
    // Pared vertical de 300 m en la columna 60, con un hueco en las filas 95–100
    final g = _grid(
      (c, r) => (c - 60).abs() <= 1 && (r < 95 || r > 100) ? 3300 : 3000,
    );
    final a = _at(g, 20.5, 30.5), b = _at(g, 100.5, 30.5);
    final path = findTerrainPath(g, a, b)!;
    final crossing = path
        .where((p) => (g.toPixel(p.lng, p.lat).$1 - 60.5).abs() < 2)
        .map((p) => g.toPixel(p.lng, p.lat).$2);
    expect(crossing, isNotEmpty);
    for (final y in crossing) {
      expect(y, inInclusiveRange(93, 103));
    }
  });

  test('sin paso o sin relieve no inventa nada', () {
    final wall = _grid((c, r) => (c - 60).abs() <= 1 ? 3300 : 3000);
    expect(
      findTerrainPath(wall, _at(wall, 20.5, 30.5), _at(wall, 100.5, 30.5)),
      isNull,
    );
    final holes = _grid((c, r) => c > 50 ? double.nan : 3000);
    expect(
      findTerrainPath(holes, _at(holes, 20.5, 30.5), _at(holes, 100.5, 30.5)),
      isNull,
    );
  });
}
