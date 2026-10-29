import 'dart:math' as math;

import '../data/trail_route.dart';
import '../tracking/track.dart' show haversine;

/// Altitud de un punto, o null si no hay relieve de ese lugar en el teléfono.
typedef ElevationAt = Future<double?> Function(double lng, double lat);

/// Calcula el perfil de una línea: distancias acumuladas, altitudes y desnivel.
///
/// Agrega puntos intermedios para que no haya tramos de más de [step] metros sin altitud
/// (una recta de 2 km entre dos clics cruza valles que su inicio y su fin no muestran).
Future<TrailRoute> buildProfile({
  required List<LngLat> line,
  required ElevationAt elevation,
  required String id,
  required String name,
  required String source,
  double step = 30,
}) async {
  assert(line.length >= 2, 'una ruta necesita al menos dos puntos');
  final points = densify(line, step: step);
  final distances = <double>[0];
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1], b = points[i];
    distances.add(distances.last + haversine(a.lat, a.lng, b.lat, b.lng));
  }
  final raw = <double?>[for (final p in points) await elevation(p.lng, p.lat)];
  final known = raw.whereType<double>().length;
  final elevations = fillGaps(raw);
  final gain = elevationGain(elevations);
  final km = (distances.last / 1000).toStringAsFixed(1);
  return TrailRoute(
    id: id,
    name: name,
    summary: known == 0
        ? '$km km · sin relieve descargado: descarga la zona para ver el desnivel'
        : '$km km · +${gain.round()} m de desnivel',
    coordinates: points,
    distances: distances,
    elevations: elevations,
    gain: gain,
    source: source,
  );
}

/// Inserta puntos en los tramos largos y quita los que están a menos de 2 m del anterior.
List<LngLat> densify(List<LngLat> line, {double step = 30}) {
  final out = <LngLat>[line.first];
  for (var i = 1; i < line.length; i++) {
    final a = out.last, b = line[i];
    final d = haversine(a.lat, a.lng, b.lat, b.lng);
    if (d < 2 && i < line.length - 1) continue;
    final n = (d / step).floor();
    for (var k = 1; k <= n; k++) {
      final t = k / (n + 1);
      out.add(LngLat(a.lng + (b.lng - a.lng) * t, a.lat + (b.lat - a.lat) * t));
    }
    out.add(b);
  }
  return out;
}

/// Rellena las altitudes que faltan interpolando entre las conocidas (o con la más cercana
/// en los extremos). Sin ninguna conocida, todo queda en 0.
List<double> fillGaps(List<double?> raw) {
  final known = [
    for (var i = 0; i < raw.length; i++)
      if (raw[i] != null) i,
  ];
  if (known.isEmpty) return List.filled(raw.length, 0);
  return [
    for (var i = 0; i < raw.length; i++) raw[i] ?? _interpolate(raw, known, i),
  ];
}

double _interpolate(List<double?> raw, List<int> known, int i) {
  final after = known.firstWhere((k) => k > i, orElse: () => -1);
  final before = known.lastWhere((k) => k < i, orElse: () => -1);
  if (before == -1) return raw[after]!;
  if (after == -1) return raw[before]!;
  final t = (i - before) / (after - before);
  return raw[before]! + (raw[after]! - raw[before]!) * t;
}

/// Desnivel positivo: suaviza el ruido del relieve y solo cuenta subidas de 5 m o más.
double elevationGain(List<double> e) => _climb(e, up: true);

/// Desnivel negativo, con el mismo criterio que [elevationGain].
double elevationLoss(List<double> e) => _climb(e, up: false);

double _climb(List<double> e, {required bool up}) {
  if (e.length < 2) return 0;
  const window = 2, threshold = 5.0;
  final smooth = [
    for (var i = 0; i < e.length; i++)
      _mean(
        e.sublist(math.max(0, i - window), math.min(e.length, i + window + 1)),
      ),
  ];
  var total = 0.0, ref = smooth.first;
  for (final v in smooth.skip(1)) {
    final diff = up ? v - ref : ref - v;
    if (diff >= threshold) {
      total += diff;
      ref = v;
    } else if (diff <= -threshold) {
      ref = v; // cambió de sentido: nueva referencia
    }
  }
  return total;
}

double _mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;

/// Un tramo de la ruta, en metros desde la salida, y su pendiente más fuerte.
class Stretch {
  const Stretch(this.from, this.to, this.maxPct);
  final double from, to, maxPct;
  double get length => to - from;
}

/// Pendiente (en %) desde la cual se avisa que un tramo es muy empinado.
const steepThresholdPct = 40.0;

/// Tramos seguidos con [thresholdPct] % de pendiente o más (subiendo o bajando), medida sobre
/// ventanas de [window] metros para no exagerar por un par de puntos muy juntos. El relieve
/// descargado suaviza (~30 m por píxel): un tramo que aquí no sale puede ser más duro en la realidad.
List<Stretch> steepStretches(
  TrailRoute r, {
  double thresholdPct = steepThresholdPct,
  double window = 100,
}) {
  final out = <Stretch>[];
  double? from;
  var end = 0.0, peak = 0.0;
  void close() {
    if (from == null) return;
    if (out.isNotEmpty && from! <= out.last.to + 1e-6) {
      final last = out.removeLast();
      out.add(Stretch(last.from, end, math.max(last.maxPct, peak)));
    } else {
      out.add(Stretch(from!, end, peak));
    }
    from = null;
    peak = 0;
  }

  for (var m = 0.0; m + window <= r.totalMeters; m += window / 2) {
    final s = r.slopeAt(m, window: window).abs();
    if (s >= thresholdPct) {
      from ??= m;
      peak = math.max(peak, s);
      end = m + window;
    } else {
      close();
    }
  }
  close();
  return out;
}

/// Pendiente máxima (en %) sobre tramos de al menos [window] metros, para no exagerar
/// por un par de puntos muy juntos.
double maxSlope(TrailRoute r, {double window = 100}) {
  var best = 0.0;
  for (var m = 0.0; m + window <= r.totalMeters; m += window / 2) {
    best = math.max(best, r.slopeAt(m, window: window).abs());
  }
  return best;
}
