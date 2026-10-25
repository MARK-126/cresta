import 'dart:convert';
import 'dart:io';

import 'package:cresta/src/data/trail_route.dart';
import 'package:flutter_test/flutter_test.dart';

TrailRoute _ramp() => TrailRoute(
  id: 't',
  name: 'Rampa',
  summary: '',
  coordinates: const [LngLat(0, 0), LngLat(0, 0.01), LngLat(0, 0.02)],
  distances: [0, 1000, 2000],
  elevations: [3000, 3100, 3100],
  gain: 100,
  source: '',
);

void main() {
  group('TrailRoute', () {
    test('interpola posición y elevación', () {
      final p = _ramp().along(500);
      expect(p.elevation, closeTo(3050, 1e-9));
      expect(p.position.lat, closeTo(0.005, 1e-12));
    });

    test('limita los metros al largo de la ruta', () {
      final r = _ramp();
      expect(r.along(-50).meters, 0);
      expect(r.along(99999).meters, 2000);
      expect(r.along(99999).elevation, 3100);
    });

    test('pendiente en porcentaje', () {
      final r = _ramp();
      expect(r.slopeAt(0), closeTo(10, 1e-9));
      expect(r.slopeAt(1500), closeTo(0, 1e-9));
    });

    test('tiempo estimado con Naismith (4 km/h + 1 h por 400 m)', () {
      // 2 km → 30 min; 100 m → 15 min
      expect(_ramp().estimatedTime, const Duration(minutes: 45));
    });

    test('la ruta incluida en assets es coherente', () {
      final json = jsonDecode(
        File('assets/data/arista_del_sol.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final r = TrailRoute.fromJson(json);
      expect(r.totalMeters, inInclusiveRange(11000, 13000));
      expect(r.maxElevation, greaterThan(5100));
      expect(
        r.coordinates.first.lat,
        lessThan(r.coordinates.last.lat),
      ); // de Paso de Cortés hacia el norte
    });
  });
}
