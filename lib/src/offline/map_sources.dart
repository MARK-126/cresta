import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Solo ASCII: los encabezados HTTP no admiten acentos ni eñes.
const userAgent = 'Cresta/0.1 (personal mountaineering app)';

/// Una fuente de mosaicos que se puede descargar para usar sin conexión.
///
/// Todas son libres para uso personal y permiten guardarse en el teléfono.
/// Si la app se vuelve comercial hay que revisar la licencia del satélite (CC BY-NC-SA).
enum MapSource {
  /// Relieve para el 3D, el sombreado y las curvas de nivel (Terrain Tiles, AWS Open Data).
  dem(
    label: 'Relieve 3D',
    template: 'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png',
    minZoom: 8,
    maxZoomBasic: 11,
    maxZoomDetailed: 12,
    avgBytes: 90 * 1024,
    attribution: 'Relieve: Mapzen Terrain Tiles',
  ),

  /// Satélite Sentinel-2 sin nubes de EOX (10 m por píxel: rinde hasta zoom 14).
  sat(
    label: 'Satélite',
    template: 'https://tiles.maps.eox.at/wmts/1.0.0/s2cloudless-2024_3857/default/g/{z}/{y}/{x}.jpg',
    minZoom: 8,
    maxZoomBasic: 13,
    maxZoomDetailed: 14,
    avgBytes: 18 * 1024,
    attribution: 'Sentinel-2 cloudless 2024 de EOX IT Services (datos Copernicus modificados)',
  ),

  /// Mapa topográfico vectorial de OpenStreetMap servido por OpenFreeMap.
  /// La URL cambia con cada versión semanal; se obtiene de su TileJSON ([TopoTemplate]).
  topo(
    label: 'Topográfico y senderos',
    template: null,
    minZoom: 8,
    maxZoomBasic: 13,
    maxZoomDetailed: 14,
    avgBytes: 22 * 1024,
    attribution: '© OpenMapTiles · © colaboradores de OpenStreetMap',
  );

  const MapSource({
    required this.label,
    required this.template,
    required this.minZoom,
    required this.maxZoomBasic,
    required this.maxZoomDetailed,
    required this.avgBytes,
    required this.attribution,
  });

  final String label;
  final String? template;
  final int minZoom;
  final int maxZoomBasic;
  final int maxZoomDetailed;
  final int avgBytes;
  final String attribution;

  /// El relieve siempre se descarga: sin él no hay 3D ni curvas de nivel.
  bool get required => this == dem;

  static MapSource? byId(String id) =>
      values.where((s) => s.name == id).firstOrNull;
}

/// URL actual de los mosaicos vectoriales de OpenFreeMap.
///
/// Se pide el TileJSON cuando hay red y se guarda en disco para usarla en el siguiente arranque.
class TopoTemplate {
  TopoTemplate(this._file, {http.Client? client})
    : _client = client ?? http.Client();

  static const tileJsonUrl = 'https://tiles.openfreemap.org/planet';

  final File _file;
  final http.Client _client;
  String? _cached;

  Future<String?> get() async {
    if (_cached != null) return _cached;
    if (await _file.exists()) {
      final saved =
          jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
      _cached = saved['template'] as String?;
      final fetchedAt = DateTime.tryParse('${saved['fetchedAt']}');
      final fresh =
          fetchedAt != null &&
          DateTime.now().difference(fetchedAt) < const Duration(days: 3);
      if (!fresh) refresh();
      return _cached;
    }
    return refresh();
  }

  Future<String?> refresh() async {
    try {
      final r = await _client
          .get(Uri.parse(tileJsonUrl), headers: {'User-Agent': userAgent})
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return _cached;
      final template =
          ((jsonDecode(r.body) as Map)['tiles'] as List).first as String;
      _cached = template;
      await _file.parent.create(recursive: true);
      await _file.writeAsString(
        jsonEncode({
          'template': template,
          'fetchedAt': DateTime.now().toIso8601String(),
        }),
      );
    } on Exception catch (e) {
      debugPrint('TopoTemplate: $e');
    }
    return _cached;
  }
}

/// URL de descarga de un mosaico, o null si la fuente aún no tiene URL (topo sin TileJSON).
Uri? tileUrl(MapSource source, int z, int x, int y, {String? topoTemplate}) {
  final t = source == MapSource.topo ? topoTemplate : source.template;
  if (t == null) return null;
  return Uri.parse(
    t.replaceAll('{z}', '$z').replaceAll('{x}', '$x').replaceAll('{y}', '$y'),
  );
}
