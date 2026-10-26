import 'package:flutter/foundation.dart';

import '../data/trail_route.dart';
import 'planned_route.dart';
import 'route_profile.dart';

/// Busca un camino por senderos entre dos puntos, o null si no lo hay en el mapa visible.
typedef SnapLeg = Future<List<LngLat>?> Function(LngLat from, LngLat to);

enum _Step { point, poi }

/// Estado del planificador: los puntos que toca el usuario, los tramos entre ellos y los
/// puntos de interés. Recalcula el perfil después de cada cambio.
class RoutePlanner extends ChangeNotifier {
  RoutePlanner({
    required this.snap,
    required this.elevation,
    PlannedRoute? initial,
  }) {
    if (initial == null) return;
    waypoints.addAll(initial.waypoints);
    legs.addAll(initial.legs);
    snapped.addAll(initial.snapped);
    pois.addAll(initial.pois);
    origin = initial.origin;
    _history.addAll([
      for (var i = 0; i < initial.legs.length; i++) _Step.point,
      for (final _ in initial.pois) _Step.poi,
    ]);
    preview = initial.profile;
  }

  final SnapLeg snap;
  final ElevationAt elevation;

  final waypoints = <LngLat>[];
  final legs = <List<LngLat>>[];
  final snapped = <bool>[];
  final pois = <Poi>[];
  RouteOrigin origin = RouteOrigin.planner;

  /// Ajustar los tramos nuevos a los senderos del mapa.
  bool snapToTrails = true;

  /// Perfil de lo trazado hasta ahora (null si aún no hay un tramo).
  TrailRoute? preview;

  /// Aviso para el usuario sobre el último tramo (p. ej. no encontró sendero).
  String? notice;

  bool busy = false;
  final _history = <_Step>[];
  int _generation = 0;

  bool get canUndo => _history.isNotEmpty || waypoints.isNotEmpty;
  bool get canSave => legs.isNotEmpty && preview != null && !busy;
  bool get isEmpty => waypoints.isEmpty && pois.isEmpty;

  /// Línea completa (todos los tramos unidos).
  List<LngLat> get line => PlannedRoute.joinLegs(legs);

  void setSnap(bool on) {
    snapToTrails = on;
    notifyListeners();
  }

  /// Agrega un punto de paso; si ya hay uno antes, calcula el tramo hasta él.
  Future<void> addPoint(LngLat p) async {
    if (busy) return;
    notice = null;
    if (waypoints.isEmpty) {
      waypoints.add(p);
      notifyListeners();
      return;
    }
    busy = true;
    notifyListeners();
    final from = waypoints.last;
    List<LngLat>? path;
    if (snapToTrails) {
      path = await snap(from, p);
      if (path == null) {
        notice = 'No encontré un sendero entre esos puntos en lo que se ve del mapa: el tramo va en línea recta.';
      }
    }
    waypoints.add(p);
    legs.add(path ?? [from, p]);
    snapped.add(path != null);
    _history.add(_Step.point);
    busy = false;
    await _recompute();
  }

  void addPoi(Poi poi) {
    pois.add(poi);
    _history.add(_Step.poi);
    notifyListeners();
  }

  void removePoi(Poi poi) {
    final i = pois.indexOf(poi);
    if (i < 0) return;
    pois.removeAt(i);
    // Quita del historial la entrada que le corresponde (la i-ésima de tipo poi)
    var seen = -1;
    for (var k = 0; k < _history.length; k++) {
      if (_history[k] == _Step.poi && ++seen == i) {
        _history.removeAt(k);
        break;
      }
    }
    notifyListeners();
  }

  /// Deshace lo último: un punto de paso (con su tramo) o un punto de interés.
  Future<void> undo() async {
    if (busy) return;
    notice = null;
    if (_history.isEmpty) {
      if (waypoints.length == 1) waypoints.clear(); // el punto de salida
      notifyListeners();
      return;
    }
    if (_history.removeLast() == _Step.poi) {
      pois.removeLast();
      notifyListeners();
      return;
    }
    waypoints.removeLast();
    legs.removeLast();
    snapped.removeLast();
    await _recompute();
  }

  /// Invierte el sentido (p. ej. para planear el regreso).
  Future<void> reverse() async {
    if (legs.isEmpty || busy) return;
    final w = waypoints.reversed.toList();
    final l = [for (final leg in legs.reversed) leg.reversed.toList()];
    final s = snapped.reversed.toList();
    waypoints
      ..clear()
      ..addAll(w);
    legs
      ..clear()
      ..addAll(l);
    snapped
      ..clear()
      ..addAll(s);
    await _recompute();
  }

  void clear() {
    waypoints.clear();
    legs.clear();
    snapped.clear();
    pois.clear();
    _history.clear();
    preview = null;
    notice = null;
    busy = false;
    origin = RouteOrigin.planner;
    _generation++;
    notifyListeners();
  }

  Future<void> _recompute() async {
    final gen = ++_generation;
    if (legs.isEmpty) {
      preview = null;
      notifyListeners();
      return;
    }
    busy = true;
    notifyListeners();
    final p = await buildProfile(
      line: line,
      elevation: elevation,
      id: 'plan',
      name: 'Ruta',
      source: 'Cresta',
    );
    // Si hubo otro cambio mientras se calculaba, este resultado ya no sirve
    if (gen != _generation) return;
    preview = p;
    busy = false;
    notifyListeners();
  }

  /// La ruta lista para guardar.
  PlannedRoute toRoute(String name) {
    final p = preview!;
    return PlannedRoute(
      name: name,
      waypoints: List.of(waypoints),
      legs: [for (final l in legs) List.of(l)],
      snapped: List.of(snapped),
      pois: List.of(pois),
      profile: TrailRoute(
        id: 'route',
        name: name,
        summary: p.summary,
        coordinates: p.coordinates,
        distances: p.distances,
        elevations: p.elevations,
        gain: p.gain,
        source: switch (origin) {
          RouteOrigin.planner => 'Planeada en Cresta',
          RouteOrigin.gpx => 'Importada de GPX',
          RouteOrigin.kml => 'Importada de KML',
        },
      ),
      origin: origin,
    );
  }
}
