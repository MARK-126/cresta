import 'dart:async';
import 'dart:io';

import 'package:cresta/src/expeditions/expedition.dart';
import 'package:cresta/src/expeditions/expedition_store.dart';
import 'package:cresta/src/offline/map_sources.dart';
import 'package:cresta/src/offline/offline_maps.dart';
import 'package:cresta/src/offline/offline_region.dart';
import 'package:cresta/src/offline/region_downloader.dart';
import 'package:cresta/src/offline/tile_math.dart';
import 'package:cresta/src/offline/tile_store.dart';
import 'package:cresta/src/storage/json_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Una zona chica (≈ 4 × 4 km) en el Iztaccíhuatl.
const _bbox = BBox(-98.66, 19.14, -98.62, 19.18);

OfflineRegion _region({
  Set<MapSource> sources = const {MapSource.dem, MapSource.sat},
}) => OfflineRegion(
  id: 'r1',
  name: 'Izta',
  bbox: _bbox,
  detail: DetailLevel.basic,
  sources: sources,
);

void main() {
  test(
    'JsonStore: escrituras simultáneas se ordenan y gana la última',
    () async {
      final tmp = Directory.systemTemp.createTempSync('cresta');
      final store = JsonStore(File('${tmp.path}/x.json'));
      await Future.wait([
        for (var i = 0; i < 20; i++) store.write({'n': i}),
      ]);
      expect(await store.read(), {'n': 19});
      tmp.deleteSync(recursive: true);
    },
  );

  group('tile_math', () {
    test('convierte coordenadas a mosaicos', () {
      // Mosaico conocido del relieve que contiene la cumbre del Popocatépetl
      expect(lngToTileX(-98.6234, 12), 925);
      expect(latToTileY(19.0234, 12), 1827);
    });

    test('cuenta mosaicos por zoom', () {
      expect(countTiles(_bbox, 0, 0), 1);
      expect(countTiles(_bbox, 12, 12), tileRange(_bbox, 12).count);
      expect(countTiles(_bbox, 8, 14), greaterThan(countTiles(_bbox, 8, 13)));
    });

    test('expandKm agranda la caja', () {
      final b = _bbox.expandKm(2);
      expect(b.widthKm, closeTo(_bbox.widthKm + 4, 0.1));
      expect(b.heightKm, closeTo(_bbox.heightKm + 4, 0.1));
    });
  });

  group('OfflineRegion', () {
    test('los trabajos coinciden con el total y van de menor a mayor zoom', () {
      final r = _region();
      final jobs = r.jobs.toList();
      expect(jobs.length, r.totalTiles);
      expect(jobs.first.z, MapSource.dem.minZoom);
      expect(
        jobs.map((j) => j.z).toList(),
        orderedEquals([...jobs.map((j) => j.z)]..sort()),
      );
      expect(
        jobs
            .where((j) => j.source == MapSource.dem)
            .map((j) => j.z)
            .reduce((a, b) => a > b ? a : b),
        MapSource.dem.maxZoomBasic,
      );
    });

    test('covers respeta fuente, zoom y área', () {
      final r = _region();
      final (x, y) = tileRange(_bbox, 12).tiles.first;
      expect(r.covers(MapSource.sat, 12, x, y), isTrue);
      expect(
        r.covers(MapSource.topo, 12, x, y),
        isFalse,
        reason: 'no se pidió topo',
      );
      expect(
        r.covers(MapSource.dem, 12, x, y),
        isFalse,
        reason: 'el relieve básico llega a z11',
      );
      expect(r.covers(MapSource.sat, 12, x + 50, y), isFalse);
    });

    test('estimación y límite de tamaño', () {
      final small = OfflineRegion.estimate(_bbox, DetailLevel.detailed, {
        MapSource.dem,
        MapSource.sat,
        MapSource.topo,
      });
      expect(small.tooBig, isFalse);
      expect(small.bytes, greaterThan(0));
      const huge = BBox(-104, 16, -96, 24);
      expect(
        OfflineRegion.estimate(huge, DetailLevel.detailed, {
          MapSource.sat,
        }).tooBig,
        isTrue,
      );
    });

    test('JSON de ida y vuelta; una descarga en curso vuelve como pausada', () {
      final r = _region()
        ..status = RegionStatus.downloading
        ..doneTiles = 5;
      final back = OfflineRegion.fromJson(r.toJson());
      expect(back.bbox, r.bbox);
      expect(back.sources, r.sources);
      expect(back.doneTiles, 5);
      expect(back.status, RegionStatus.paused);
    });
  });

  group('RegionDownloader', () {
    late Directory tmp;
    late TileStore store;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('cresta');
      store = TileStore(Directory('${tmp.path}/tiles'));
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    RegionDownloader downloader(http.Client client) => RegionDownloader(
      store: store,
      client: client,
      topoTemplate: () async => 'https://topo/{z}/{x}/{y}.pbf',
      retryDelay: Duration.zero,
    );

    test('descarga todo y al repetir no vuelve a pedir nada', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response.bytes(List.filled(10, 1), 200);
      });
      final r = _region();
      final first = await downloader(client).run(r, token: CancelToken());
      expect(first.outcome, DownloadOutcome.complete);
      expect(calls, r.totalTiles);

      final second = await downloader(client).run(r, token: CancelToken());
      expect(second.outcome, DownloadOutcome.complete);
      expect(
        calls,
        r.totalTiles,
        reason: 'reanudable: lo que está en disco no se pide',
      );
    });

    test('un 404 no es error (mosaico sin datos)', () async {
      final client = MockClient((_) async => http.Response('', 404));
      final result = await downloader(client)
          .run(_region(), token: CancelToken());
      expect(result.outcome, DownloadOutcome.complete);
    });

    test('sin red se detiene como "offline" sin marcar mosaicos', () async {
      final client = MockClient(
        (_) async => throw const SocketException('sin red'),
      );
      final result = await downloader(client)
          .run(_region(), token: CancelToken());
      expect(result.outcome, DownloadOutcome.offline);
      expect(await store.sizeOnDisk(), 0);
    });

    test('se puede pausar a mitad', () async {
      final token = CancelToken();
      var calls = 0;
      final client = MockClient((_) async {
        if (++calls == 5) token.cancel();
        return http.Response.bytes([1], 200);
      });
      final r = _region();
      final result = await downloader(client).run(r, token: token);
      expect(result.outcome, DownloadOutcome.cancelled);
      expect(calls, lessThan(r.totalTiles));
    });
  });

  group('OfflineMaps y expediciones', () {
    late Directory tmp;
    late TileStore store;
    late OfflineMaps maps;
    late ExpeditionStore expeditions;
    late StreamController<NetworkKind> net;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('cresta');
      store = TileStore(Directory('${tmp.path}/tiles'));
      net = StreamController<NetworkKind>();
      maps = OfflineMaps(
        store: store,
        downloader: RegionDownloader(
          store: store,
          client: MockClient((_) async => http.Response.bytes([1, 2, 3], 200)),
          topoTemplate: () async => 'https://topo/{z}/{x}/{y}.pbf',
          retryDelay: Duration.zero,
        ),
        regionsFile: JsonStore(File('${tmp.path}/regions.json')),
        settingsFile: JsonStore(File('${tmp.path}/settings.json')),
        networkChanges: net.stream,
      );
      await maps.load();
      expeditions = ExpeditionStore(
        JsonStore(File('${tmp.path}/expeditions.json')),
        maps,
      );
    });
    tearDown(() async {
      maps.dispose();
      await net.close();
      tmp.deleteSync(recursive: true);
    });

    Future<void> settle() async {
      for (var i = 0; i < 200 && maps.active != null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    test('crear expedición, descargar zona y quedar lista', () async {
      final e = await expeditions.create(
        name: 'Izta',
        date: DateTime(2026, 11, 15),
      );
      expect(expeditions.statusOf(e).readiness, Readiness.noMaps);

      final r = await maps.add(
        name: 'Izta',
        bbox: _bbox,
        detail: DetailLevel.basic,
        sources: {MapSource.sat},
      );
      await expeditions.attachRegion(e, r.id);
      expect(
        r.sources,
        contains(MapSource.dem),
        reason: 'el relieve siempre se incluye',
      );
      await settle();

      expect(r.status, RegionStatus.complete);
      expect(expeditions.statusOf(e).readiness, Readiness.ready);
      expect(expeditions.statusOf(e).bounds, _bbox);
    });

    test('con datos móviles y "solo Wi-Fi" la descarga espera', () async {
      net.add(NetworkKind.mobile);
      await Future<void>.delayed(Duration.zero);
      final r = await maps.add(
        name: 'Izta',
        bbox: _bbox,
        detail: DetailLevel.basic,
        sources: {},
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(r.status, RegionStatus.queued);
      expect(r.message, 'Esperando Wi-Fi');

      net.add(NetworkKind.wifi);
      await Future<void>.delayed(Duration.zero);
      await settle();
      expect(r.status, RegionStatus.complete);
    });

    test(
      'borrar una zona libera solo los mosaicos que nadie más usa',
      () async {
        final a = await maps.add(
          name: 'A',
          bbox: _bbox,
          detail: DetailLevel.basic,
          sources: {},
        );
        await settle();
        final b = await maps.add(
          name: 'B',
          bbox: _bbox.expandKm(3),
          detail: DetailLevel.basic,
          sources: {},
        );
        await settle();
        final before = await store.sizeOnDisk();

        await maps.remove(b.id);
        final after = await store.sizeOnDisk();
        expect(after, lessThan(before));
        // Todo lo de A sigue en disco
        for (final j in a.jobs) {
          expect(await store.has(j.source, j.z, j.x, j.y), isTrue);
        }

        await maps.remove(a.id);
        expect(await store.sizeOnDisk(), 0);
      },
    );

    test('borrar la expedición borra sus mapas si nadie más los usa', () async {
      final e1 = await expeditions.create(name: 'Uno');
      final e2 = await expeditions.create(name: 'Dos');
      final r = await maps.add(
        name: 'Compartida',
        bbox: _bbox,
        detail: DetailLevel.basic,
        sources: {},
      );
      await settle();
      await expeditions.attachRegion(e1, r.id);
      await expeditions.attachRegion(e2, r.id);

      await expeditions.delete(e1, deleteMaps: true);
      expect(maps.byId(r.id), isNotNull, reason: 'la usa otra expedición');
      await expeditions.delete(e2, deleteMaps: true);
      expect(maps.byId(r.id), isNull);
    });

    test('las expediciones y zonas se guardan en disco', () async {
      final e = await expeditions.create(
        name: 'Pico de Orizaba',
        date: DateTime(2027, 1, 10),
        notes: 'Salida 1 a.m.',
      );
      final r = await maps.add(
        name: 'Orizaba',
        bbox: _bbox,
        detail: DetailLevel.detailed,
        sources: {MapSource.topo},
      );
      await expeditions.attachRegion(e, r.id);
      await settle();

      final maps2 = OfflineMaps(
        store: store,
        downloader: maps.downloader,
        regionsFile: JsonStore(File('${tmp.path}/regions.json')),
        settingsFile: JsonStore(File('${tmp.path}/settings.json')),
      );
      await maps2.load();
      final again = ExpeditionStore(
        JsonStore(File('${tmp.path}/expeditions.json')),
        maps2,
      );
      await again.load();
      final e2 = again.all.single;
      expect(e2.name, 'Pico de Orizaba');
      expect(e2.notes, 'Salida 1 a.m.');
      expect(e2.date, DateTime(2027, 1, 10));
      expect(again.statusOf(e2).readiness, Readiness.ready);
      maps2.dispose();
    });
  });
}
