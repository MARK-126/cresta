import 'track.dart';

/// Distancia recorrida hasta cada punto, en metros. Entre tramos (después de una pausa)
/// no suma: el salto no se caminó.
List<double> cumulativeMeters(List<TrackPoint> points) {
  final out = <double>[];
  for (var i = 0; i < points.length; i++) {
    if (i == 0) {
      out.add(0);
      continue;
    }
    final a = points[i - 1], b = points[i];
    out.add(
      out.last +
          (a.segment == b.segment ? haversine(a.lat, a.lng, b.lat, b.lng) : 0),
    );
  }
  return out;
}

/// Un recorrido partido para compartir: lo que se oculta al inicio, lo que se ve y lo que
/// se oculta al final. Los cortes caen entre dos puntos (se interpolan), así el recorte
/// es exacto aunque el GPS haya guardado puntos cada 20 m.
class SharedParts {
  const SharedParts(this.before, this.visible, this.after);
  final List<TrackPoint> before;
  final List<TrackPoint> visible;
  final List<TrackPoint> after;
}

TrackPoint _lerp(TrackPoint a, TrackPoint b, double t) => TrackPoint(
  time: a.time.add(
    Duration(
      milliseconds: (b.time.difference(a.time).inMilliseconds * t).round(),
    ),
  ),
  lng: a.lng + (b.lng - a.lng) * t,
  lat: a.lat + (b.lat - a.lat) * t,
  altitude: a.altitude == null || b.altitude == null
      ? a.altitude ?? b.altitude
      : a.altitude! + (b.altitude! - a.altitude!) * t,
  accuracy: a.accuracy,
  speed: a.speed,
  segment: a.segment,
);

/// El punto a [m] metros del inicio (interpolado) y el índice del primer punto después.
(TrackPoint, int) _at(List<TrackPoint> pts, List<double> d, double m) {
  var i = 1;
  while (i < pts.length - 1 && d[i] < m) {
    i++;
  }
  final span = d[i] - d[i - 1];
  final t = span <= 0 ? 1.0 : ((m - d[i - 1]) / span).clamp(0.0, 1.0);
  return (_lerp(pts[i - 1], pts[i], t), i);
}

/// Parte [points] ocultando los primeros [hideStart] y los últimos [hideEnd] metros.
SharedParts splitForSharing(
  List<TrackPoint> points,
  double hideStart,
  double hideEnd,
) {
  if (points.length < 2 || (hideStart <= 0 && hideEnd <= 0)) {
    return SharedParts(const [], points, const []);
  }
  final d = cumulativeMeters(points);
  final total = d.last;
  final from = hideStart.clamp(0.0, total);
  final to = (total - hideEnd).clamp(from, total);
  final (a, ia) = _at(points, d, from);
  final (b, ib) = _at(points, d, to);
  return SharedParts(
    [...points.take(ia), if (from > 0) a],
    [a, for (var i = ia; i < ib; i++) points[i], b],
    [if (to < total) b, ...points.skip(ib)],
  );
}

/// Lo que se comparte de un recorrido (video, GPX, imagen): sin el recorte que eligió el
/// usuario para no mostrar dónde empieza y termina (su casa, por ejemplo).
List<TrackPoint> forSharing(Track t, List<TrackPoint> points) =>
    splitForSharing(points, t.hideStart, t.hideEnd).visible;
