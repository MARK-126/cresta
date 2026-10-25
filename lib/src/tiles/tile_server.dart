import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../offline/map_sources.dart';
import '../offline/tile_store.dart';

/// Ruta de un mosaico pedido por el mapa: `/tiles/<fuente>/<z>/<x>/<y>`.
@immutable
class TilePath {
  const TilePath(this.source, this.z, this.x, this.y);

  final MapSource source;
  final int z;
  final int x;
  final int y;

  /// Devuelve null si la ruta no es un mosaico válido (incluye intentos de `..`).
  static TilePath? parse(String path) {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length != 5 || parts[0] != 'tiles') return null;
    final source = MapSource.byId(parts[1]);
    final z = int.tryParse(parts[2]);
    final x = int.tryParse(parts[3]);
    final y = int.tryParse(parts[4]);
    if (source == null ||
        z == null ||
        x == null ||
        y == null ||
        z < 0 ||
        z > 22) {
      return null;
    }
    final max = 1 << z;
    if (x < 0 || y < 0 || x >= max || y >= max) return null;
    return TilePath(source, z, x, y);
  }
}

/// Servidor HTTP en 127.0.0.1 que alimenta al WebView del mapa.
///
/// - `/` y archivos de `assets/web` (página del mapa, MapLibre y tipografías)
/// - `/data/<archivo>` desde `assets/data`
/// - `/tiles/<fuente>/<z>/<x>/<y>`: primero las zonas descargadas, luego la caché de navegación
///   y por último la red (lo que se ve con conexión se guarda en la caché).
class TileServer {
  TileServer({
    required this.offline,
    required this.cache,
    required this.topoTemplate,
    AssetBundle? bundle,
    http.Client? client,
  }) : _bundle = bundle ?? rootBundle,
       _client = client ?? http.Client();

  final TileStore offline;
  final TileStore cache;
  final Future<String?> Function() topoTemplate;
  final AssetBundle _bundle;
  final http.Client _client;
  HttpServer? _server;

  Uri get baseUri => Uri.parse('http://127.0.0.1:${_server!.port}');

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handle);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _client.close();
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      final path = Uri.decodeComponent(req.uri.path);
      if (path.startsWith('/tiles/')) {
        await _serveTile(path, res);
      } else if (path.startsWith('/data/')) {
        await _serveAsset('assets/data/${path.substring(6)}', res);
      } else if (path.startsWith('/fonts/')) {
        await _serveFont(path, res);
      } else {
        await _serveAsset(
          'assets/web/${path == '/' ? 'index.html' : path.substring(1)}',
          res,
        );
      }
    } catch (e) {
      debugPrint('TileServer: $e');
      res.statusCode = HttpStatus.internalServerError;
    }
    await res.close();
  }

  /// `/fonts/Noto Sans Regular,Arial Unicode MS Regular/0-255.pbf` → `assets/web/fonts/noto-sans-regular/0-255.pbf`.
  /// Solo se incluyen los rangos del alfabeto latino; para los demás se responde vacío.
  Future<void> _serveFont(String path, HttpResponse res) async {
    final parts = path.split('/'); // ['', 'fonts', stack, range]
    if (parts.length != 4) {
      res.statusCode = HttpStatus.notFound;
      return;
    }
    final font = parts[2]
        .split(',')
        .first
        .trim()
        .toLowerCase()
        .replaceAll(' ', '-');
    final key = 'assets/web/fonts/$font/${parts[3]}';
    try {
      final data = await _bundle.load(key);
      res.headers.contentType = ContentType('application', 'x-protobuf');
      res.add(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    } on FlutterError {
      res.headers.contentType = ContentType(
        'application',
        'x-protobuf',
      ); // glifo ausente: MapLibre lo omite
    }
  }

  Future<void> _serveAsset(String key, HttpResponse res) async {
    if (key.contains('..')) {
      res.statusCode = HttpStatus.badRequest;
      return;
    }
    final ByteData data;
    try {
      data = await _bundle.load(key);
    } on FlutterError {
      res.statusCode = HttpStatus.notFound;
      return;
    }
    res.headers.contentType = _contentType(key);
    res.add(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }

  Future<void> _serveTile(String path, HttpResponse res) async {
    final t = TilePath.parse(path);
    if (t == null) {
      res.statusCode = HttpStatus.notFound;
      return;
    }
    final bytes =
        await offline.read(t.source, t.z, t.x, t.y) ??
        await cache.read(t.source, t.z, t.x, t.y) ??
        await _fetchAndCache(t);
    if (bytes == null) {
      // 204 en vez de 404: MapLibre deja el hueco sin llenar la consola de errores
      res.statusCode = HttpStatus.noContent;
      return;
    }
    res.headers.contentType = switch (t.source) {
      MapSource.topo => ContentType('application', 'x-protobuf'),
      MapSource.dem => ContentType('image', 'png'),
      MapSource.sat => ContentType('image', 'jpeg'),
    };
    res.headers.set(HttpHeaders.cacheControlHeader, 'max-age=86400');
    res.add(bytes);
  }

  Future<Uint8List?> _fetchAndCache(TilePath t) async {
    final topo = t.source == MapSource.topo ? await topoTemplate() : null;
    final url = tileUrl(t.source, t.z, t.x, t.y, topoTemplate: topo);
    if (url == null) return null;
    try {
      final r = await _client
          .get(url, headers: {'User-Agent': userAgent})
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200 || r.bodyBytes.isEmpty) return null;
      await cache.write(t.source, t.z, t.x, t.y, r.bodyBytes);
      return r.bodyBytes;
    } on Exception {
      return null; // sin conexión: el mapa deja ese mosaico vacío
    }
  }

  static ContentType _contentType(String key) {
    final ext = key.split('.').last;
    return switch (ext) {
      'html' => ContentType.html,
      'js' => ContentType('application', 'javascript', charset: 'utf-8'),
      'css' => ContentType('text', 'css', charset: 'utf-8'),
      'json' || 'geojson' => ContentType.json,
      _ => ContentType.binary,
    };
  }
}
