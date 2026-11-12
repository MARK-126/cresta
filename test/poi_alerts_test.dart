import 'dart:async';
import 'dart:io';

import 'package:cresta/src/data/trail_route.dart';
import 'package:cresta/src/routes/planned_route.dart';
import 'package:cresta/src/tracking/poi_alerts.dart';
import 'package:cresta/src/tracking/track_recorder.dart';
import 'package:cresta/src/tracking/track_store.dart';
import 'package:cresta/src/tracking/turnaround_alerts.dart';
import 'package:flutter_test/flutter_test.dart';

const _mLat = 1 / 111195; // grados de latitud por metro (haversine)

LngLat _north(double m) => LngLat(-98.65, 19.10 + m * _mLat);

class _Sink implements AlertSink {
  final shown = <(int, String, String)>[];
  @override
  Future<void> show(int id, String title, String body) async =>
      shown.add((id, title, body));
  @override
  Future<void> cancel(int id) async {}
}

void main() {
  // Ruta recta de 2 km al norte
  final route = TrailRoute(
    id: 'r',
    name: 'Recta',
    summary: '',
    coordinates: [for (var m = 0.0; m <= 2000; m += 100) _north(m)],
    distances: [for (var m = 0.0; m <= 2000; m += 100) m],
    elevations: List.filled(21, 3500),
    gain: 0,
    source: '',
  );
  final water = Poi(kind: PoiKind.water, at: _north(500), name: 'Arroyo');
  final noReturn = Poi(kind: PoiKind.noReturn, at: _north(1500));
  final farAway = Poi(
    kind: PoiKind.camp,
    at: LngLat(-98.64, 19.10 + 800 * _mLat), // ~1 km al este de la ruta
  );
  final pois = [water, noReturn, farAway];

  test('los puntos de seguridad se avisan antes', () {
    expect(poiAlertMeters(PoiKind.water), 150);
    expect(poiAlertMeters(PoiKind.noReturn), 300);
    expect(poiAlertMeters(PoiKind.danger), 300);
  });

  test('el próximo punto por delante, sobre la ruta', () {
    final a = nextPoiAhead(route, pois, 100)!;
    expect(a.poi, water);
    expect(a.meters, closeTo(400, 5));
    // Pasando el agua (10 m atrás) todavía cuenta; ya lejos, sigue el de no retorno
    expect(nextPoiAhead(route, pois, 510)!.poi, water);
    final b = nextPoiAhead(route, pois, 700)!;
    expect(b.poi, noReturn);
    expect(b.meters, closeTo(800, 5));
    // El campamento a 1 km de la ruta no cuenta; al final no queda nada
    expect(nextPoiAhead(route, pois, 1600), isNull);
  });

  test('cerca de un punto, según su distancia de aviso', () {
    final p200 = _north(300); // a 200 m del agua: fuera de sus 150 m
    expect(nearPoi(pois, p200.lat, p200.lng), isNull);
    final p100 = _north(400);
    expect(nearPoi(pois, p100.lat, p100.lng)!.$1, water);
    final p250 = _north(
      1250,
    ); // a 250 m del punto de no retorno: dentro de sus 300 m
    expect(nearPoi(pois, p250.lat, p250.lng)!.$1, noReturn);
  });

  test('textos de los avisos', () {
    expect(poiAlertText(water, 120), (
      'Agua: Arroyo',
      'A 120 m del agua. Buen momento para rellenar.',
    ));
    expect(poiAlertText(water, 5).$2, startsWith('Llegaste al agua.'));
    expect(poiAlertText(noReturn, 280).$1, 'Punto de no retorno');
    expect(poiAlertText(noReturn, 280).$2, contains('Decide ahí si sigues'));
    expect(
      poiAlertText(noReturn, 3).$2,
      startsWith('Estás en el punto de no retorno.'),
    );
  });

  test('avisa una vez por punto al acercarse, mientras se graba', () async {
    final tmp = Directory.systemTemp.createTempSync('cresta_poi');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final store = TrackStore(Directory('${tmp.path}/tracks'));
    await store.load();
    late StreamController<GpsFix> gps;
    final t0 = DateTime(2026, 11, 12, 9);
    final rec = TrackRecorder(
      store: store,
      positions: (_) => (gps = StreamController<GpsFix>()).stream,
      clock: () => t0,
    );
    final sink = _Sink();
    final alerts = PoiAlerts(recorder: rec, sink: sink)..attach();
    await rec.start(name: 'x', route: route, pois: pois);
    // Camina toda la ruta, un punto cada 50 m
    for (var m = 0.0; m <= 2000; m += 50) {
      final p = _north(m);
      gps.add(
        GpsFix(
          time: t0.add(Duration(seconds: m.round())),
          lng: p.lng,
          lat: p.lat,
          altitude: 3500,
          accuracy: 5,
        ),
      );
      await Future<void>.delayed(Duration.zero);
    }
    expect(sink.shown.map((s) => s.$1), [
      PoiAlerts.baseId, // agua, a 150 m
      PoiAlerts.baseId + 1, // no retorno, a 300 m
    ]);
    expect(
      sink.shown.first.$3,
      'A 150 m del agua. Buen momento para rellenar.',
    );
    expect(sink.shown.last.$3, startsWith('A 300 m del punto de no retorno'));
    alerts.dispose();
    await rec.discard();
    rec.dispose();
  });
}
