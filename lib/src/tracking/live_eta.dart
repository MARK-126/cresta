import '../data/trail_route.dart' show naismith;
import 'route_progress.dart';
import 'track_stats.dart';

/// Cuánto falta y a qué hora llegas, en vivo mientras grabas.
class LiveEta {
  const LiveEta({
    required this.remaining,
    required this.arrival,
    required this.pace,
  });

  /// Tiempo en movimiento que falta (sin contar paradas).
  final Duration remaining;
  final DateTime arrival;

  /// Tu ritmo respecto a la regla de Naismith (1.2 = tardas 20 % más); null mientras no
  /// hay datos suficientes y se usa la regla tal cual.
  final double? pace;
}

/// Datos mínimos para medir tu ritmo: antes, unos minutos parado o una bajada lo
/// distorsionan demasiado.
const minPaceMoving = Duration(minutes: 15);
const minPaceMeters = 500.0;

/// Tu ritmo: tiempo real en movimiento entre el que da Naismith para lo que llevas.
/// Acotado a 0.5–2.5 para que un tramo raro no dispare la estimación.
double? paceFactor(TrackStats s) {
  if (s.moving < minPaceMoving || s.meters < minPaceMeters) return null;
  final expected = naismith(s.meters, s.gain).inSeconds;
  if (expected <= 0) return null;
  return (s.moving.inSeconds / expected).clamp(0.5, 2.5).toDouble();
}

/// Llegada al final de la ruta (o al inicio, si se regresa por la traza). Null sin ruta.
LiveEta? liveEta({
  required RouteProgress? progress,
  required TrackStats stats,
  required DateTime now,
}) {
  if (progress == null) return null;
  final base = naismith(progress.remainingMeters, progress.remainingGain);
  final pace = paceFactor(stats);
  final remaining = Duration(seconds: (base.inSeconds * (pace ?? 1)).round());
  return LiveEta(remaining: remaining, arrival: now.add(remaining), pace: pace);
}
