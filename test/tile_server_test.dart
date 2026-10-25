import 'dart:io';

import 'package:cresta/src/offline/map_sources.dart';
import 'package:cresta/src/offline/tile_store.dart';
import 'package:cresta/src/tiles/tile_server.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('TilePath.parse', () {
    test('acepta mosaicos válidos', () {
      final t = TilePath.parse('/tiles/dem/12/901/1832')!;
      expect(t.source, MapSource.dem);
      expect((t.z, t.x, t.y), (12, 901, 1832));
    });

    test('rechaza rutas inválidas o peligrosas', () {
      for (final p in [
        '/tiles/dem/12/901',
        '/tiles/foo/1/0/0',
        '/tiles/dem/../../etc',
        '/tiles/dem/2/4/0',
        '/tiles/dem/-1/0/0',
      ]) {
        expect(TilePath.parse(p), isNull, reason: p);
      }
    });
  });

  test('el User-Agent es ASCII (con acentos, todas las descargas fallan)', () {
    expect(userAgent.codeUnits.every((c) => c < 128), isTrue);
  });

  test('URLs de descarga: el satélite de EOX usa el orden z/y/x', () {
    expect(
      tileUrl(MapSource.sat, 13, 1803, 3664)!.path,
      endsWith('/13/3664/1803.jpg'),
    );
    expect(
      tileUrl(MapSource.dem, 12, 901, 1832).toString(),
      contains('/terrarium/12/901/1832.png'),
    );
    expect(
      tileUrl(MapSource.topo, 1, 0, 0),
      isNull,
      reason: 'sin TileJSON no hay URL',
    );
    expect(
      tileUrl(
        MapSource.topo,
        1,
        0,
        0,
        topoTemplate: 'https://t/{z}/{x}/{y}.pbf',
      ).toString(),
      'https://t/1/0/0.pbf',
    );
  });

  group('TileServer', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('cresta'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('sirve lo descargado, si no la caché y por último la red', () async {
      final offline = TileStore(Directory('${tmp.path}/offline'));
      final cache = TileStore(Directory('${tmp.path}/cache'));
      await offline.write(MapSource.dem, 1, 0, 0, [0x89, 0x50, 0x4E, 0x47]);
      var networkCalls = 0;
      final client = MockClient((req) async {
        networkCalls++;
        return http.Response.bytes([0xFF, 0xD8, 0xFF], 200);
      });
      final server = TileServer(
        offline: offline,
        cache: cache,
        topoTemplate: () async => null,
        bundle: _EmptyBundle(),
        client: client,
      );
      await server.start();
      final io = HttpClient();
      Future<HttpClientResponse> get(String path) async =>
          (await io.getUrl(server.baseUri.resolve(path))).close();

      final fromOffline = await get('/tiles/dem/1/0/0');
      expect(fromOffline.statusCode, 200);
      expect(fromOffline.headers.contentType?.mimeType, 'image/png');
      expect(networkCalls, 0);

      final fromNet = await get('/tiles/sat/1/1/1');
      expect(fromNet.statusCode, 200);
      expect(fromNet.headers.contentType?.mimeType, 'image/jpeg');
      expect(await cache.has(MapSource.sat, 1, 1, 1), isTrue);
      expect(
        await offline.has(MapSource.sat, 1, 1, 1),
        isFalse,
        reason: 'navegar no cuenta como descarga',
      );

      await get('/tiles/sat/1/1/1');
      expect(networkCalls, 1, reason: 'la segunda vez sale de la caché');

      expect(
        (await get('/tiles/topo/1/0/0')).statusCode,
        204,
        reason: 'topo sin URL y sin red',
      );
      expect((await get('/tiles/dem/9/9')).statusCode, 404);
      io.close();
      await server.stop();
    });
  });
}

class _EmptyBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => throw FlutterError('no asset $key');
}
