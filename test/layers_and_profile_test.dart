import 'package:cresta/src/data/trail_route.dart';
import 'package:cresta/src/map/map_layers.dart';
import 'package:cresta/src/ui/elevation_profile.dart';
import 'package:cresta/src/ui/format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cada modo enciende sus capas', () {
    final m = layerPreset(AppMode.mountain);
    final c = layerPreset(AppMode.civil);
    expect(m['route'], isTrue);
    expect(m['zones'], isFalse);
    expect(c['zones'], isTrue);
    expect(c['route'], isFalse);
    expect(m.keys.toSet(), mapLayers.map((l) => l.id).toSet());
  });

  test('formatos', () {
    expect(fmtInt(5207), '5,207');
    expect(fmtInt(1234567), '1,234,567');
    expect(fmtKm(12104.8), '12.1');
    expect(fmtDuration(const Duration(minutes: 427)), '7 h 07');
    expect(fmtAgo(65), 'hace 1 h 05');
  });

  testWidgets('el perfil reporta los metros al deslizar', (tester) async {
    final route = TrailRoute(
      id: 't',
      name: 'x',
      summary: '',
      coordinates: const [LngLat(0, 0), LngLat(0, 1)],
      distances: [0, 10000],
      elevations: [3600, 5200],
      gain: 1600,
      source: '',
    );
    double? got;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(width: 300, child: ElevationProfile(route: route, onScrub: (m) => got = m))),
    ));
    await tester.tapAt(tester.getTopLeft(find.byType(ElevationProfile)) + const Offset(299, 60));
    expect(got, closeTo(10000, 1));
    await tester.tapAt(tester.getTopLeft(find.byType(ElevationProfile)) + const Offset(0, 60));
    expect(got, 0);
  });
}
