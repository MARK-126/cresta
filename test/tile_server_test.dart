import 'dart:io';

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
      expect(t.relative, 'dem/12/901/1832');
      expect(t.upstream.toString(), contains('/terrarium/12/901/1832.png'));
    });

    test('el satélite de Esri usa el orden z/y/x', () {
      expect(TilePath.parse('/tiles/sat/13/1803/3664')!.upstream.path, endsWith('/tile/13/3664/1803'));
    });

    test('rechaza rutas inválidas o peligrosas', () {
      for (final p in ['/tiles/dem/12/901', '/tiles/foo/1/0/0', '/tiles/dem/../../etc', '/tiles/dem/2/4/0', '/tiles/dem/-1/0/0']) {
        expect(TilePath.parse(p), isNull, reason: p);
      }
    });
  });

  group('TileServer', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('cresta'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('sirve del paquete, si no descarga y guarda en caché', () async {
      final pack = Directory('${tmp.path}/pack');
      File('${pack.path}/dem/1/0/0')
        ..createSync(recursive: true)
        ..writeAsBytesSync([0x89, 0x50, 0x4E, 0x47]);
      var networkCalls = 0;
      final client = MockClient((req) async {
        networkCalls++;
        return http.Response.bytes([0xFF, 0xD8, 0xFF], 200);
      });
      final server = TileServer(packDirs: [pack], cacheDir: Directory('${tmp.path}/cache'), bundle: _EmptyBundle(), client: client);
      await server.start();
      final io = HttpClient();
      Future<HttpClientResponse> get(String path) async => (await io.getUrl(server.baseUri.resolve(path))).close();

      final fromPack = await get('/tiles/dem/1/0/0');
      expect(fromPack.statusCode, 200);
      expect(fromPack.headers.contentType?.mimeType, 'image/png');
      expect(networkCalls, 0);

      final fromNet = await get('/tiles/sat/1/1/1');
      expect(fromNet.statusCode, 200);
      expect(fromNet.headers.contentType?.mimeType, 'image/jpeg');
      expect(File('${tmp.path}/cache/sat/1/1/1').existsSync(), isTrue);

      await get('/tiles/sat/1/1/1');
      expect(networkCalls, 1, reason: 'la segunda vez sale de la caché');

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
