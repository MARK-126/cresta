import 'dart:math' as math;

/// Una ruta de senderismo con su perfil de elevación ya muestreado.
class TrailRoute {
  TrailRoute({
    required this.id,
    required this.name,
    required this.summary,
    required this.coordinates,
    required this.distances,
    required this.elevations,
    required this.gain,
    required this.source,
  }) : assert(
         coordinates.length == distances.length &&
             distances.length == elevations.length,
       );

  factory TrailRoute.fromJson(Map<String, dynamic> json) {
    List<double> nums(String key) =>
        (json[key] as List).map((v) => (v as num).toDouble()).toList();
    return TrailRoute(
      id: json['id'] as String,
      name: json['name'] as String,
      summary: json['summary'] as String,
      coordinates: [
        for (final p in json['coordinates'] as List) LngLat.fromJson(p as List),
      ],
      distances: nums('distances'),
      elevations: nums('elevations'),
      gain: (json['gain'] as num).toDouble(),
      source: json['source'] as String? ?? '',
    );
  }

  final String id;
  final String name;
  final String summary;
  final List<LngLat> coordinates;

  /// Distancia acumulada en metros para cada punto.
  final List<double> distances;

  /// Elevación en metros para cada punto.
  final List<double> elevations;

  /// Desnivel positivo acumulado (suavizado) en metros.
  final double gain;
  final String source;

  double get totalMeters => distances.last;
  double get maxElevation => elevations.reduce(math.max);
  double get minElevation => elevations.reduce(math.min);
  double get endElevation => elevations.last;

  /// Tiempo estimado con la regla de Naismith: 4 km/h más 1 h por cada 400 m de subida
  /// (más conservadora que los 600 m clásicos, por la altitud).
  Duration get estimatedTime {
    final hours = totalMeters / 1000 / 4 + gain / 400;
    return Duration(minutes: (hours * 60).round());
  }

  /// Punto y elevación interpolados a [meters] del inicio.
  RoutePoint along(double meters) {
    final m = meters.clamp(0, totalMeters).toDouble();
    var i = 1;
    while (i < distances.length - 1 && distances[i] < m) {
      i++;
    }
    final span = math.max(1.0, distances[i] - distances[i - 1]);
    final t = ((m - distances[i - 1]) / span).clamp(0.0, 1.0);
    final a = coordinates[i - 1];
    final b = coordinates[i];
    return RoutePoint(
      meters: m,
      position: LngLat(
        a.lng + (b.lng - a.lng) * t,
        a.lat + (b.lat - a.lat) * t,
      ),
      elevation: elevations[i - 1] + (elevations[i] - elevations[i - 1]) * t,
    );
  }

  /// Pendiente media en porcentaje en los [window] metros siguientes a [meters].
  double slopeAt(double meters, {double window = 200}) {
    final a = along(meters);
    final b = along(meters + window);
    final run = b.meters - a.meters;
    if (run <= 0) return 0;
    return (b.elevation - a.elevation) / run * 100;
  }
}

class LngLat {
  const LngLat(this.lng, this.lat);

  /// Desde un par GeoJSON `[lng, lat]`.
  factory LngLat.fromJson(List pair) =>
      LngLat((pair[0] as num).toDouble(), (pair[1] as num).toDouble());

  final double lng;
  final double lat;

  @override
  String toString() => 'LngLat($lng, $lat)';
}

class RoutePoint {
  const RoutePoint({
    required this.meters,
    required this.position,
    required this.elevation,
  });
  final double meters;
  final LngLat position;
  final double elevation;
}
