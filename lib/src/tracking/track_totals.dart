import 'track.dart';

/// Cifras sumadas de varios recorridos terminados.
class TrackTotals {
  TrackTotals.of(Iterable<Track> tracks) {
    for (final t in tracks) {
      count++;
      meters += t.summary.meters;
      gain += t.summary.gain;
      moving += t.summary.moving;
      final alt = t.summary.maxAltitude;
      if (alt != null && (maxAltitude == null || alt > maxAltitude!)) {
        maxAltitude = alt;
        highest = t;
      }
    }
  }

  int count = 0;
  double meters = 0;
  double gain = 0;
  Duration moving = Duration.zero;
  double? maxAltitude;

  /// El recorrido donde se alcanzó la altitud máxima.
  Track? highest;
}

/// Resumen personal: semana, mes, histórico y desnivel de las últimas semanas.
/// Solo cuenta recorridos terminados; uno en curso aún no tiene cifras finales.
class ActivitySummary {
  ActivitySummary(Iterable<Track> tracks, {required DateTime now}) {
    final done = tracks.where((t) => t.status == TrackStatus.finished).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final today = DateTime(now.year, now.month, now.day);
    // La semana empieza en lunes, como en el calendario de México
    weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(now.year, now.month);
    bool from(Track t, DateTime start) => !t.startedAt.isBefore(start);

    week = TrackTotals.of(done.where((t) => from(t, weekStart)));
    month = TrackTotals.of(done.where((t) => from(t, monthStart)));
    all = TrackTotals.of(done);
    recent = done.take(3).toList();
    weeklyGain = [
      for (var i = weeks - 1; i >= 0; i--)
        TrackTotals.of(
          done.where((t) {
            final start = _addDays(weekStart, -7 * i);
            return from(t, start) && t.startedAt.isBefore(_addDays(start, 7));
          }),
        ).gain,
    ];
  }

  /// Semanas que muestra la gráfica de desnivel.
  static const weeks = 8;

  late final DateTime weekStart;
  late final TrackTotals week;
  late final TrackTotals month;
  late final TrackTotals all;
  late final List<Track> recent;

  /// Desnivel positivo por semana, de la más antigua a la actual.
  late final List<double> weeklyGain;

  // Sumar días por calendario (no por 24 h) para no desfasarse con el horario de verano
  static DateTime _addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);
}
