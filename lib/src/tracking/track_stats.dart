import 'dart:collection';
import 'dart:math' as math;

import 'track.dart';

/// Estadísticas de un recorrido, calculadas punto por punto (en vivo o al releer un recorrido).
///
/// La altitud del GPS salta varios metros entre lecturas; por eso se suaviza y el desnivel
/// solo se cuenta cuando la subida o bajada acumulada supera [hysteresis] metros.
class TrackStats {
  TrackStats({this.hysteresis = 5});

  final double hysteresis;

  double meters = 0;
  double gain = 0;
  double loss = 0;
  double? maxAltitude;
  double? minAltitude;
  Duration moving = Duration.zero;
  int points = 0;
  DateTime? first;
  DateTime? last;

  TrackPoint? _prev;
  double? _smoothAlt;
  double? _refAlt;
  final _recentAlt = Queue<(DateTime, double)>();

  /// Altitud suavizada actual.
  double? get altitude => _smoothAlt;

  /// Por debajo de esto se considera que estás detenido.
  static const _movingSpeed = 0.3; // m/s

  /// Huecos más largos (pausas, GPS perdido) no cuentan como tiempo en movimiento.
  static const _maxGap = Duration(minutes: 5);

  void add(TrackPoint p) {
    points++;
    first ??= p.time;
    last = p.time;

    final prev = _prev;
    if (prev != null && prev.segment == p.segment) {
      final d = haversine(prev.lat, prev.lng, p.lat, p.lng);
      final dt = p.time.difference(prev.time);
      meters += d;
      if (dt > Duration.zero &&
          dt <= _maxGap &&
          d / (dt.inMilliseconds / 1000) >= _movingSpeed) {
        moving += dt;
      }
    }
    _prev = p;

    final alt = p.altitude;
    if (alt == null) return;
    _smoothAlt = _smoothAlt == null ? alt : _smoothAlt! * 0.7 + alt * 0.3;
    final s = _smoothAlt!;
    maxAltitude = math.max(maxAltitude ?? s, s);
    minAltitude = math.min(minAltitude ?? s, s);
    _refAlt ??= s;
    if (s - _refAlt! >= hysteresis) {
      gain += s - _refAlt!;
      _refAlt = s;
    } else if (_refAlt! - s >= hysteresis) {
      loss += _refAlt! - s;
      _refAlt = s;
    }
    _recentAlt.add((p.time, s));
    while (_recentAlt.length > 2 &&
        p.time.difference(_recentAlt.first.$1) > const Duration(minutes: 10)) {
      _recentAlt.removeFirst();
    }
  }

  /// Velocidad vertical de los últimos ~10 minutos, en metros por hora (negativa si bajas).
  double? get verticalSpeed {
    if (_recentAlt.length < 2) return null;
    final (t0, a0) = _recentAlt.first;
    final (t1, a1) = _recentAlt.last;
    final hours = t1.difference(t0).inSeconds / 3600;
    if (hours < 2 / 60) return null; // menos de 2 minutos: no es confiable
    return (a1 - a0) / hours;
  }

  Duration get elapsed =>
      first == null || last == null ? Duration.zero : last!.difference(first!);

  TrackSummary get summary => TrackSummary(
    meters: meters,
    gain: gain,
    loss: loss,
    maxAltitude: maxAltitude,
    moving: moving,
    elapsed: elapsed,
    points: points,
  );

  static TrackStats of(Iterable<TrackPoint> points) {
    final s = TrackStats();
    points.forEach(s.add);
    return s;
  }
}
