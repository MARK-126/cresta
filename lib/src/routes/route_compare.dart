import 'dart:ui' show Color;

import '../data/trail_route.dart';
import 'route_profile.dart';

/// Colores con los que se distinguen las rutas comparadas (cian, oro, terracota del diseño).
const compareHex = ['#46eae5', '#f0bf63', '#ffa089'];

/// Cuántas rutas se comparan a la vez (uno por color).
int get maxCompared => compareHex.length;

Color compareColor(int i) =>
    Color(0xFF000000 | int.parse(compareHex[i].substring(1), radix: 16));

/// Las cifras de una ruta para ponerla al lado de otras.
class RouteStats {
  RouteStats(TrailRoute r, {this.straightMeters = 0})
    : meters = r.totalMeters,
      gain = r.gain,
      loss = elevationLoss(r.elevations),
      maxElevation = r.maxElevation,
      minElevation = r.minElevation,
      maxSlopePct = maxSlope(r),
      steepMeters = steepStretches(r).fold<double>(0, (a, t) => a + t.length),
      time = r.estimatedTime;

  final double meters;
  final double gain;
  final double loss;
  final double maxElevation;
  final double minElevation;
  final double maxSlopePct;
  final Duration time;

  /// Metros con pendiente de [steepThresholdPct] % o más.
  final double steepMeters;

  /// Metros en línea recta, sin sendero.
  final double straightMeters;

  /// Sin relieve descargado no hay desnivel ni altitudes que comparar.
  bool get hasRelief => gain > 0 || loss > 0;
}

/// Lo que se compara y se destaca (menor es mejor).
enum CompareMetric {
  distance(false),
  gain(true),
  loss(true),
  maxSlope(true),
  steep(true),
  straight(false),
  time(false);

  const CompareMetric(this.needsRelief);
  final bool needsRelief;

  double of(RouteStats s) => switch (this) {
    distance => s.meters,
    gain => s.gain,
    loss => s.loss,
    maxSlope => s.maxSlopePct,
    steep => s.steepMeters,
    straight => s.straightMeters,
    time => s.time.inMinutes.toDouble(),
  };
}

/// Índices de las rutas con el mejor valor (el menor) en [metric]. Vacío si no hay nada que
/// destacar: menos de dos rutas comparables o todas iguales. Las métricas de relieve solo
/// cuentan rutas con relieve, para que una sin datos no gane por tener ceros.
Set<int> bestRoutes(CompareMetric metric, List<RouteStats> stats) {
  final candidates = [
    for (var i = 0; i < stats.length; i++)
      if (!metric.needsRelief || stats[i].hasRelief) i,
  ];
  if (candidates.length < 2) return {};
  final values = [for (final i in candidates) metric.of(stats[i])];
  final best = values.reduce((a, b) => a < b ? a : b);
  final worst = values.reduce((a, b) => a > b ? a : b);
  if (worst - best < 1e-6) return {};
  return {
    for (final i in candidates)
      if (metric.of(stats[i]) - best < 1e-6) i,
  };
}
