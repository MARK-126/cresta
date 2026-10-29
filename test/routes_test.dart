import 'dart:convert';
import 'dart:io';

import 'package:cresta/src/data/trail_route.dart';
import 'package:cresta/src/routes/planned_route.dart';
import 'package:cresta/src/routes/route_export.dart';
import 'package:cresta/src/routes/route_ledger.dart';
import 'package:cresta/src/routes/route_import.dart';
import 'package:cresta/src/routes/route_planner.dart';
import 'package:cresta/src/routes/route_profile.dart';
import 'package:cresta/src/routes/route_store.dart';
import 'package:cresta/src/storage/json_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// 1 km hacia el norte, con el mismo radio terrestre que `haversine`.
const _kmLat = 1000 / 111195;

/// Relieve falso: sube 100 m por cada km hacia el norte desde 19.0°.
Future<double?> _slope(double lng, double lat) async =>
    3000 + (lat - 19.0) / _kmLat * 100;

Future<double?> _noRelief(double lng, double lat) async => null;

void main() {
  group('Perfil', () {
    test('distancia, puntos intermedios y desnivel de una recta', () async {
      final r = await buildProfile(
        line: const [LngLat(-98.6, 19.0), LngLat(-98.6, 19.0 + 2 * _kmLat)],
        elevation: _slope,
        id: 'x',
        name: 'x',
        source: 'prueba',
      );
      expect(r.totalMeters, closeTo(2000, 5));
      // Cada 30 m como máximo: una recta de 2 km tiene más de 60 puntos
      expect(r.coordinates.length, greaterThan(60));
      expect(r.elevations.first, closeTo(3000, 1));
      expect(r.elevations.last, closeTo(3200, 1));
      expect(r.gain, inInclusiveRange(185, 200));
      expect(r.summary, contains('+'));
    });

    test('sin relieve descargado no inventa desnivel y lo avisa', () async {
      final r = await buildProfile(
        line: const [LngLat(-98.6, 19.0), LngLat(-98.6, 19.0 + _kmLat)],
        elevation: _noRelief,
        id: 'x',
        name: 'x',
        source: 'prueba',
      );
      expect(r.gain, 0);
      expect(r.summary, contains('sin relieve'));
    });

    test('rellena altitudes faltantes interpolando', () {
      expect(fillGaps([null, 100, null, 200, null]), [100, 100, 150, 200, 200]);
    });

    test('el ruido menor a 5 m no suma desnivel', () {
      final noisy = [
        for (var i = 0; i < 100; i++) 2000.0 + (i.isEven ? 3 : -3),
      ];
      expect(elevationGain(noisy), 0);
      expect(elevationLoss(noisy), 0);
      expect(
        elevationGain([for (var i = 0; i < 50; i++) 100.0 + i * 10]),
        closeTo(490, 30),
      );
    });
  });

  group('Planificador', () {
    late List<(LngLat, LngLat)> asked;
    List<LngLat>? trail;

    RoutePlanner planner() {
      asked = [];
      return RoutePlanner(
        snap: (a, b) async {
          asked.add((a, b));
          return trail;
        },
        elevation: _slope,
      );
    }

    const a = LngLat(-98.6, 19.0);
    final b = LngLat(-98.6, 19.0 + _kmLat);
    final c = LngLat(-98.59, 19.0 + _kmLat);

    test(
      'ajusta a sendero cuando lo hay y si no, traza recto y avisa',
      () async {
        final p = planner();
        trail = [a, const LngLat(-98.601, 19.004), b];
        await p.addPoint(a);
        expect(p.legs, isEmpty);
        await p.addPoint(b);
        expect(p.legs.single.length, 3);
        expect(p.snapped, [true]);
        expect(p.notice, isNull);

        trail = null;
        await p.addPoint(c);
        expect(p.legs.last, [b, c]);
        expect(p.snapped, [true, false]);
        expect(p.notice, contains('línea recta'));
        expect(p.preview!.totalMeters, greaterThan(1000));
        expect(asked.length, 2);
      },
    );

    test('sin ajuste no consulta los senderos', () async {
      final p = planner()..setSnap(false);
      await p.addPoint(a);
      await p.addPoint(b);
      expect(asked, isEmpty);
      expect(p.snapped, [false]);
    });

    test('deshacer quita lo último: punto de interés o tramo', () async {
      trail = null;
      final p = planner();
      await p.addPoint(a);
      await p.addPoint(b);
      p.addPoi(Poi(kind: PoiKind.water, at: b));
      await p.undo();
      expect(p.pois, isEmpty);
      expect(p.legs.length, 1);
      await p.undo();
      expect(p.legs, isEmpty);
      expect(p.preview, isNull);
      expect(p.waypoints, [a]);
      await p.undo();
      expect(p.isEmpty, isTrue);
    });

    test('invertir cambia el sentido de la ruta', () async {
      trail = null;
      final p = planner();
      await p.addPoint(a);
      await p.addPoint(b);
      await p.reverse();
      expect(p.waypoints.first.lat, b.lat);
      expect(p.line.first.lat, b.lat);
      expect(
        p.preview!.elevations.first,
        greaterThan(p.preview!.elevations.last),
      );
    });
  });

  test('la ruta se guarda y se vuelve a leer igual', () async {
    final dir = Directory.systemTemp.createTempSync('cresta_routes');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = JsonStore(File('${dir.path}/routes.json'));
    final p = RoutePlanner(snap: (a, b) async => null, elevation: _slope);
    await p.addPoint(const LngLat(-98.6, 19.0));
    await p.addPoint(const LngLat(-98.6, 19.0 + _kmLat));
    p.addPoi(
      Poi(kind: PoiKind.summit, at: const LngLat(-98.6, 19.009), name: 'Cima'),
    );
    final store = RouteStore(file);
    await store.save(p.toRoute('Subida norte', expeditionId: 'exp1'));

    final again = RouteStore(file);
    await again.load();
    final r = again.forExpedition('exp1')!;
    expect(r.name, 'Subida norte');
    expect(r.pois.single.name, 'Cima');
    expect(r.pois.single.kind, PoiKind.summit);
    expect(r.profile.totalMeters, closeTo(1000, 5));
    expect(r.profile.source, 'Planeada en Cresta');
    // Al editarla se recupera todo, incluido el historial para deshacer
    final edit = RoutePlanner(
      snap: (a, b) async => null,
      elevation: _slope,
      initial: r,
    );
    expect(edit.canSave, isTrue);
    await edit.undo();
    expect(edit.pois, isEmpty);
  });

  group('RouteStore', () {
    late Directory dir;
    late File raw;
    late JsonStore file;
    Future<PlannedRoute> route(String name, {String? expeditionId}) async {
      final p = RoutePlanner(snap: (a, b) async => null, elevation: _slope);
      await p.addPoint(const LngLat(-98.6, 19.0));
      await p.addPoint(const LngLat(-98.6, 19.0 + _kmLat));
      return p.toRoute(name, expeditionId: expeditionId);
    }

    setUp(() {
      dir = Directory.systemTemp.createTempSync('cresta_rstore');
      raw = File('${dir.path}/routes.json');
      file = JsonStore(raw);
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test(
      'migra el formato anterior (una ruta por expedición) con respaldo',
      () async {
        final a = (await route('Izta')).toJson()
          ..remove('id')
          ..remove('expeditionId');
        final b = (await route('Popo')).toJson()
          ..remove('id')
          ..remove('expeditionId');
        final legacy = jsonEncode({'exp1': a, 'exp2': b});
        await raw.writeAsString(legacy);

        final store = RouteStore(file);
        await store.load();
        expect(store.forExpedition('exp1')!.name, 'Izta');
        expect(store.forExpedition('exp2')!.name, 'Popo');
        expect(store.forExpedition('exp1')!.id, 'r-exp1');
        expect(store.all.length, 2);

        // Quedó el respaldo intacto y el archivo nuevo en el formato 2
        expect(await File('${raw.path}.v1.bak').readAsString(), legacy);
        final now =
            jsonDecode(await raw.readAsString()) as Map<String, dynamic>;
        expect(now['version'], 2);
        expect((now['routes'] as List).length, 2);

        // Abrirlo otra vez da lo mismo y no vuelve a migrar
        final again = RouteStore(file);
        await again.load();
        expect(again.all.map((r) => r.id), ['r-exp1', 'r-exp2']);
        expect(await File('${raw.path}.v1.bak').readAsString(), legacy);
      },
    );

    test(
      'una ruta ilegible del formato anterior no se lleva a las demás',
      () async {
        final ok = (await route('Izta')).toJson()
          ..remove('id')
          ..remove('expeditionId');
        final legacy = jsonEncode({
          'exp1': ok,
          'exp2': {'name': 1},
        });
        await raw.writeAsString(legacy);
        final store = RouteStore(file);
        await store.load();
        expect(store.all.single.name, 'Izta');
        // La dañada sigue en el respaldo
        expect(await File('${raw.path}.v1.bak').readAsString(), legacy);
      },
    );

    test(
      'varias rutas por expedición, rutas sueltas, reemplazar y borrar',
      () async {
        final store = RouteStore(file);
        final r1 = await route('A', expeditionId: 'e1');
        final r2 = await route('B', expeditionId: 'e1');
        final solo = await route('Suelta');
        await store.save(r1);
        await store.save(r2);
        await store.save(solo);
        expect(store.of('e1').map((r) => r.name), ['A', 'B']);
        expect(store.forExpedition('e1')!.name, 'A');
        expect(store.byId(solo.id)!.expeditionId, isNull);

        // Guardar con el mismo id reemplaza (editar una ruta no la duplica)
        await store.save(r1.withName('A2'));
        expect(store.of('e1').map((r) => r.name), ['A2', 'B']);

        final nueva = await route('Nueva');
        await store.replaceOf('e1', nueva);
        expect(store.of('e1').single.name, 'Nueva');
        expect(store.all.length, 2);

        await store.save(store.byId(solo.id)!.linkedTo('e2'));
        expect(store.forExpedition('e2')!.name, 'Suelta');

        final again = RouteStore(file);
        await again.load();
        expect(again.all.map((r) => r.name), ['Suelta', 'Nueva']);
        await again.deleteOf('e1');
        expect(again.of('e1'), isEmpty);
        await again.delete(solo.id);
        expect(again.all, isEmpty);
      },
    );
  });

  group('Importar', () {
    test('GPX: track, nombre y puntos de interés', () {
      const gpx = '''<?xml version="1.0"?>
<gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1">
  <metadata><name>Archivo</name></metadata>
  <wpt lat="19.10" lon="-98.64"><name>Fuente del Ángel</name></wpt>
  <wpt lat="19.12" lon="-98.63"><name>Refugio Grupo de los 100</name></wpt>
  <trk><name>Ruta a la cumbre</name>
    <trkseg>
      <trkpt lat="19.10" lon="-98.64"><ele>3900</ele></trkpt>
      <trkpt lat="19.11" lon="-98.635"><ele>4100</ele></trkpt>
    </trkseg>
    <trkseg><trkpt lat="19.12" lon="-98.63"/></trkseg>
  </trk>
</gpx>''';
      final r = parseRouteFile('ruta.gpx', gpx);
      expect(r.name, 'Ruta a la cumbre');
      expect(r.line.length, 3);
      expect(r.line.first.lng, -98.64);
      expect(r.origin, RouteOrigin.gpx);
      expect(r.pois.map((p) => p.kind), [PoiKind.water, PoiKind.shelter]);
    });

    test('GPX sin track usa la ruta (rtept)', () {
      const gpx = '''<gpx><rte><name>Plan</name>
<rtept lat="1" lon="2"/><rtept lat="1.1" lon="2.1"/></rte></gpx>''';
      final r = parseRouteFile('plan.gpx', gpx);
      expect(r.name, 'Plan');
      expect(r.line.length, 2);
    });

    test('KML: línea con altitud y punto de interés', () {
      const kml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"><Document><name>Mi doc</name>
  <Placemark><name>Cumbre principal</name><Point><coordinates>-98.63,19.12,5200</coordinates></Point></Placemark>
  <Placemark><name>Arista</name><LineString><coordinates>
    -98.64,19.10,3900 -98.635,19.11,4100
    -98.63,19.12,5200
  </coordinates></LineString></Placemark>
</Document></kml>''';
      final r = parseRouteFile('ruta.kml', kml);
      expect(r.name, 'Arista');
      expect(r.line.length, 3);
      expect(r.line.last.lat, 19.12);
      expect(r.pois.single.kind, PoiKind.summit);
      expect(r.origin, RouteOrigin.kml);
    });

    test('KML de Google Earth con gx:Track', () {
      const kml = '''<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">
<Placemark><gx:Track><gx:coord>-98.64 19.10 3900</gx:coord><gx:coord>-98.63 19.12 5200</gx:coord></gx:Track></Placemark></kml>''';
      expect(parseRouteFile('t.kml', kml).line.length, 2);
    });

    test('archivos que no sirven dan un mensaje claro', () {
      expect(
        () => parseRouteFile('x.kmz', 'PK…'),
        throwsA(isA<RouteImportException>()),
      );
      expect(
        () => parseRouteFile('x.gpx', '<gpx><wpt lat="1" lon="2"/></gpx>'),
        throwsA(predicate((e) => '$e'.contains('al menos dos puntos'))),
      );
      expect(
        () => parseRouteFile('x.gpx', 'no es xml'),
        throwsA(isA<RouteImportException>()),
      );
    });
  });

  test('bitácora: paradas en orden con hora estimada; GPX de ida y vuelta', () async {
    final p = RoutePlanner(snap: (a, b) async => null, elevation: _slope);
    await p.addPoint(const LngLat(-98.6, 19.0));
    await p.addPoint(const LngLat(-98.6, 19.0 + 3 * _kmLat));
    // Se agregan en desorden: la bitácora las ordena por dónde caen en la ruta
    p.addPoi(
      Poi(kind: PoiKind.camp, at: const LngLat(-98.6, 19.0 + 2 * _kmLat)),
    );
    p.addPoi(
      Poi(kind: PoiKind.water, at: const LngLat(-98.599, 19.0 + _kmLat)),
    );
    final route = p.toRoute('Norte');

    final stops = routeLedger(route);
    expect(stops.map((s) => s.name), [
      'Salida',
      'Agua',
      'Campamento',
      'Llegada',
    ]);
    expect(stops[1].meters, closeTo(1000, 40));
    expect(stops[1].offRoute, closeTo(105, 15));
    expect(stops.last.eta, route.profile.estimatedTime);
    expect(stops[2].eta < stops.last.eta, isTrue);

    final back = parseRouteFile('norte.gpx', routeToGpx(route));
    expect(back.name, 'Norte');
    expect(back.line.length, route.profile.coordinates.length);
    expect(back.pois.map((p) => p.kind), [PoiKind.camp, PoiKind.water]);
  });
}
