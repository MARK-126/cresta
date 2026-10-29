import 'package:cresta/src/data/trail_route.dart';
import 'package:cresta/src/routes/planned_route.dart';
import 'package:cresta/src/routes/route_compare.dart';
import 'package:cresta/src/routes/route_profile.dart';
import 'package:cresta/src/tracking/track.dart' show haversine;
import 'package:flutter_test/flutter_test.dart';

/// Ruta recta al norte de 2 km, un punto cada 50 m, con la altitud que dé [elevation].
TrailRoute _route(double Function(double meters) elevation) {
  const n = 41;
  final elevations = [for (var i = 0; i < n; i++) elevation(50.0 * i)];
  return TrailRoute(
    id: 'r',
    name: 'Ruta',
    summary: '',
    coordinates: [
      for (var i = 0; i < n; i++) LngLat(-98.6, 19.0 + 50.0 * i / 111000),
    ],
    distances: [for (var i = 0; i < n; i++) 50.0 * i],
    elevations: elevations,
    gain: elevationGain(elevations),
    source: 'test',
  );
}

void main() {
  group('Tramos empinados', () {
    test('una subida suave no avisa', () {
      expect(steepStretches(_route((m) => 3000 + m * 0.15)), isEmpty);
    });

    test('un tramo de 50 % se detecta con su largo y su pendiente', () {
      // 600 m planos, 300 m al 50 %, el resto plano
      final r = _route((m) {
        if (m < 600) return 3000;
        if (m < 900) return 3000 + (m - 600) * 0.5;
        return 3150;
      });
      final s = steepStretches(r);
      expect(s.length, 1);
      expect(s.single.maxPct, closeTo(50, 2));
      expect(s.single.length, inInclusiveRange(250, 450));
      expect(s.single.from, inInclusiveRange(450, 650));
    });

    test(
      'dos tramos separados salen por separado y la bajada también cuenta',
      () {
        final r = _route((m) {
          if (m < 300) return 3000;
          if (m < 600) return 3000 + (m - 300) * 0.6; // sube 180 m
          if (m < 1200) return 3180;
          if (m < 1500) return 3180 - (m - 1200) * 0.6; // baja 180 m
          return 3000;
        });
        final s = steepStretches(r);
        expect(s.length, 2);
        expect(s.first.to, lessThan(s.last.from));
      },
    );

    test('un umbral más alto deja menos tramos', () {
      final r = _route((m) => m < 500 ? 3000 : 3000 + (m - 500) * 0.45);
      expect(steepStretches(r), isNotEmpty);
      expect(steepStretches(r, thresholdPct: 60), isEmpty);
    });
  });

  group('Sin sendero', () {
    const a = LngLat(-98.6, 19.0);
    const b = LngLat(-98.6, 19.01);
    const c = LngLat(-98.59, 19.02);
    PlannedRoute planned(List<bool> snapped) => PlannedRoute(
      name: 'R',
      waypoints: const [a, b, c],
      legs: const [
        [a, b],
        [b, c],
      ],
      snapped: snapped,
      pois: const [],
      profile: _route((m) => 3000),
    );

    test('suma solo los tramos que van en línea recta', () {
      final bc = haversine(b.lat, b.lng, c.lat, c.lng);
      final ab = haversine(a.lat, a.lng, b.lat, b.lng);
      expect(planned([true, true]).straightMeters, 0);
      expect(planned([true, false]).straightMeters, closeTo(bc, 0.01));
      expect(planned([false, false]).straightMeters, closeTo(ab + bc, 0.01));
      expect(planned([true, false]).straightLegs, 1);
    });
  });

  test('comparar: lo empinado y lo recto cuentan, y 0 contra 0 no destaca', () {
    final steepRoute = _route((m) => m < 500 ? 3000 : 3000 + (m - 500) * 0.6);
    final gentle = _route((m) => 3000 + m * 0.1);
    final stats = [
      RouteStats(steepRoute, straightMeters: 800),
      RouteStats(gentle),
    ];
    expect(stats[0].steepMeters, greaterThan(0));
    expect(stats[1].steepMeters, 0);
    expect(bestRoutes(CompareMetric.steep, stats), {1});
    expect(bestRoutes(CompareMetric.straight, stats), {1});
    expect(
      bestRoutes(CompareMetric.straight, [
        RouteStats(gentle),
        RouteStats(gentle),
      ]),
      isEmpty,
    );
  });
}
