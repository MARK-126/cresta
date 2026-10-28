import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../offline/map_sources.dart';
import '../offline/tile_store.dart';

/// Altitud del terreno a partir del relieve descargado (Terrain Tiles, ~30 m por píxel a zoom 12).
///
/// Funciona sin conexión y es mucho más estable que la altitud del GPS, que salta ±15 m;
/// por eso el desnivel del recorrido se calcula con ella cuando hay relieve en el teléfono.
class TerrainElevation {
  TerrainElevation(this.stores, {this.zoom = 12, this.decode = decodeRgba});

  /// Dónde buscar el relieve: zonas descargadas y caché de navegación.
  final List<TileStore> stores;
  final int zoom;

  /// PNG → píxeles RGBA de 256 × 256 (reemplazable en pruebas).
  final Future<Uint8List?> Function(Uint8List png) decode;

  final _cache = <String, Uint8List?>{};
  static const _maxTiles = 12;

  /// Metros sobre el nivel del mar, o null si no hay relieve de ese lugar en el teléfono.
  Future<double?> at(double lng, double lat) async {
    final n = (1 << zoom) * 256.0;
    final r = lat.clamp(-85.0, 85.0) * math.pi / 180;
    final px = (lng + 180) / 360 * n;
    final py = (1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2 * n;
    final nearest = await _pixel(px.floor(), py.floor());
    if (nearest == null) {
      debugPrint(
        'TerrainElevation: sin relieve en $zoom/${px ~/ 256}/${py ~/ 256}',
      );
      return null;
    }
    // Interpolación bilineal entre los centros de los 4 píxeles vecinos: con el
    // más cercano la altitud sube en escalones de ~30 m y exagera las pendientes.
    final fx = px - .5, fy = py - .5;
    final x0 = fx.floor(), y0 = fy.floor();
    final e00 = await _pixel(x0, y0), e10 = await _pixel(x0 + 1, y0);
    final e01 = await _pixel(x0, y0 + 1), e11 = await _pixel(x0 + 1, y0 + 1);
    // En el borde de lo descargado puede faltar un vecino
    if (e00 == null || e10 == null || e01 == null || e11 == null) {
      return nearest;
    }
    final dx = fx - x0, dy = fy - y0;
    final top = e00 + (e10 - e00) * dx, bottom = e01 + (e11 - e01) * dx;
    return top + (bottom - top) * dy;
  }

  /// Altitud de un píxel en coordenadas globales del zoom, o null sin relieve.
  Future<double?> _pixel(int gx, int gy) async {
    final rgba = await _tile(gx ~/ 256, gy ~/ 256);
    if (rgba == null || rgba.length < 256 * 256 * 4) return null;
    final i = ((gy % 256) * 256 + gx % 256) * 4;
    // Codificación terrarium: (R × 256 + G + B / 256) − 32768
    return rgba[i] * 256 + rgba[i + 1] + rgba[i + 2] / 256 - 32768;
  }

  Future<Uint8List?> _tile(int x, int y) async {
    final key = '$x/$y';
    if (_cache.containsKey(key)) {
      final v = _cache.remove(key);
      _cache[key] = v; // al final: usado hace poco
      return v;
    }
    Uint8List? rgba;
    for (final s in stores) {
      final png = await s.read(MapSource.dem, zoom, x, y);
      if (png == null) continue;
      rgba = await decode(png);
      break;
    }
    _cache[key] = rgba;
    if (_cache.length > _maxTiles) _cache.remove(_cache.keys.first);
    return rgba;
  }

  /// Decodifica un PNG con el decodificador del motor de Flutter.
  static Future<Uint8List?> decodeRgba(Uint8List png) async {
    try {
      final codec = await ui.instantiateImageCodec(png);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      frame.image.dispose();
      return data?.buffer.asUint8List();
    } catch (e) {
      debugPrint('TerrainElevation: no se pudo leer el relieve: $e');
      return null;
    }
  }
}
