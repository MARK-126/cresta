import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import '../data/trail_route.dart';
import '../offline/tile_math.dart';
import 'dem_grid.dart';

/// Relieve de una caja (null si no hay o es muy grande).
typedef DemLoader = Future<DemGrid?> Function(BBox box);

/// Camino a campo traviesa donde no hay sendero: el más rápido a pie sobre el relieve
/// descargado (Tobler fuera de sendero), que por eso busca lo más llano y rodea lo
/// empinado. El relieve es de ~30 m: no ve barrancas cortas, ríos, vegetación ni
/// cercas, así que el resultado es una sugerencia para revisar, no un trazo seguro.
class TerrainRouter {
  TerrainRouter(this.load);

  final DemLoader load;

  Future<List<LngLat>?> route(LngLat a, LngLat b) async {
    final d = _meters(a, b);
    // Margen para rodear: los cerros obligan a desviarse
    for (final margin in [math.max(800.0, d * 0.4), math.max(500.0, d * 0.2)]) {
      final grid = await load(boxAround(a, b, margin));
      if (grid == null) continue;
      return Isolate.run(() => findTerrainPath(grid, a, b));
    }
    return null;
  }
}

/// Caja que contiene a y b más [marginM] metros por lado.
BBox boxAround(LngLat a, LngLat b, double marginM) {
  final dLat = marginM / 111320;
  final dLng =
      marginM / (111320 * math.cos((a.lat + b.lat) / 2 * math.pi / 180));
  return BBox(
    math.min(a.lng, b.lng) - dLng,
    math.min(a.lat, b.lat) - dLat,
    math.max(a.lng, b.lng) + dLng,
    math.max(a.lat, b.lat) + dLat,
  );
}

double _meters(LngLat a, LngLat b) {
  final dLat = (b.lat - a.lat) * 111320;
  final dLng =
      (b.lng - a.lng) * 111320 * math.cos((a.lat + b.lat) / 2 * math.pi / 180);
  return math.sqrt(dLat * dLat + dLng * dLng);
}

/// Más de 45° (100 %) no se camina: con relieve de 30 m eso ya es pared o escalada.
const maxWalkableGrade = 1.0;

const _dirs = [
  (1, 0), (-1, 0), (0, 1), (0, -1), //
  (1, 1), (1, -1), (-1, 1), (-1, -1),
];

/// A* sobre los píxeles del relieve con 8 vecinos; costo = segundos a pie. Pura (corre
/// en otro isolate). Null si a o b no tienen relieve o no hay paso.
List<LngLat>? findTerrainPath(DemGrid g, LngLat a, LngLat b) {
  final (ax, ay) = g.toPixel(a.lng, a.lat);
  final (bx, by) = g.toPixel(b.lng, b.lat);
  final w = g.width, h = g.height;
  final s = ay.floor() * w + ax.floor(), t = by.floor() * w + bx.floor();
  bool inside(double x, double y) => x >= 0 && y >= 0 && x < w && y < h;
  if (!inside(ax, ay) || !inside(bx, by)) return null;
  if (g.ele[s].isNaN || g.ele[t].isNaN) return null;

  final rowM = [for (var r = 0; r < h; r++) g.metersPerPixel(r)];
  const fastest = toblerMaxMs * offTrailFactor;
  final tc = t % w, tr = t ~/ w;
  double estimate(int i) {
    final dc = (i % w - tc) * rowM[i ~/ w], dr = (i ~/ w - tr) * rowM[i ~/ w];
    return math.sqrt(dc * dc + dr * dr) / fastest;
  }

  final cost = Float64List(w * h)..fillRange(0, w * h, double.infinity);
  final prev = Int32List(w * h)..fillRange(0, w * h, -1);
  final done = Uint8List(w * h);
  cost[s] = 0;
  final heap = _Heap()..push(estimate(s), s);
  while (heap.isNotEmpty) {
    final u = heap.pop();
    if (done[u] == 1) continue;
    done[u] = 1;
    if (u == t) break;
    final uc = u % w, ur = u ~/ w, ue = g.ele[u], m = rowM[ur];
    for (final (dc, dr) in _dirs) {
      final vc = uc + dc, vr = ur + dr;
      if (vc < 0 || vr < 0 || vc >= w || vr >= h) continue;
      final v = vr * w + vc;
      final ve = g.ele[v];
      if (done[v] == 1 || ve.isNaN) continue;
      final dist = dc != 0 && dr != 0 ? m * math.sqrt2 : m;
      final grade = (ve - ue) / dist;
      if (grade.abs() > maxWalkableGrade) continue;
      final secs = dist / (toblerKmh(grade) / 3.6 * offTrailFactor);
      final nc = cost[u] + secs;
      if (nc < cost[v]) {
        cost[v] = nc;
        prev[v] = u;
        heap.push(nc + estimate(v), v);
      }
    }
  }
  if (cost[t].isInfinite) return null;

  final cells = <(double, double)>[];
  for (var u = t; u != -1; u = prev[u]) {
    cells.add((u % w + .5, u ~/ w + .5));
  }
  // Los 8 vecinos dejan zigzag: se simplifica a ~1/3 de píxel (≈ 10 m)
  final simple = _simplify(cells.reversed.toList(), .35);
  final out = <LngLat>[a];
  for (final (x, y) in simple.skip(1).take(simple.length - 2)) {
    final (lng, lat) = g.toLngLat(x, y);
    out.add(LngLat(lng, lat));
  }
  out.add(b);
  return out;
}

/// Douglas–Peucker en píxeles.
List<(double, double)> _simplify(List<(double, double)> p, double tol) {
  if (p.length < 3) return p;
  final keep = List<bool>.filled(p.length, false);
  keep[0] = keep[p.length - 1] = true;
  final stack = <(int, int)>[(0, p.length - 1)];
  while (stack.isNotEmpty) {
    final (i, j) = stack.removeLast();
    var best = tol, at = -1;
    final (x1, y1) = p[i];
    final (x2, y2) = p[j];
    final dx = x2 - x1, dy = y2 - y1, len = math.sqrt(dx * dx + dy * dy);
    for (var k = i + 1; k < j; k++) {
      final (x, y) = p[k];
      final d = len == 0
          ? math.sqrt((x - x1) * (x - x1) + (y - y1) * (y - y1))
          : ((x - x1) * dy - (y - y1) * dx).abs() / len;
      if (d > best) {
        best = d;
        at = k;
      }
    }
    if (at != -1) {
      keep[at] = true;
      stack
        ..add((i, at))
        ..add((at, j));
    }
  }
  return [
    for (var k = 0; k < p.length; k++)
      if (keep[k]) p[k],
  ];
}

/// Montículo binario mínimo de nodos por prioridad.
class _Heap {
  final _k = <double>[];
  final _v = <int>[];
  bool get isNotEmpty => _k.isNotEmpty;

  void push(double k, int v) {
    _k.add(k);
    _v.add(v);
    var i = _k.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_k[p] <= _k[i]) break;
      _swap(i, p);
      i = p;
    }
  }

  int pop() {
    final top = _v[0];
    final lastK = _k.removeLast(), lastV = _v.removeLast();
    if (_k.isNotEmpty) {
      _k[0] = lastK;
      _v[0] = lastV;
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = l + 1;
        var m = i;
        if (l < _k.length && _k[l] < _k[m]) m = l;
        if (r < _k.length && _k[r] < _k[m]) m = r;
        if (m == i) break;
        _swap(i, m);
        i = m;
      }
    }
    return top;
  }

  void _swap(int i, int j) {
    final k = _k[i], v = _v[i];
    _k[i] = _k[j];
    _v[i] = _v[j];
    _k[j] = k;
    _v[j] = v;
  }
}
