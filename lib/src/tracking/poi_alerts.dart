import '../data/trail_route.dart';
import '../routes/planned_route.dart';
import 'route_progress.dart';
import 'track.dart' show haversine;
import 'track_recorder.dart';
import 'turnaround_alerts.dart' show AlertSink;

/// A qué distancia se avisa de un punto de interés. Los de seguridad, antes: hay que
/// decidir (punto de no retorno) o prepararse (peligro) antes de llegar.
double poiAlertMeters(PoiKind kind) => switch (kind) {
  PoiKind.noReturn || PoiKind.danger => 300,
  _ => 150,
};

/// Un punto de interés más adelante en la ruta.
class PoiAhead {
  const PoiAhead(this.poi, this.meters);
  final Poi poi;

  /// Metros por la ruta desde donde estás.
  final double meters;
}

/// Los puntos de interés a más de esto de la ruta no se cuentan como "por delante".
const _maxOffRoute = 300.0;

/// El próximo punto de interés por delante sobre la ruta, o null si no queda ninguno.
PoiAhead? nextPoiAhead(TrailRoute route, List<Poi> pois, double metersAlong) {
  PoiAhead? best;
  for (final p in pois) {
    final at = RouteProgress.of(route, p.at.lng, p.at.lat);
    if (at.offRoute > _maxOffRoute) continue;
    final ahead = at.metersAlong - metersAlong;
    // Unos metros atrás todavía cuenta: lo estás pasando
    if (ahead < -20) continue;
    if (best == null || ahead < best.meters) {
      best = PoiAhead(p, ahead < 0 ? 0 : ahead);
    }
  }
  return best;
}

/// El punto de interés más cercano dentro de su distancia de aviso, o null.
(Poi, double)? nearPoi(List<Poi> pois, double lat, double lng) {
  (Poi, double)? best;
  for (final p in pois) {
    final d = haversine(lat, lng, p.at.lat, p.at.lng);
    if (d <= poiAlertMeters(p.kind) && (best == null || d < best.$2)) {
      best = (p, d);
    }
  }
  return best;
}

/// Texto del aviso al acercarse a un punto de interés.
(String, String) poiAlertText(Poi p, double meters) {
  // A menos de 20 m ya estás ahí (el GPS no da para más)
  final at = meters < 20 ? null : meters.round();
  final title = p.name == p.kind.label
      ? p.kind.label
      : '${p.kind.label}: ${p.name}';
  final body = switch (p.kind) {
    PoiKind.noReturn =>
      '${at == null ? 'Estás en el punto de no retorno' : 'A $at m del punto de no retorno'}. '
          'Decide ahí si sigues: revisa la hora, el clima y cómo vas.',
    PoiKind.danger =>
      '${at == null ? 'Estás en un peligro marcado en tu ruta' : 'A $at m de un peligro marcado en tu ruta'}. '
          'Avanza con cuidado.',
    PoiKind.water =>
      '${at == null ? 'Llegaste al agua' : 'A $at m del agua'}. Buen momento para rellenar.',
    _ =>
      at == null
          ? 'Llegaste a este punto de tu ruta.'
          : 'A $at m de este punto de tu ruta.',
  };
  return (title, body);
}

/// Avisa con una notificación al acercarse a cada punto de interés de la ruta, una vez por
/// recorrido. Escucha al grabador (cada lectura del GPS), como [TurnaroundAlerts].
class PoiAlerts {
  PoiAlerts({required this.recorder, required this.sink});

  /// Ids de notificación: 7200 + el número del punto.
  static const baseId = 7200;

  final TrackRecorder recorder;
  final AlertSink sink;

  String? _trackId;
  final _done = <int>{};

  void attach() => recorder.addListener(_check);
  void dispose() => recorder.removeListener(_check);

  void _check() {
    final id = recorder.isActive ? recorder.track?.id : null;
    if (id != _trackId) {
      _trackId = id;
      _done.clear();
    }
    final fix = recorder.lastFix;
    if (id == null || fix == null || recorder.pois.isEmpty) return;
    for (var i = 0; i < recorder.pois.length; i++) {
      if (_done.contains(i)) continue;
      final p = recorder.pois[i];
      final d = haversine(fix.lat, fix.lng, p.at.lat, p.at.lng);
      if (d > poiAlertMeters(p.kind)) continue;
      _done.add(i);
      final (title, body) = poiAlertText(p, d);
      sink.show(baseId + i, title, body);
    }
  }
}
