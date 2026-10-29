// ignore_for_file: avoid_print, avoid_relative_lib_imports
// Experimento 2: ¿los senderos de los mosaicos cubren una ruta real y una búsqueda la reproduce?
// Uso: dart tool/dev/spike_ruta.dart RUTA_DEL_PAQUETE assets/data/arista_del_sol.json
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../lib/src/tiles/mvt.dart';
import '../../lib/src/tiles/tile_clip.dart';

typedef P = (double lng, double lat);

const _trailClasses = {'path', 'track'};

double _m(P a, P b) {
  final dLat = (b.$2 - a.$2) * 111320;
  final dLng =
      (b.$1 - a.$1) * 111320 * math.cos((a.$2 + b.$2) / 2 * math.pi / 180);
  return math.sqrt(dLat * dLat + dLng * dLng);
}

/// Distancia de un punto a un segmento, en metros.
double _distSeg(P p, P a, P b) {
  final cos = math.cos(p.$2 * math.pi / 180);
  double x(P q) => (q.$1 - p.$1) * 111320 * cos;
  double y(P q) => (q.$2 - p.$2) * 111320;
  final ax = x(a), ay = y(a), bx = x(b), by = y(b);
  final dx = bx - ax, dy = by - ay;
  final len2 = dx * dx + dy * dy;
  final t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
  final px = ax + t * dx, py = ay + t * dy;
  return math.sqrt(px * px + py * py);
}

/// Distancia de un punto a un segmento (m) y dónde cae la proyección (0 = a, 1 = b).
(double, double) _proj(P p, P a, P b) {
  final cos = math.cos(p.$2 * math.pi / 180);
  double x(P q) => (q.$1 - p.$1) * 111320 * cos;
  double y(P q) => (q.$2 - p.$2) * 111320;
  final ax = x(a), ay = y(a), bx = x(b), by = y(b);
  final dx = bx - ax, dy = by - ay;
  final len2 = dx * dx + dy * dy;
  final t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
  final px = ax + t * dx, py = ay + t * dy;
  return (math.sqrt(px * px + py * py), t);
}

class SegIndex {
  SegIndex(this.cell);
  final double cell; // grados
  final _grid = <(int, int), List<(P, P)>>{};
  (int, int) _k(P p) => ((p.$1 / cell).floor(), (p.$2 / cell).floor());
  void add(P a, P b) {
    final ka = _k(a), kb = _k(b);
    for (var i = math.min(ka.$1, kb.$1); i <= math.max(ka.$1, kb.$1); i++) {
      for (var j = math.min(ka.$2, kb.$2); j <= math.max(ka.$2, kb.$2); j++) {
        (_grid[(i, j)] ??= []).add((a, b));
      }
    }
  }

  double nearest(P p) {
    final k = _k(p);
    var best = double.infinity;
    for (var i = -5; i <= 5; i++) {
      for (var j = -5; j <= 5; j++) {
        for (final s in _grid[(k.$1 + i, k.$2 + j)] ?? const []) {
          best = math.min(best, _distSeg(p, s.$1, s.$2));
        }
      }
    }
    return best;
  }
}

String _pct(List<double> v, double q) {
  final s = [...v]..sort();
  return s[((s.length - 1) * q).round()].toStringAsFixed(0);
}

double _len(List<P> l) {
  var s = 0.0;
  for (var i = 1; i < l.length; i++) {
    s += _m(l[i - 1], l[i]);
  }
  return s;
}

void main(List<String> args) {
  final zoom = int.tryParse(Platform.environment["Z"] ?? "") ?? 14;
  final root = Directory('${args[0]}/topo');
  final route = <P>[
    for (final c
        in (jsonDecode(File(args[1]).readAsStringSync())['coordinates']
            as List))
      ((c[0] as num).toDouble(), (c[1] as num).toDouble()),
  ];
  final routeLen = _len(route);

  // 1) Senderos de todos los mosaicos de zoom 14 (los de menor zoom no traen path/track)
  final lines = <List<P>>[];
  final borderPts =
      <P>[]; // puntos que caen exactamente en el borde de un mosaico
  var tiles = 0;
  final sw = Stopwatch()..start();
  for (final f in root.listSync(recursive: true)) {
    if (f is! File) continue;
    final parts = f.path.split('/');
    final z = int.parse(parts[parts.length - 3]);
    if (z != zoom) continue;
    final x = int.parse(parts[parts.length - 2]), y = int.parse(parts.last);
    tiles++;
    for (final layer in decodeMvt(Uint8List.fromList(f.readAsBytesSync()))) {
      if (layer.name != 'transportation') continue;
      for (final ft in layer.features) {
        if (ft.type != 2 || !_trailClasses.contains(ft.props['class'])) {
          continue;
        }
        for (final part in ft.parts) {
          final runs = Platform.environment['CLIP'] == '0'
              ? [
                  [for (final q in part) (q.$1.toDouble(), q.$2.toDouble())],
                ]
              : clipLineToTile(part, layer.extent);
          for (final run in runs) {
            lines.add([
              for (final q in run)
                tilePointToLngLat(z, x, y, q.$1, q.$2, layer.extent),
            ]);
            for (final q in run) {
              final e = layer.extent;
              if (q.$1 == 0 || q.$1 == e || q.$2 == 0 || q.$2 == e) {
                borderPts.add(
                  tilePointToLngLat(z, x, y, q.$1, q.$2, layer.extent),
                );
              }
            }
          }
        }
      }
    }
  }
  print(
    'z14: $tiles mosaicos, ${lines.length} líneas de sendero, leídas en ${sw.elapsedMilliseconds} ms',
  );
  final trailKm = lines.fold<double>(0, (a, l) => a + _len(l)) / 1000;
  print(
    'senderos: ${trailKm.toStringAsFixed(1)} km en total; ruta real: ${(routeLen / 1000).toStringAsFixed(1)} km, ${route.length} puntos',
  );

  // 2) ¿Qué tanto cubren la ruta real?
  final idx = SegIndex(0.001);
  for (final l in lines) {
    for (var i = 1; i < l.length; i++) {
      idx.add(l[i - 1], l[i]);
    }
  }
  final d = [for (final p in route) idx.nearest(p)];
  double within(double m) => d.where((x) => x <= m).length / d.length * 100;
  print(
    'puntos de la ruta real con un sendero a ≤ 25 m: ${within(25).toStringAsFixed(0)} %, ≤ 50 m: ${within(50).toStringAsFixed(0)} %, ≤ 100 m: ${within(100).toStringAsFixed(0)} %',
  );
  print(
    'distancia al sendero más cercano: mediana ${_pct(d, 0.5)} m, p90 ${_pct(d, 0.9)} m, máx ${_pct(d, 1)} m',
  );

  // 3) Grafo (nodos redondeados a ~11 m) y camino más corto entre el inicio y el final de la ruta
  final quant = double.tryParse(Platform.environment['Q'] ?? '') ?? 1e5;
  String key(P p) => '${(p.$1 * quant).round()},${(p.$2 * quant).round()}';
  final nodes = <String, int>{};
  final pos = <P>[];
  final adj = <int, List<(int, double)>>{};
  int node(P p) => nodes.putIfAbsent(key(p), () {
    pos.add(p);
    return pos.length - 1;
  });
  for (final l in lines) {
    for (var i = 1; i < l.length; i++) {
      final a = node(l[i - 1]), b = node(l[i]);
      if (a == b) continue;
      final w = _m(l[i - 1], l[i]);
      (adj[a] ??= []).add((b, w));
      (adj[b] ??= []).add((a, w));
    }
  }
  // Los mosaicos cortan las líneas y los cruces no comparten vértice: se unen los nodos que
  // quedan a menos de [linkMeters] (la misma idea que "unir extremos sueltos a < 20 m" del JS).
  final linkMeters = double.tryParse(Platform.environment['LINK'] ?? '') ?? 20;
  // MODE=ends: solo los extremos sueltos (nodos con un único vecino) se unen a la línea más
  // cercana a menos de TAU metros, sin tocar el resto: así no hay atajos entre senderos paralelos.
  if (Platform.environment['MODE'] == 'ends') {
    final tau = double.tryParse(Platform.environment['TAU'] ?? '') ?? 8;
    final segList = <(int, int)>[];
    final segGrid = <(int, int), List<int>>{};
    const cd = 0.0002;
    (int, int) kk(P p) => ((p.$1 / cd).floor(), (p.$2 / cd).floor());
    for (final e in adj.entries) {
      for (final n in e.value) {
        if (e.key < n.$1) segList.add((e.key, n.$1));
      }
    }
    for (var s = 0; s < segList.length; s++) {
      final a = pos[segList[s].$1], b = pos[segList[s].$2];
      final ka = kk(a), kb = kk(b);
      for (var i = math.min(ka.$1, kb.$1); i <= math.max(ka.$1, kb.$1); i++) {
        for (var j = math.min(ka.$2, kb.$2); j <= math.max(ka.$2, kb.$2); j++) {
          (segGrid[(i, j)] ??= []).add(s);
        }
      }
    }
    final links = <(int, int, int, double, double)>[];
    var ends = 0;
    for (var i = 0; i < pos.length; i++) {
      final nbrs = (adj[i] ?? const <(int, double)>[]).map((e) => e.$1).toSet();
      if (nbrs.length != 1) continue;
      ends++;
      final only = nbrs.first;
      final p = pos[i], k = kk(p);
      var bestD = tau;
      (int, int, double)? best;
      for (var di = -2; di <= 2; di++) {
        for (var dj = -2; dj <= 2; dj++) {
          for (final s in segGrid[(k.$1 + di, k.$2 + dj)] ?? const <int>[]) {
            final (a, b) = segList[s];
            if (a == i || b == i || a == only || b == only) continue;
            final (dd, t) = _proj(p, pos[a], pos[b]);
            if (dd < bestD) {
              bestD = dd;
              best = (a, b, t);
            }
          }
        }
      }
      if (best != null) {
        final (a, b, t) = best;
        final len = _m(pos[a], pos[b]);
        links.add((i, a, b, bestD + t * len, bestD + (1 - t) * len));
      }
    }
    for (final (i, a, b, wa, wb) in links) {
      (adj[i] ??= []).add((a, wa));
      (adj[a] ??= []).add((i, wa));
      (adj[i] ??= []).add((b, wb));
      (adj[b] ??= []).add((i, wb));
    }
    print(
      'extremos sueltos: $ends; unidos a ≤ ${tau.toStringAsFixed(0)} m: ${links.length}',
    );
  }
  // MODE=border: solo se unen puntos que caen en el borde de un mosaico (donde está el desajuste)
  final onlyBorder = Platform.environment['MODE'] == 'border';
  final borderIds = {for (final p in borderPts) ?nodes[key(p)]};
  if (linkMeters > 0) {
    const cellDeg = 0.0003;
    final cells = <(int, int), List<int>>{};
    (int, int) cellOf(P p) =>
        ((p.$1 / cellDeg).floor(), (p.$2 / cellDeg).floor());
    for (var i = 0; i < pos.length; i++) {
      (cells[cellOf(pos[i])] ??= []).add(i);
    }
    var added = 0;
    for (var i = 0; i < pos.length; i++) {
      final c = cellOf(pos[i]);
      for (var di = -1; di <= 1; di++) {
        for (var dj = -1; dj <= 1; dj++) {
          for (final j in cells[(c.$1 + di, c.$2 + dj)] ?? const <int>[]) {
            if (j <= i) continue;
            if (onlyBorder &&
                !(borderIds.contains(i) && borderIds.contains(j))) {
              continue;
            }
            final w = _m(pos[i], pos[j]);
            if (w > linkMeters) continue;
            final exists = (adj[i] ?? const <(int, double)>[]).any(
              (e) => e.$1 == j,
            );
            if (exists) continue;
            (adj[i] ??= []).add((j, w));
            (adj[j] ??= []).add((i, w));
            added++;
          }
        }
      }
    }
    print('uniones añadidas a ≤ ${linkMeters.toStringAsFixed(0)} m: $added');
  }
  int nearestNode(P p) {
    var best = -1;
    var bd = double.infinity;
    for (var i = 0; i < pos.length; i++) {
      final dd = _m(p, pos[i]);
      if (dd < bd) {
        bd = dd;
        best = i;
      }
    }
    return best;
  }

  final s = nearestNode(route.first), t = nearestNode(route.last);
  print(
    'grafo: ${pos.length} nodos; inicio de la ruta a ${_m(route.first, pos[s]).toStringAsFixed(0)} m de un nodo, final a ${_m(route.last, pos[t]).toStringAsFixed(0)} m',
  );

  // Componentes conectados
  final comp = List<int>.filled(pos.length, -1);
  var nc = 0;
  for (var i = 0; i < pos.length; i++) {
    if (comp[i] != -1) continue;
    final q = Queue<int>()..add(i);
    comp[i] = nc;
    while (q.isNotEmpty) {
      final u = q.removeFirst();
      for (final e in adj[u] ?? const <(int, double)>[]) {
        if (comp[e.$1] == -1) {
          comp[e.$1] = nc;
          q.add(e.$1);
        }
      }
    }
    nc++;
  }
  print(
    'componentes conectados: $nc; inicio y final en la misma: ${comp[s] == comp[t]}',
  );

  // Dijkstra por distancia
  final dist = List<double>.filled(pos.length, double.infinity);
  final prev = List<int>.filled(pos.length, -1);
  dist[s] = 0;
  final pq = SplayTreeSet<(double, int)>(
    (a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
  )..add((0, s));
  final sw2 = Stopwatch()..start();
  while (pq.isNotEmpty) {
    final cur = pq.first;
    pq.remove(cur);
    final u = cur.$2;
    if (u == t) break;
    for (final e in adj[u] ?? const <(int, double)>[]) {
      final nd = dist[u] + e.$2;
      if (nd < dist[e.$1]) {
        pq.remove((dist[e.$1], e.$1));
        dist[e.$1] = nd;
        prev[e.$1] = u;
        pq.add((nd, e.$1));
      }
    }
  }
  print('búsqueda: ${sw2.elapsedMicroseconds / 1000} ms');
  if (dist[t].isInfinite) {
    print('sin camino entre el inicio y el final de la ruta');
    return;
  }
  final path = <P>[];
  for (var u = t; u != -1; u = prev[u]) {
    path.add(pos[u]);
  }
  final found = path.reversed.toList();
  final dump = Platform.environment['DUMP'];
  if (dump != null) {
    List<List<double>> pts(List<P> l) => [
      for (final p in l) [p.$1, p.$2],
    ];
    File(dump).writeAsStringSync(
      jsonEncode({
        'route': pts(route),
        'found': pts(found),
        'trails': [for (final l in lines) pts(l)],
      }),
    );
  }
  print(
    'camino encontrado: ${(dist[t] / 1000).toStringAsFixed(1)} km (la ruta real: ${(routeLen / 1000).toStringAsFixed(1)} km)',
  );

  // 4) ¿Se parece a la ruta real?
  final ridx = SegIndex(0.001);
  for (var i = 1; i < route.length; i++) {
    ridx.add(route[i - 1], route[i]);
  }
  final fidx = SegIndex(0.001);
  for (var i = 1; i < found.length; i++) {
    fidx.add(found[i - 1], found[i]);
  }
  final a = [for (final p in found) ridx.nearest(p)];
  final b = [for (final p in route) fidx.nearest(p)];
  double frac(List<double> v, double m) =>
      v.where((x) => x <= m).length / v.length * 100;
  print(
    'del camino encontrado, cerca de la ruta real: ≤ 50 m ${frac(a, 50).toStringAsFixed(0)} %, ≤ 150 m ${frac(a, 150).toStringAsFixed(0)} %; máx ${_pct(a, 1)} m',
  );
  print(
    'de la ruta real, cerca del camino encontrado: ≤ 50 m ${frac(b, 50).toStringAsFixed(0)} %, ≤ 150 m ${frac(b, 150).toStringAsFixed(0)} %; máx ${_pct(b, 1)} m',
  );
}
