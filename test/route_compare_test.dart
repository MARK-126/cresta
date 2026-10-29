import 'package:cresta/src/data/trail_route.dart';
import 'package:cresta/src/routes/route_compare.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ruta recta hacia el norte de [km] kilómetros que sube [climb] m (0 = sin relieve).
TrailRoute _route(double km, double climb) {
  const n = 11;
  final coords = [
    for (var i = 0; i < n; i++) LngLat(-98.6, 19.0 + km * i / (n - 1) / 111),
  ];
  return TrailRoute(
    id: 'r',
    name: 'Ruta',
    summary: '',
    coordinates: coords,
    distances: [for (var i = 0; i < n; i++) km * 1000 * i / (n - 1)],
    elevations: [for (var i = 0; i < n; i++) 3000 + climb * i / (n - 1)],
    gain: climb,
    source: 'test',
  );
}

void main() {
  test('las cifras salen del perfil de la ruta', () {
    final s = RouteStats(_route(10, 1000));
    expect(s.meters, closeTo(10000, 1));
    expect(s.gain, 1000);
    expect(s.loss, 0);
    expect(s.maxElevation, 4000);
    expect(s.minElevation, 3000);
    expect(s.maxSlopePct, closeTo(10, 0.5));
    expect(s.hasRelief, isTrue);
    expect(RouteStats(_route(5, 0)).hasRelief, isFalse);
  });

  test('destaca la mejor en cada cifra (menor es mejor)', () {
    final a = RouteStats(_route(10, 1000));
    final b = RouteStats(_route(12, 600));
    final stats = [a, b];
    expect(bestRoutes(CompareMetric.distance, stats), {0});
    expect(bestRoutes(CompareMetric.gain, stats), {1});
    expect(bestRoutes(CompareMetric.maxSlope, stats), {1});
    expect(bestRoutes(CompareMetric.time, stats), {1});
  });

  test('no destaca nada si son iguales o si no se pueden comparar', () {
    final a = RouteStats(_route(10, 500));
    final same = RouteStats(_route(10, 500));
    expect(bestRoutes(CompareMetric.distance, [a, same]), isEmpty);
    expect(bestRoutes(CompareMetric.distance, [a]), isEmpty);
    // Una ruta sin relieve no gana en desnivel por tener ceros
    final flat = RouteStats(_route(10, 0));
    expect(bestRoutes(CompareMetric.gain, [a, flat]), isEmpty);
    expect(bestRoutes(CompareMetric.distance, [a, flat]), isEmpty);
  });

  test('con un empate en lo mejor se destacan las dos', () {
    final stats = [
      RouteStats(_route(10, 800)),
      RouteStats(_route(10, 800)),
      RouteStats(_route(14, 800)),
    ];
    expect(bestRoutes(CompareMetric.distance, stats), {0, 1});
  });

  test('hay un color por ruta comparada', () {
    expect(maxCompared, 3);
    expect(compareColor(0).toARGB32(), 0xFF46EAE5);
  });
}
