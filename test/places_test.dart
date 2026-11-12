import 'dart:io';
import 'dart:math' as math;

import 'package:cresta/src/offline/map_sources.dart';
import 'package:cresta/src/offline/offline_region.dart';
import 'package:cresta/src/offline/tile_math.dart';
import 'package:cresta/src/places/place_index.dart';
import 'package:cresta/src/places/places.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cuatro mosaicos reales de OpenFreeMap (zoom 14) del Cordón del Plata, Mendoza.
const _topo = 'test/fixtures/topo';

double _lng(int x) => x / (1 << 14) * 360 - 180;
double _lat(int y) {
  final n = math.pi * (1 - 2 * y / (1 << 14));
  return math.atan((math.exp(n) - math.exp(-n)) / 2) * 180 / math.pi;
}

/// Zona que cubre los mosaicos x 5033–5035, y 9782–9783 (los de x 5034 no están).
final _bbox = BBox(
  _lng(5033) + 1e-4,
  _lat(9784) + 1e-4,
  _lng(5036) - 1e-4,
  _lat(9782) - 1e-4,
);

OfflineRegion _region({DateTime? topoAt}) => OfflineRegion(
  id: 'plata',
  name: 'Cordón del Plata',
  bbox: _bbox,
  detail: DetailLevel.detailed,
  sources: const {MapSource.topo},
  status: RegionStatus.complete,
  topoAt: topoAt ?? DateTime.utc(2026, 11, 1),
);

MapPlace _p(String name, PlaceKind kind, double lat, [double lng = -69.4]) =>
    MapPlace(name, kind, lng, lat);

void main() {
  test('cumbres, refugios y lugares con nombre de un mosaico', () {
    final bytes = File('$_topo/14/5035/9783').readAsBytesSync();
    final places = placesInTile(bytes, 14, 5035, 9783);
    String kindOf(String name) =>
        places.firstWhere((p) => p.name == name).kind.name;
    expect(kindOf('Refugio San Bernardo'), 'hut');
    expect(kindOf('Refugio UNCuyo'), 'hut');
    expect(kindOf('Refugio Mausy'), 'hut'); // "shelter" también es refugio
    expect(kindOf('Mirador del Puma'), 'viewpoint');
    expect(kindOf('Quebrada del Estudiante'), 'parking');
    final peak = places.firstWhere((p) => p.name == 'Cerro Andresito');
    expect(peak.kind, PlaceKind.peak);
    expect(peak.ele, 3000);
    // Todo cae dentro del mosaico (lo del borde de los vecinos no se cuenta)
    for (final p in places) {
      expect(p.lng, inInclusiveRange(_lng(5035), _lng(5036)));
      expect(p.lat, inInclusiveRange(_lat(9784), _lat(9783)));
    }
  });

  test('el índice de varios mosaicos no repite un sendero que cruza dos', () {
    final places = buildPlaces(_topo, [
      (14, 5033, 9782),
      (14, 5033, 9783),
      (14, 5034, 9783), // no está: se salta
      (14, 5035, 9782),
      (14, 5035, 9783),
    ]);
    int count(String name) => places.where((p) => p.name == name).length;
    expect(count('Cerro Adolfo Calle'), 1);
    expect(count('Ascenso Adolfo Calle'), 1);
    expect(count('Cerro Arenales'), 1);
    expect(places.firstWhere((p) => p.name == 'Cerro Adolfo Calle').ele, 4227);
  });

  test(
    'junta repetidos cercanos pero no lugares distintos con el mismo nombre',
    () {
      const m = 1 / 111195; // grados de latitud por metro
      final merged = mergePlaces([
        _p('Cerro Negro', PlaceKind.peak, -33),
        _p(
          'Cerro Negro',
          PlaceKind.peak,
          -33 + 100 * m,
        ), // la misma, en otra zona
        _p('Cerro Negro', PlaceKind.peak, -33 + 5000 * m), // otra cumbre
        _p('Cerro Negro', PlaceKind.hamlet, -33), // otro tipo
        _p('Arroyo Blanco', PlaceKind.river, -33),
        _p('Arroyo Blanco', PlaceKind.river, -33 + 1500 * m), // otro tramo
        _p('Arroyo Blanco', PlaceKind.river, -33 + 4000 * m),
      ]);
      expect(merged.where((p) => p.kind == PlaceKind.peak).length, 2);
      expect(merged.where((p) => p.kind == PlaceKind.hamlet).length, 1);
      expect(merged.where((p) => p.kind == PlaceKind.river).length, 2);
    },
  );

  group('buscar', () {
    const m = 1 / 111195;
    final places = [
      _p('Cerro Arenales', PlaceKind.peak, -33 + 7000 * m),
      _p('Arenales Chico', PlaceKind.peak, -33 + 9000 * m),
      _p('Los Arenales', PlaceKind.hamlet, -33 + 1000 * m),
      _p('Shangrilá', PlaceKind.camp, -33 + 2000 * m),
      _p('punto 3', PlaceKind.water, -33 + 3000 * m),
      _p('Refugio San Bernardo', PlaceKind.hut, -33 + 4000 * m),
      _p('Arroyo Blanco', PlaceKind.river, -33 + 6000 * m),
      _p('Arroyo Blanco', PlaceKind.river, -33 + 500 * m),
      _p('Las Vegas', PlaceKind.town, -33 + 100 * m),
    ];
    List<String> names(String q) => [
      for (final h in searchPlaces(places, q, lat: -33, lng: -69.4))
        h.place.name,
    ];

    test('sin acentos ni mayúsculas', () {
      expect(names('SHANGRILA'), ['Shangrilá']);
      expect(names('san bern'), ['Refugio San Bernardo']);
    });

    test('primero lo que empieza así, luego por palabra, luego lo demás', () {
      // "Arenales Chico" empieza así; las otras dos tienen la palabra (la más cercana antes)
      expect(names('arenales'), [
        'Arenales Chico',
        'Los Arenales',
        'Cerro Arenales',
      ]);
    });

    test('también por tipo, después de los nombres', () {
      expect(names('agua'), ['punto 3']);
      expect(names('refugio'), ['Refugio San Bernardo']);
    });

    test('de un río solo el tramo más cercano, con su distancia', () {
      final hits = searchPlaces(places, 'arroyo', lat: -33, lng: -69.4);
      expect(hits.length, 1);
      expect(hits.single.meters, closeTo(500, 2));
    });

    test('sin búsqueda: lo más cercano de lo útil en la montaña', () {
      // Sin pueblos, parajes ni ríos
      expect(names(''), [
        'Shangrilá',
        'punto 3',
        'Refugio San Bernardo',
        'Cerro Arenales',
        'Arenales Chico',
      ]);
    });

    test('sin posición: a igual coincidencia, el tipo ordena', () {
      final hits = searchPlaces(places, 'arenales');
      expect(hits.map((h) => h.place.name), [
        'Arenales Chico',
        'Cerro Arenales',
        'Los Arenales',
      ]);
      expect(hits.first.meters, isNull);
    });
  });

  test('el índice se guarda y se rehace solo cuando cambian las zonas', () async {
    final tmp = Directory.systemTemp.createTempSync('cresta_places');
    addTearDown(() => tmp.deleteSync(recursive: true));
    // Copia de los mosaicos, para poder borrarlos y ver que se lee lo guardado
    final topo = Directory('${tmp.path}/topo');
    for (final f in Directory(_topo).listSync(recursive: true)) {
      if (f is! File) continue;
      final to = File('${topo.path}${f.path.substring(_topo.length)}');
      to.parent.createSync(recursive: true);
      f.copySync(to.path);
    }
    var regions = [_region()];
    PlaceIndex index() => PlaceIndex(
      regions: () => regions,
      topoDir: topo.path,
      file: File('${tmp.path}/places.json'),
    );

    final first = await index().places();
    expect(first.map((p) => p.name), contains('Cerro Adolfo Calle'));
    expect(File('${tmp.path}/places.json').existsSync(), isTrue);

    // Otra vez (la app se reabrió) sin mosaicos: sale del archivo guardado
    topo.deleteSync(recursive: true);
    final again = index();
    expect(again.hasMaps, isTrue);
    expect((await again.places()).length, first.length);

    // La zona se actualizó: se rehace (y ya no hay mosaicos)
    regions = [_region(topoAt: DateTime.utc(2026, 12, 1))];
    expect(await again.places(), isEmpty);

    // Una zona a medias no cuenta
    regions = [_region()..status = RegionStatus.downloading];
    expect(again.hasMaps, isFalse);
  });
}
