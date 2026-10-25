import 'dart:math' as math;

import '../data/trail_route.dart';

/// Dónde estás respecto a la ruta planeada.
class RouteProgress {
  const RouteProgress({
    required this.metersAlong,
    required this.offRoute,
    required this.remainingMeters,
    required this.remainingGain,
  });

  /// Metros recorridos sobre la ruta (proyección del punto más cercano).
  final double metersAlong;

  /// Distancia a la ruta en metros.
  final double offRoute;
  final double remainingMeters;

  /// Desnivel que falta subir hasta el final de la ruta.
  final double remainingGain;

  /// A partir de esta distancia se avisa que te saliste de la ruta.
  static const offRouteLimit = 80.0;

  bool get isOffRoute => offRoute > offRouteLimit;

  /// Proyecta [lng], [lat] sobre la ruta. Usa coordenadas planas locales: el error es despreciable
  /// a escala de un sendero.
  static RouteProgress of(TrailRoute route, double lng, double lat) {
    final kx = 111320 * math.cos(lat * math.pi / 180), ky = 110570.0;
    var best = double.infinity, bestAlong = 0.0;
    final c = route.coordinates, d = route.distances;
    for (var i = 1; i < c.length; i++) {
      final ax = (c[i - 1].lng - lng) * kx, ay = (c[i - 1].lat - lat) * ky;
      final bx = (c[i].lng - lng) * kx, by = (c[i].lat - lat) * ky;
      final vx = bx - ax, vy = by - ay;
      final len2 = vx * vx + vy * vy;
      final t = len2 == 0 ? 0.0 : (-(ax * vx + ay * vy) / len2).clamp(0.0, 1.0);
      final px = ax + vx * t, py = ay + vy * t;
      final dist = math.sqrt(px * px + py * py);
      if (dist < best) {
        best = dist;
        bestAlong = d[i - 1] + (d[i] - d[i - 1]) * t;
      }
    }
    // Subida pendiente desde el punto proyectado, con el mismo umbral de 5 m que las
    // estadísticas del recorrido para no sumar el ruido del relieve
    var remainingGain = 0.0;
    var ref = route.along(bestAlong).elevation;
    for (var i = 0; i < d.length; i++) {
      if (d[i] <= bestAlong) continue;
      final e = route.elevations[i];
      if (e - ref >= 5) {
        remainingGain += e - ref;
        ref = e;
      } else if (ref - e >= 5) {
        ref = e;
      }
    }
    return RouteProgress(
      metersAlong: bestAlong,
      offRoute: best,
      remainingMeters: route.totalMeters - bestAlong,
      remainingGain: remainingGain,
    );
  }
}
