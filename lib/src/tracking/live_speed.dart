import 'track.dart';
import 'track_recorder.dart' show GpsFix;

/// Lecturas más viejas que esto no dicen tu velocidad actual (GPS perdido, en pausa).
const liveSpeedMaxAge = Duration(seconds: 30);

/// Por debajo de esto el GPS "baila" estando quieto: se muestra 0.
const _stillKmh = 0.8;

/// Tu velocidad actual en km/h, o null si no se sabe.
///
/// La del GPS (efecto Doppler) es la más precisa; si el teléfono no la entrega, se calcula
/// con los dos últimos puntos del recorrido (si son del mismo tramo y recientes).
double? liveSpeedKmh(GpsFix? fix, List<TrackPoint> points, DateTime now) {
  if (fix == null || now.difference(fix.time) > liveSpeedMaxAge) return null;
  double? kmh;
  final s = fix.speed;
  if (s != null && s >= 0) {
    kmh = s * 3.6;
  } else if (points.length >= 2) {
    final a = points[points.length - 2], b = points.last;
    final dt = b.time.difference(a.time).inMilliseconds / 1000;
    if (a.segment == b.segment &&
        dt > 0 &&
        now.difference(b.time) <= liveSpeedMaxAge) {
      kmh = haversine(a.lat, a.lng, b.lat, b.lng) / dt * 3.6;
    }
  }
  if (kmh == null) return null;
  return kmh < _stillKmh ? 0 : kmh;
}
