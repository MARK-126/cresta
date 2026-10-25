import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cresta/src/data/trail_route.dart';
import 'package:cresta/src/expeditions/expedition.dart';
import 'package:cresta/src/tracking/gpx.dart';
import 'package:cresta/src/tracking/route_progress.dart';
import 'package:cresta/src/tracking/track.dart';
import 'package:cresta/src/tracking/track_recorder.dart';
import 'package:cresta/src/tracking/track_stats.dart';
import 'package:cresta/src/tracking/track_store.dart';
import 'package:cresta/src/tracking/terrain_elevation.dart';
import 'package:cresta/src/offline/map_sources.dart';
import 'package:cresta/src/offline/tile_store.dart';

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime(2026, 11, 15, 6);

/// Caminata hacia el norte: un punto cada 30 s, 25 m de avance y 5 m de subida por punto.
List<GpsFix> _walk(
  int n, {
  double startLat = 19.10,
  double startAlt = 3700,
  double accuracy = 5,
}) => [
  for (var i = 0; i < n; i++)
    GpsFix(
      time: _t0.add(Duration(seconds: 30 * i)),
      lng: -98.65,
      lat: startLat + i * 25 / 110570,
      altitude: startAlt + i * 5,
      accuracy: accuracy,
    ),
];

TrackPoint _pt(GpsFix f, [int segment = 0]) => TrackPoint(
  time: f.time,
  lng: f.lng,
  lat: f.lat,
  altitude: f.altitude,
  accuracy: f.accuracy,
  segment: segment,
);

void main() {
  group('TrackStats', () {
    test('distancia, tiempo en movimiento y desnivel', () {
      final s = TrackStats.of(_walk(41).map(_pt));
      expect(s.meters, closeTo(1000, 10));
      expect(s.moving, const Duration(minutes: 20));
      // La altitud suavizada se queda unos metros atrás de la real al final
      expect(s.gain, inInclusiveRange(175, 200));
      expect(s.loss, 0);
      expect(
        s.verticalSpeed,
        closeTo(600, 40),
        reason: '5 m cada 30 s = 600 m/h',
      );
    });

    test('el ruido de altitud del GPS no suma desnivel', () {
      final noisy = [
        for (var i = 0; i < 60; i++)
          TrackPoint(
            time: _t0.add(Duration(seconds: 10 * i)),
            lng: -98.65,
            lat: 19.1,
            altitude: 4000 + (i.isEven ? 3.0 : -3.0),
          ),
      ];
      final s = TrackStats.of(noisy);
      expect(s.gain, 0);
      expect(s.loss, 0);
    });

    test('una pausa no cuenta como distancia ni tiempo en movimiento', () {
      final a = _walk(5).map(_pt).toList();
      final b = _walk(5, startLat: 19.2)
          .map(
            (f) => _pt(
              GpsFix(
                time: f.time.add(const Duration(hours: 1)),
                lng: f.lng,
                lat: f.lat,
                altitude: f.altitude,
                accuracy: 5,
              ),
              1,
            ),
          )
          .toList();
      final s = TrackStats.of([...a, ...b]);
      expect(
        s.meters,
        closeTo(200, 2),
        reason: 'dos tramos de 100 m, sin unir el salto',
      );
      expect(s.moving, const Duration(minutes: 4));
    });
  });

  test('RouteProgress: avance, distancia a la ruta y subida pendiente', () {
    final route = TrailRoute(
      id: 'r',
      name: 'r',
      summary: '',
      coordinates: const [
        LngLat(-98.65, 19.10),
        LngLat(-98.65, 19.11),
        LngLat(-98.65, 19.12),
      ],
      distances: [0, 1105.7, 2211.4],
      elevations: [3700, 3900, 4200],
      gain: 500,
      source: '',
    );
    final onRoute = RouteProgress.of(route, -98.65, 19.105);
    expect(onRoute.metersAlong, closeTo(553, 2));
    expect(onRoute.offRoute, closeTo(0, 1));
    expect(onRoute.isOffRoute, isFalse);
    expect(onRoute.remainingGain, closeTo(400, 1));

    final off = RouteProgress.of(route, -98.649, 19.11); // ~105 m al este
    expect(off.offRoute, closeTo(105, 3));
    expect(off.isOffRoute, isTrue);
  });

  test('GPX con un tramo por cada pausa', () {
    final t = Track(
      id: 'x',
      expeditionId: 'e',
      name: 'Izta & Popo',
      startedAt: _t0,
    );
    final pts = [
      ..._walk(2).map(_pt),
      ..._walk(2, startLat: 19.2).map((f) => _pt(f, 1)),
    ];
    final gpx = toGpx(t, pts);
    expect('<trkseg>'.allMatches(gpx).length, 2);
    expect('<trkpt'.allMatches(gpx).length, 4);
    expect(gpx, contains('Izta &amp; Popo'));
    expect(gpx, contains('<ele>3700.0</ele>'));
  });

  test('hora límite de la expedición', () {
    final e = Expedition(id: 'e', name: 'x', turnaroundMinutes: 11 * 60 + 30);
    expect(
      e.turnaroundOn(DateTime(2026, 11, 15, 4)),
      DateTime(2026, 11, 15, 11, 30),
    );
    expect(Expedition.fromJson(e.toJson()).turnaroundMinutes, 690);
  });

  group('TrackRecorder', () {
    late Directory tmp;
    late TrackStore store;
    late StreamController<GpsFix> gps;
    late DateTime now;
    late TrackRecorder rec;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('cresta');
      store = TrackStore(Directory('${tmp.path}/tracks'));
      await store.load();
      now = _t0;
      rec = TrackRecorder(
        store: store,
        positions: (_) {
          gps = StreamController<GpsFix>();
          return gps.stream;
        },
        clock: () => now,
      );
    });
    tearDown(() async {
      rec.dispose();
      await Future<void>.delayed(
        const Duration(milliseconds: 50),
      ); // deja terminar escrituras
      tmp.deleteSync(recursive: true);
    });

    Future<void> feed(Iterable<GpsFix> fixes) async {
      for (final f in fixes) {
        gps.add(f);
      }
      await Future<void>.delayed(Duration.zero);
    }

    test(
      'graba, descarta lecturas malas o quietas, y guarda al terminar',
      () async {
        await rec.start(expeditionId: 'e', name: 'Subida');
        await feed(_walk(10));
        await feed([
          GpsFix(
            time: _t0.add(const Duration(seconds: 301)),
            lng: -98.0,
            lat: 19.0,
            accuracy: 120,
          ),
        ]); // mala
        final last = _walk(10).last;
        await feed([
          GpsFix(
            time: last.time.add(const Duration(seconds: 5)),
            lng: last.lng,
            lat: last.lat + 1 / 110570,
            accuracy: 5,
          ),
        ]); // 1 m: quieto
        expect(rec.points.length, 10);

        final t = await rec.stop();
        expect(t.status, TrackStatus.finished);
        expect(t.summary.meters, closeTo(225, 2));
        expect(rec.state, RecorderState.idle);

        final again = TrackStore(store.dir);
        await again.load();
        expect(again.byId(t.id)!.summary.meters, closeTo(225, 2));
        expect((await again.readPoints(t.id)).length, 10);
      },
    );

    test('pausar y reanudar empieza un tramo nuevo', () async {
      await rec.start(expeditionId: 'e', name: 'x');
      await feed(_walk(3));
      rec.pause();
      expect(rec.state, RecorderState.paused);
      rec.resume();
      await feed(
        _walk(3, startLat: 19.2).map(
          (f) => GpsFix(
            time: f.time.add(const Duration(hours: 1)),
            lng: f.lng,
            lat: f.lat,
            altitude: f.altitude,
            accuracy: 5,
          ),
        ),
      );
      expect(rec.points.map((p) => p.segment).toSet(), {0, 1});
      expect(rec.stats.meters, closeTo(100, 2));
    });

    test(
      'si la app se cierra grabando, el recorrido se recupera en pausa',
      () async {
        await rec.start(expeditionId: 'e', name: 'x');
        await feed(_walk(6));
        // Simula el guardado periódico y luego un cierre sin "Terminar"
        rec.pause();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final store2 = TrackStore(store.dir);
        await store2.load();
        final rec2 = TrackRecorder(
          store: store2,
          positions: (_) => const Stream.empty(),
        );
        await rec2.recover();
        expect(rec2.state, RecorderState.paused);
        expect(rec2.points.length, 6);
        expect(rec2.stats.meters, closeTo(125, 2));
      },
    );

    test('avisa de la hora límite', () async {
      await rec.start(
        expeditionId: 'e',
        name: 'x',
        turnaround: _t0.add(const Duration(hours: 5)),
      );
      expect(rec.turnaroundState, TurnaroundState.ok);
      now = _t0.add(const Duration(hours: 4, minutes: 40));
      expect(rec.turnaroundState, TurnaroundState.soon);
      now = _t0.add(const Duration(hours: 5, minutes: 1));
      expect(rec.turnaroundState, TurnaroundState.passed);
    });

    test('descartar borra el recorrido', () async {
      await rec.start(expeditionId: 'e', name: 'x');
      await feed(_walk(3));
      await rec.discard();
      expect(store.all, isEmpty);
    });

    test(
      'una línea a medias en el archivo de puntos no rompe la lectura',
      () async {
        await rec.start(expeditionId: 'e', name: 'x');
        await feed(_walk(3));
        final t = await rec.stop();
        await File('${store.dir.path}/points/${t.id}.jsonl')
            .writeAsString('[1730000000000, -98.6', mode: FileMode.append);
        expect((await store.readPoints(t.id)).length, 3);
        expect(
          jsonEncode(store.byId(t.id)!.toJson()),
          contains('"status":"finished"'),
        );
      },
    );
  });

  test(
    'altitud del terreno desde el relieve descargado (codificación terrarium)',
    () async {
      final tmp = Directory.systemTemp.createTempSync('cresta');
      final store = TileStore(Directory('${tmp.path}/tiles'));
      // Popocatépetl, zoom 12: mosaico (925, 1827)
      await store.write(MapSource.dem, 12, 925, 1827, [1, 2, 3]);
      // Píxeles falsos: todo el mosaico a 5,452 m → R=149, G=76, B=0  (149·256 + 76 − 32768 = 5452)
      final rgba = Uint8List(256 * 256 * 4);
      for (var i = 0; i < rgba.length; i += 4) {
        rgba[i] = 149;
        rgba[i + 1] = 76;
      }
      final t = TerrainElevation([store], decode: (_) async => rgba);
      expect(await t.at(-98.6234, 19.0234), 5452);
      expect(
        await t.at(-70.01, -32.65),
        isNull,
        reason: 'sin relieve descargado en Argentina',
      );
      tmp.deleteSync(recursive: true);
    },
  );

  test('el grabador usa la altitud del terreno cuando la hay', () async {
    final tmp = Directory.systemTemp.createTempSync('cresta');
    final store = TrackStore(Directory('${tmp.path}/tracks'));
    final gps = StreamController<GpsFix>();
    final rec = TrackRecorder(
      store: store,
      positions: (_) => gps.stream,
      terrain: (lng, lat) async =>
          4000 + (lat - 19.10) * 110570 * 0.2, // pendiente del 20 %
    );
    await rec.start(expeditionId: 'e', name: 'x');
    for (final f in _walk(21)) {
      gps.add(
        GpsFix(time: f.time, lng: f.lng, lat: f.lat, altitude: 0, accuracy: 5),
      ); // GPS sin altitud útil
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(rec.points.length, 21);
    expect(rec.points.first.altitude, closeTo(4000, 0.1));
    expect(
      rec.stats.gain,
      inInclusiveRange(80, 100),
      reason: '500 m al 20 % = 100 m',
    );
    rec.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    tmp.deleteSync(recursive: true);
  });
}
