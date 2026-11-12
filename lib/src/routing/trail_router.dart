import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import '../data/trail_route.dart';
import '../offline/map_sources.dart';
import '../offline/tile_math.dart';
import '../offline/tile_store.dart';
import '../tiles/mvt.dart';
import '../tiles/tile_clip.dart';

/// Lee un mosaico topográfico guardado (MVT sin comprimir) o null si no está.
typedef TopoTileReader = Future<Uint8List?> Function(int z, int x, int y);

/// Un mosaico topográfico ya leído, listo para mandarlo a otro isolate.
typedef TopoTile = ({int z, int x, int y, Uint8List bytes});

/// Busca el camino más corto por senderos, brechas y calles entre dos puntos con los
/// mapas guardados en el teléfono (sin conexión). Usa los mosaicos de zoom 14 (descarga
/// Detallada); donde no hay, el de zoom 13, que trae muchos menos senderos.
///
/// Medido en el experimento del 28 oct 2026 (ver `docs/contexto/pruebas.md`): hay que
/// recortar cada línea a su mosaico y unir solo los extremos sueltos a la línea más cercana.
class TrailRouter {
  TrailRouter(this.read);

  /// Lee de las zonas descargadas y, si no, de la caché de navegación.
  factory TrailRouter.fromStores(List<TileStore> stores) =>
      TrailRouter((z, x, y) async {
        for (final s in stores) {
          final bytes = await s.read(MapSource.topo, z, x, y);
          if (bytes != null) return bytes;
        }
        return null;
      });

  final TopoTileReader read;

  /// Tope de mosaicos de zoom 14 por búsqueda (~55 × 55 km).
  static const maxTiles = 600;

  /// Camino de [a] a [b], o null si no hay mapas, algún punto queda lejos de todo
  /// sendero o los senderos no se conectan.
  Future<List<LngLat>?> route(LngLat a, LngLat b) async {
    final tiles = await _load(a, b);
    if (tiles.isEmpty) return null;
    return Isolate.run(() => findTrailPath(tiles, a, b));
  }

  Future<List<TopoTile>> _load(LngLat a, LngLat b) async {
    // Margen: los senderos rodean barrancas, así que se busca más allá de la línea recta
    var margin = math.max(1500.0, _meters(a, b) * 0.5);
    late TileRange range;
    do {
      range = tileRange(_box(a, b, margin), 14);
      margin *= 0.7;
    } while (range.count > maxTiles && margin > 300);
    if (range.count > maxTiles) return const [];
    final tiles = <TopoTile>[];
    final parents = <(int, int)>{};
    for (final (x, y) in range.tiles) {
      final bytes = await read(14, x, y);
      if (bytes != null) {
        tiles.add((z: 14, x: x, y: y, bytes: bytes));
      } else if (parents.add((x >> 1, y >> 1))) {
        final up = await read(13, x >> 1, y >> 1);
        if (up != null) tiles.add((z: 13, x: x >> 1, y: y >> 1, bytes: up));
      }
    }
    return tiles;
  }
}

BBox _box(LngLat a, LngLat b, double marginM) {
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

typedef _P = (double, double);

double _meters(LngLat a, LngLat b) => _m((a.lng, a.lat), (b.lng, b.lat));

double _m(_P a, _P b) {
  final dLat = (b.$2 - a.$2) * 111320;
  final dLng =
      (b.$1 - a.$1) * 111320 * math.cos((a.$2 + b.$2) / 2 * math.pi / 180);
  return math.sqrt(dLat * dLat + dLng * dLng);
}

/// Distancia (m) de [p] al segmento a–b y dónde cae su proyección (0 = a, 1 = b).
(double, double) _project(_P p, _P a, _P b) {
  final cos = math.cos(p.$2 * math.pi / 180);
  final ax = (a.$1 - p.$1) * 111320 * cos, ay = (a.$2 - p.$2) * 111320;
  final bx = (b.$1 - p.$1) * 111320 * cos, by = (b.$2 - p.$2) * 111320;
  final dx = bx - ax, dy = by - ay;
  final len2 = dx * dx + dy * dy;
  final t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
  final px = ax + t * dx, py = ay + t * dy;
  return (math.sqrt(px * px + py * py), t);
}

/// Clases de OpenMapTiles por las que se puede caminar, con su costo por metro.
/// Las carreteras grandes cuestan el doble: solo se usan si no hay otra forma.
const _walkable = {
  'path': 1.0,
  'track': 1.0,
  'service': 1.0,
  'minor': 1.0,
  'tertiary': 1.0,
  'secondary': 1.2,
  'primary': 1.2,
  'trunk': 2.0,
  'motorway': 2.0,
};

/// Distancia máxima de un extremo suelto a otra línea para unirlos (los senderos que se
/// tocan en el terreno quedan a 1–3 m en los mosaicos; resultado estable entre 3 y 30 m).
const joinLooseEndsMeters = 15.0;

/// Distancia máxima de un punto marcado al sendero más cercano para usarlo.
const snapMeters = 150.0;

/// Busca el camino (función pura, corre en otro isolate). Ver [TrailRouter].
List<LngLat>? findTrailPath(List<TopoTile> tiles, LngLat a, LngLat b) {
  final g = _Graph();
  for (final t in tiles) {
    final MvtLayer layer;
    try {
      layer = decodeMvt(t.bytes).firstWhere((l) => l.name == 'transportation');
    } on StateError {
      continue; // mosaico sin caminos
    } on FormatException {
      continue;
    }
    for (final f in layer.features) {
      final cost = _walkable[f.props['class']];
      if (f.type != 2 || cost == null) continue;
      for (final part in f.parts) {
        // Recortar al mosaico: los márgenes repiten las líneas con otros vértices
        for (final run in clipLineToTile(part, layer.extent)) {
          int? prev;
          for (final q in run) {
            final n = g.node(
              tilePointToLngLat(t.z, t.x, t.y, q.$1, q.$2, layer.extent),
            );
            if (prev != null && prev != n) g.link(prev, n, cost);
            prev = n;
          }
        }
      }
    }
  }
  if (g.pos.isEmpty) return null;
  g.indexSegments();
  g.joinLooseEnds(joinLooseEndsMeters);
  final s = g.attach((a.lng, a.lat));
  final t = g.attach((b.lng, b.lat));
  if (s == null || t == null) return null;
  // Los dos sobre el mismo segmento: directo, sin ir hasta sus extremos
  if (g.attachedTo[s] == g.attachedTo[t]) g.link(s, t, 1);
  final path = g.search(s, t);
  if (path == null) return null;
  final out = <LngLat>[a];
  for (final i in path) {
    final p = g.pos[i];
    if (_m(p, (out.last.lng, out.last.lat)) > 0.5) out.add(LngLat(p.$1, p.$2));
  }
  // Termina justo en el punto marcado
  if (_meters(out.last, b) > 0.5) {
    out.add(b);
  } else {
    out[out.length - 1] = b;
  }
  return out.length < 2 ? null : out;
}

class _Graph {
  final pos = <_P>[];
  final adj = <List<(int, double)>>[];

  /// Segmento al que quedó pegado cada punto marcado (ver [attach]).
  final attachedTo = <int, (int, int)>{};
  final _ids = <(int, int), int>{};

  // Índice de segmentos en celdas de ~55 m para buscar la línea más cercana
  static const _cell = 0.0005;
  final _segs = <(int, int)>[];
  final _grid = <(int, int), List<int>>{};

  /// Nodo de un punto; los vértices a menos de ~1 m se vuelven el mismo.
  int node(_P p) =>
      _ids.putIfAbsent(((p.$1 * 1e5).round(), (p.$2 * 1e5).round()), () {
        pos.add(p);
        adj.add([]);
        return pos.length - 1;
      });

  /// Arista en los dos sentidos; [factor] multiplica los metros (costo de la clase).
  void link(int u, int v, double factor) {
    final w = _m(pos[u], pos[v]) * factor;
    adj[u].add((v, w));
    adj[v].add((u, w));
  }

  (int, int) _key(_P p) => ((p.$1 / _cell).floor(), (p.$2 / _cell).floor());

  void _addSeg(int u, int v) {
    _segs.add((u, v));
    final ka = _key(pos[u]), kb = _key(pos[v]);
    for (var i = math.min(ka.$1, kb.$1); i <= math.max(ka.$1, kb.$1); i++) {
      for (var j = math.min(ka.$2, kb.$2); j <= math.max(ka.$2, kb.$2); j++) {
        (_grid[(i, j)] ??= []).add(_segs.length - 1);
      }
    }
  }

  void indexSegments() {
    for (var u = 0; u < adj.length; u++) {
      for (final (v, _) in adj[u]) {
        if (u < v) _addSeg(u, v);
      }
    }
  }

  /// Segmento más cercano a [p] a menos de [maxM], sin contar los que tocan [skip].
  (int, int, double, double)? nearestSeg(_P p, double maxM, {Set<int>? skip}) {
    final k = _key(p);
    final rings = (maxM / 50).ceil() + 1;
    var best = maxM;
    (int, int, double, double)? found;
    final seen = <int>{};
    for (var di = -rings; di <= rings; di++) {
      for (var dj = -rings; dj <= rings; dj++) {
        for (final s in _grid[(k.$1 + di, k.$2 + dj)] ?? const <int>[]) {
          if (!seen.add(s)) continue;
          final (u, v) = _segs[s];
          if (skip != null && (skip.contains(u) || skip.contains(v))) continue;
          final (d, t) = _project(p, pos[u], pos[v]);
          if (d < best) {
            best = d;
            found = (u, v, d, t);
          }
        }
      }
    }
    return found;
  }

  /// Los mosaicos cortan las líneas y los cruces no siempre comparten vértice: cada extremo
  /// suelto se une a la línea más cercana. Solo los extremos, para no inventar atajos
  /// entre senderos paralelos.
  void joinLooseEnds(double maxM) {
    final links = <(int, int, int, double, double)>[];
    for (var i = 0; i < pos.length; i++) {
      final nbrs = {for (final (v, _) in adj[i]) v};
      if (nbrs.length != 1) continue;
      final hit = nearestSeg(pos[i], maxM, skip: {i, nbrs.first});
      if (hit == null) continue;
      final (u, v, d, t) = hit;
      final len = _m(pos[u], pos[v]);
      links.add((i, u, v, d + t * len, d + (1 - t) * len));
    }
    for (final (i, u, v, wu, wv) in links) {
      adj[i].add((u, wu));
      adj[u].add((i, wu));
      adj[i].add((v, wv));
      adj[v].add((i, wv));
    }
  }

  /// Nodo nuevo sobre la línea más cercana a [p] (a menos de [snapMeters]), unido a
  /// los dos extremos de ese segmento.
  int? attach(_P p) {
    final hit = nearestSeg(p, snapMeters);
    if (hit == null) return null;
    final (u, v, _, t) = hit;
    final a = pos[u], b = pos[v];
    final q = (a.$1 + (b.$1 - a.$1) * t, a.$2 + (b.$2 - a.$2) * t);
    pos.add(q);
    adj.add([]);
    final n = pos.length - 1;
    attachedTo[n] = (u, v);
    adj[n].add((u, _m(q, a)));
    adj[u].add((n, _m(q, a)));
    adj[n].add((v, _m(q, b)));
    adj[v].add((n, _m(q, b)));
    return n;
  }

  /// A*: el costo nunca es menor que los metros en línea recta, así que la estimación vale.
  List<int>? search(int s, int t) {
    final dist = List<double>.filled(pos.length, double.infinity);
    final prev = List<int>.filled(pos.length, -1);
    dist[s] = 0;
    final heap = _Heap()..push(_m(pos[s], pos[t]), s);
    while (heap.isNotEmpty) {
      final (f, u) = heap.pop();
      if (u == t) break;
      if (f - _m(pos[u], pos[t]) > dist[u] + 1e-6) continue; // entrada vieja
      for (final (v, w) in adj[u]) {
        final nd = dist[u] + w;
        if (nd < dist[v]) {
          dist[v] = nd;
          prev[v] = u;
          heap.push(nd + _m(pos[v], pos[t]), v);
        }
      }
    }
    if (dist[t].isInfinite) return null;
    final path = <int>[];
    for (var u = t; u != -1; u = prev[u]) {
      path.add(u);
    }
    return path.reversed.toList();
  }
}

/// Montículo binario mínimo de (prioridad, nodo).
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

  (double, int) pop() {
    final top = (_k[0], _v[0]);
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
