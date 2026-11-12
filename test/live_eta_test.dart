import 'package:cresta/src/data/trail_route.dart';
import 'package:cresta/src/tracking/live_eta.dart';
import 'package:cresta/src/tracking/route_progress.dart';
import 'package:cresta/src/tracking/track.dart';
import 'package:cresta/src/tracking/track_stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// Caminata de [km] al norte, subiendo [gain] m, en [minutes] min de puro movimiento.
TrackStats _walked(double km, double gain, int minutes) {
  final s = TrackStats();
  final n = (km * 1000 / 25).round();
  final t0 = DateTime(2026, 11, 12, 8);
  for (var i = 0; i <= n; i++) {
    s.add(
      TrackPoint(
        time: t0.add(Duration(milliseconds: minutes * 60000 * i ~/ n)),
        lng: -98.65,
        lat: 19.10 + i * 25 / 111195,
        altitude: 3500 + gain * i / n,
        accuracy: 5,
      ),
    );
  }
  return s;
}

void main() {
  const progress = RouteProgress(
    metersAlong: 2000,
    offRoute: 0,
    remainingMeters: 4000,
    remainingGain: 400,
  );
  final now = DateTime(2026, 11, 12, 10);

  test('Naismith: 4 km/h más 1 h por cada 400 m de subida', () {
    expect(naismith(4000, 0), const Duration(hours: 1));
    expect(naismith(4000, 400), const Duration(hours: 2));
    expect(naismith(0, 200), const Duration(minutes: 30));
  });

  test('sin datos suficientes se usa la regla tal cual', () {
    expect(paceFactor(TrackStats()), isNull);
    expect(paceFactor(_walked(0.3, 0, 10)), isNull, reason: 'menos de 500 m');
    final eta = liveEta(progress: progress, stats: TrackStats(), now: now)!;
    expect(eta.pace, isNull);
    expect(eta.remaining, const Duration(hours: 2));
    expect(eta.arrival, DateTime(2026, 11, 12, 12));
  });

  test('a tu ritmo: si vas más lento que la regla, tardas más', () {
    // 2 km y 200 m de subida: Naismith 1 h; caminados en 1 h 30
    final slow = _walked(2, 200, 90);
    expect(paceFactor(slow), closeTo(1.5, 0.05));
    final eta = liveEta(progress: progress, stats: slow, now: now)!;
    expect(eta.remaining.inMinutes, closeTo(180, 6));
    // Más rápido que la regla
    expect(paceFactor(_walked(2, 200, 45)), closeTo(0.75, 0.05));
    // Muy lento (3.3 veces la regla, aún en movimiento) se acota a 2.5
    expect(paceFactor(_walked(2, 0, 100)), 2.5);
    // Tan lento que no cuenta como movimiento: no hay ritmo que medir
    expect(paceFactor(_walked(2, 0, 400)), isNull);
  });

  test('sin ruta no hay llegada', () {
    expect(liveEta(progress: null, stats: TrackStats(), now: now), isNull);
  });
}
