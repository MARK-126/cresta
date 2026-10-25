import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Fuentes de mosaicos en línea. Revisa los términos de uso antes de publicar:
/// Esri World Imagery exige una cuenta de ArcGIS para uso en apps.
const tileUpstreams = <String, String>{
  'dem': 'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png',
  'sat': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
};

/// Ruta de un mosaico pedido por el mapa: `/tiles/<tipo>/<z>/<x>/<y>`.
@immutable
class TilePath {
  const TilePath(this.type, this.z, this.x, this.y);

  final String type;
  final int z;
  final int x;
  final int y;

  /// Devuelve null si la ruta no es un mosaico válido (incluye intentos de `..`).
  static TilePath? parse(String path) {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length != 5 || parts[0] != 'tiles' || !tileUpstreams.containsKey(parts[1])) return null;
    final z = int.tryParse(parts[2]);
    final x = int.tryParse(parts[3]);
    final y = int.tryParse(parts[4]);
    if (z == null || x == null || y == null || z < 0 || z > 22) return null;
    final max = 1 << z;
    if (x < 0 || y < 0 || x >= max || y >= max) return null;
    return TilePath(parts[1], z, x, y);
  }

  String get relative => '$type/$z/$x/$y';
  Uri get upstream => Uri.parse(
      tileUpstreams[type]!.replaceAll('{z}', '$z').replaceAll('{x}', '$x').replaceAll('{y}', '$y'));
}

/// Servidor HTTP en 127.0.0.1 que alimenta al WebView del mapa.
///
/// - `/` y archivos de `assets/web` (página del mapa y MapLibre GL JS)
/// - `/data/<archivo>` desde `assets/data`
/// - `/tiles/<tipo>/<z>/<x>/<y>`: primero el paquete sin conexión, luego la caché en disco
///   y por último la red (guardando en caché lo descargado).
class TileServer {
  TileServer({required this.packDirs, required this.cacheDir, AssetBundle? bundle, http.Client? client})
      : _bundle = bundle ?? rootBundle,
        _client = client ?? http.Client();

  final List<Directory> packDirs;
  final Directory cacheDir;
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
      final path = req.uri.path;
      if (path.startsWith('/tiles/')) {
        await _serveTile(path, res);
      } else if (path.startsWith('/data/')) {
        await _serveAsset('assets/data/${path.substring(6)}', res);
      } else {
        await _serveAsset('assets/web/${path == '/' ? 'index.html' : path.substring(1)}', res);
      }
    } catch (e) {
      debugPrint('TileServer: $e');
      res.statusCode = HttpStatus.internalServerError;
    }
    await res.close();
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
    final tile = TilePath.parse(path);
    if (tile == null) {
      res.statusCode = HttpStatus.notFound;
      return;
    }
    final bytes = await _readLocal(tile) ?? await _fetchAndCache(tile);
    if (bytes == null) {
      res.statusCode = HttpStatus.notFound;
      return;
    }
    res.headers.contentType = _sniffImage(bytes);
    res.headers.set(HttpHeaders.cacheControlHeader, 'max-age=86400');
    res.add(bytes);
  }

  Future<Uint8List?> _readLocal(TilePath tile) async {
    for (final dir in [...packDirs, cacheDir]) {
      final f = File('${dir.path}/${tile.relative}');
      if (await f.exists()) return f.readAsBytes();
    }
    return null;
  }

  Future<Uint8List?> _fetchAndCache(TilePath tile) async {
    try {
      final r = await _client.get(tile.upstream).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      final f = File('${cacheDir.path}/${tile.relative}');
      await f.parent.create(recursive: true);
      await f.writeAsBytes(r.bodyBytes);
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

  static ContentType _sniffImage(Uint8List b) =>
      b.length > 3 && b[0] == 0x89 && b[1] == 0x50 ? ContentType('image', 'png') : ContentType('image', 'jpeg');
}
