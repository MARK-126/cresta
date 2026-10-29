import 'dart:math' as math;

import '../data/trail_route.dart';

/// Tipos de punto de interés que se marcan en la ruta.
enum PoiKind {
  water('Agua'),
  camp('Campamento'),
  shelter('Refugio'),
  summit('Cumbre'),
  noReturn('Punto de no retorno'),
  danger('Peligro'),
  other('Punto');

  const PoiKind(this.label);
  final String label;
}

/// Un punto de interés de la ruta (agua, campamento, punto de no retorno…).
class Poi {
  Poi({required this.kind, required this.at, String? name})
    : name = (name == null || name.trim().isEmpty) ? kind.label : name.trim();

  factory Poi.fromJson(Map<String, dynamic> j) => Poi(
    kind: PoiKind.values.asNameMap()[j['kind']] ?? PoiKind.other,
    at: LngLat.fromJson(j['at'] as List),
    name: j['name'] as String?,
  );

  final PoiKind kind;
  final LngLat at;
  final String name;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'name': name,
    'at': [at.lng, at.lat],
  };
}

/// De dónde salió la ruta.
enum RouteOrigin { planner, gpx, kml }

String newRouteId() =>
    'r${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${math.Random().nextInt(1 << 20).toRadixString(36)}';

/// Una ruta: los puntos que tocó el usuario, los tramos entre ellos (ajustados a senderos o
/// en línea recta), los puntos de interés y el perfil calculado. Tiene su propio [id] y puede
/// estar ligada a una expedición ([expeditionId]) o existir sola.
class PlannedRoute {
  PlannedRoute({
    String? id,
    this.expeditionId,
    required this.name,
    required this.waypoints,
    required this.legs,
    required this.snapped,
    required this.pois,
    required this.profile,
    this.origin = RouteOrigin.planner,
    DateTime? updatedAt,
  }) : assert(legs.length == snapped.length),
       id = id ?? newRouteId(),
       updatedAt = updatedAt ?? DateTime.now();

  /// [legacyExpeditionId]: en el formato anterior (una ruta por expedición, con la expedición
  /// como clave) la ruta no traía id ni expedición.
  factory PlannedRoute.fromJson(
    Map<String, dynamic> j, {
    String? legacyExpeditionId,
  }) {
    List<LngLat> line(List raw) => [
      for (final p in raw) LngLat.fromJson(p as List),
    ];
    return PlannedRoute(
      id:
          j['id'] as String? ??
          (legacyExpeditionId == null ? null : 'r-$legacyExpeditionId'),
      expeditionId: j['expeditionId'] as String? ?? legacyExpeditionId,
      name: j['name'] as String,
      waypoints: line(j['waypoints'] as List),
      legs: [for (final l in j['legs'] as List) line(l as List)],
      snapped: [for (final s in j['snapped'] as List) s as bool],
      pois: [
        for (final p in j['pois'] as List? ?? const [])
          Poi.fromJson(p as Map<String, dynamic>),
      ],
      profile: TrailRoute.fromJson(j['profile'] as Map<String, dynamic>),
      origin:
          RouteOrigin.values.asNameMap()[j['origin']] ?? RouteOrigin.planner,
      updatedAt: DateTime.tryParse('${j['updatedAt']}'),
    );
  }

  final String id;

  /// Expedición a la que pertenece; null si la ruta existe sola.
  final String? expeditionId;
  final String name;
  final List<LngLat> waypoints;

  /// Tramo i: de `waypoints[i]` a `waypoints[i + 1]`, con todos sus vértices.
  final List<List<LngLat>> legs;

  /// Si el tramo i sigue senderos del mapa (true) o es una línea recta (false).
  final List<bool> snapped;
  final List<Poi> pois;

  /// Trazo completo con distancias y altitudes: lo usan el mapa, el perfil y el grabador.
  final TrailRoute profile;
  final RouteOrigin origin;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    if (expeditionId != null) 'expeditionId': expeditionId,
    'name': name,
    'waypoints': [
      for (final w in waypoints) [w.lng, w.lat],
    ],
    'legs': [
      for (final l in legs)
        [
          for (final p in l) [p.lng, p.lat],
        ],
    ],
    'snapped': snapped,
    'pois': [for (final p in pois) p.toJson()],
    'profile': profile.toJson(),
    'origin': origin.name,
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// La misma ruta con otro nombre (también en el perfil, que es lo que muestra el mapa).
  PlannedRoute withName(String newName) => PlannedRoute(
    id: id,
    expeditionId: expeditionId,
    name: newName,
    waypoints: waypoints,
    legs: legs,
    snapped: snapped,
    pois: pois,
    profile: TrailRoute(
      id: profile.id,
      name: newName,
      summary: profile.summary,
      coordinates: profile.coordinates,
      distances: profile.distances,
      elevations: profile.elevations,
      gain: profile.gain,
      source: profile.source,
    ),
    origin: origin,
  );

  /// La misma ruta ligada a otra expedición (o a ninguna).
  PlannedRoute linkedTo(String? expedition) => PlannedRoute(
    id: id,
    expeditionId: expedition,
    name: name,
    waypoints: waypoints,
    legs: legs,
    snapped: snapped,
    pois: pois,
    profile: profile,
    origin: origin,
    updatedAt: updatedAt,
  );

  /// Une los tramos en una sola línea, sin repetir el punto donde se tocan.
  static List<LngLat> joinLegs(List<List<LngLat>> legs) {
    final out = <LngLat>[];
    for (final leg in legs) {
      for (final p in leg) {
        if (out.isNotEmpty && out.last.lng == p.lng && out.last.lat == p.lat) {
          continue;
        }
        out.add(p);
      }
    }
    return out;
  }
}
