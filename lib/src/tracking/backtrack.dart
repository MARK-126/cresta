import 'dart:math' as math;

import '../data/trail_route.dart';
import '../routes/route_profile.dart' show elevationGain, fillGaps;
import 'track.dart';

/// Tu propio recorrido al revés, como ruta a seguir para volver al punto de salida.
/// Null si aún no hay recorrido (menos de dos puntos separados).
///
/// Quita los puntos a menos de [minStep] m del anterior: parado, el GPS deja una nube
/// que haría zigzaguear la guía.
TrailRoute? backtrackRoute(List<TrackPoint> points, {double minStep = 5}) {
  final kept = <TrackPoint>[];
  for (final p in points.reversed) {
    if (kept.isEmpty ||
        haversine(kept.last.lat, kept.last.lng, p.lat, p.lng) >= minStep) {
      kept.add(p);
    }
  }
  // Siempre termina justo en el punto de salida (el filtro pudo dejar uno a pocos metros)
  if (kept.length > 1 && !identical(kept.last, points.first)) {
    kept[kept.length - 1] = points.first;
  }
  if (kept.length < 2) return null;
  final distances = <double>[0];
  for (var i = 1; i < kept.length; i++) {
    final a = kept[i - 1], b = kept[i];
    distances.add(distances.last + haversine(a.lat, a.lng, b.lat, b.lng));
  }
  final elevations = fillGaps([for (final p in kept) p.altitude]);
  return TrailRoute(
    id: 'regreso',
    name: 'Regreso por tu traza',
    summary: '${(distances.last / 1000).toStringAsFixed(1)} km hasta el inicio',
    coordinates: [for (final p in kept) LngLat(p.lng, p.lat)],
    distances: distances,
    elevations: elevations,
    gain: elevationGain(elevations),
    source: 'Tu recorrido',
  );
}

/// Rumbo en grados (0 = norte, 90 = este) de a hacia b.
double bearingDeg(double lat1, double lng1, double lat2, double lng2) {
  final p1 = lat1 * math.pi / 180, p2 = lat2 * math.pi / 180;
  final dl = (lng2 - lng1) * math.pi / 180;
  final y = math.sin(dl) * math.cos(p2);
  final x =
      math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

const _points = ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO'];

/// Punto cardinal del rumbo, en español ("SO" = suroeste).
String cardinal(double deg) => _points[((deg % 360) / 45).round() % 8];
