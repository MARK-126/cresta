import 'package:cresta/src/tracking/live_speed.dart';
import 'package:cresta/src/tracking/track.dart';
import 'package:cresta/src/tracking/track_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 13, 10);
  GpsFix fix({
    double? speed,
    Duration ago = Duration.zero,
    double accuracy = 5,
  }) => GpsFix(
    time: now.subtract(ago),
    lng: -68.86,
    lat: -32.89,
    accuracy: accuracy,
    speed: speed,
  );
  TrackPoint pt(double metersNorth, int secondsAgo, {int segment = 0}) =>
      TrackPoint(
        time: now.subtract(Duration(seconds: secondsAgo)),
        lng: -68.86,
        lat: -32.89 + metersNorth / 111195,
        accuracy: 5,
        segment: segment,
      );

  test('la del GPS, en km/h', () {
    expect(liveSpeedKmh(fix(speed: 1.25), const [], now), closeTo(4.5, 0.01));
  });

  test('quieto, el GPS baila: se muestra 0', () {
    expect(liveSpeedKmh(fix(speed: 0.15), const [], now), 0);
  });

  test('sin la del GPS, con los dos últimos puntos', () {
    final pts = [pt(0, 10), pt(12.5, 0)]; // 12.5 m en 10 s = 4.5 km/h
    expect(liveSpeedKmh(fix(), pts, now), closeTo(4.5, 0.05));
    // Entre dos tramos (hubo una pausa) no se calcula
    final paused = [pt(0, 10), pt(12.5, 0, segment: 1)];
    expect(liveSpeedKmh(fix(), paused, now), isNull);
  });

  test('una lectura vieja no es tu velocidad actual', () {
    expect(
      liveSpeedKmh(
        fix(speed: 1.2, ago: const Duration(minutes: 1)),
        const [],
        now,
      ),
      isNull,
    );
    expect(liveSpeedKmh(null, const [], now), isNull);
  });

  test('con mala precisión no se cree la velocidad del GPS', () {
    // Bajo techo, ±16 m: el teléfono decía 1.1 m/s estando quieto
    expect(liveSpeedKmh(fix(speed: 1.1, accuracy: 16), const [], now), isNull);
  });
}
