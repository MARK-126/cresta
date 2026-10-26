import '../data/trail_route.dart';
import '../tracking/track.dart' show haversine;
import 'planned_route.dart';
import 'route_profile.dart';

/// Una parada de la ruta en orden: salida, puntos de interés y llegada.
class LedgerStop {
  LedgerStop({
    required this.name,
    required this.meters,
    required this.elevation,
    required this.eta,
    this.poi,
    this.offRoute = 0,
  });

  final String name;

  /// Distancia desde la salida, medida sobre la ruta.
  final double meters;
  final double elevation;

  /// Tiempo estimado desde la salida (misma regla que [TrailRoute.estimatedTime]).
  final Duration eta;

  /// Null para la salida y la llegada.
  final Poi? poi;

  /// Qué tan lejos de la ruta está el punto de interés, en metros.
  final double offRoute;
}

/// Salida, puntos de interés ordenados por dónde caen en la ruta, y llegada.
List<LedgerStop> routeLedger(PlannedRoute route) {
  final r = route.profile;
  LedgerStop at(String name, int i, {Poi? poi, double off = 0}) => LedgerStop(
    name: name,
    meters: r.distances[i],
    elevation: r.elevations[i],
    eta: _etaAt(r, i),
    poi: poi,
    offRoute: off,
  );
  final stops = <LedgerStop>[
    for (final poi in route.pois)
      if (_nearest(r, poi.at) case (final i, final d))
        at(poi.name, i, poi: poi, off: d),
  ]..sort((a, b) => a.meters.compareTo(b.meters));
  return [at('Salida', 0), ...stops, at('Llegada', r.coordinates.length - 1)];
}

(int, double) _nearest(TrailRoute r, LngLat p) {
  var best = 0;
  var bestD = double.infinity;
  for (var i = 0; i < r.coordinates.length; i++) {
    final c = r.coordinates[i];
    final d = haversine(p.lat, p.lng, c.lat, c.lng);
    if (d < bestD) {
      bestD = d;
      best = i;
    }
  }
  return (best, bestD);
}

Duration _etaAt(TrailRoute r, int i) {
  final gain = i == 0 ? 0.0 : elevationGain(r.elevations.sublist(0, i + 1));
  final hours = r.distances[i] / 1000 / 4 + gain / 400;
  return Duration(minutes: (hours * 60).round());
}
