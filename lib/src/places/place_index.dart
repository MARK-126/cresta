import 'dart:io';
import 'dart:isolate';

import '../offline/map_sources.dart';
import '../offline/offline_region.dart';
import '../offline/tile_math.dart';
import '../storage/json_store.dart';
import 'places.dart';

/// Índice de lugares (cumbres, refugios, agua, pueblos…) de las zonas descargadas, para
/// buscar sin señal. Se arma la primera vez que se busca, en otro isolate, con los
/// mosaicos topográficos del zoom más alto de cada zona completa, y se guarda en el
/// teléfono; se rehace solo si cambian las zonas (otra descarga, una actualización).
class PlaceIndex {
  PlaceIndex({required this.regions, required this.topoDir, required File file})
    : _file = JsonStore(file);

  /// Las zonas descargadas en este momento.
  final List<OfflineRegion> Function() regions;

  /// Carpeta de los mosaicos topográficos guardados (`<z>/<x>/<y>`).
  final String topoDir;
  final JsonStore _file;

  /// Sube si cambia lo que se extrae de los mosaicos, para rehacer los índices guardados.
  static const version = 1;

  String? _key;
  List<MapPlace>? _places;
  Future<List<MapPlace>>? _building;

  /// Zonas que entran al índice: solo las completas (una a medias lo rehace a cada rato).
  List<OfflineRegion> get _complete => [
    for (final r in regions())
      if (r.isComplete) r,
  ]..sort((a, b) => a.id.compareTo(b.id));

  /// Hay algo en qué buscar.
  bool get hasMaps => _complete.isNotEmpty;

  /// Identifica el conjunto de zonas (y su fecha) con el que se armó el índice.
  static String keyOf(List<OfflineRegion> regions) => [
    'v$version',
    for (final r in regions)
      '${r.id}:${r.maxZoomFor(MapSource.topo)}:${r.topoDate.millisecondsSinceEpoch}',
  ].join(',');

  /// Los lugares de las zonas completas; lo arma (o lo lee del teléfono) si hace falta.
  Future<List<MapPlace>> places() {
    final complete = _complete;
    final key = keyOf(complete);
    if (key == _key && _places != null) return Future.value(_places);
    if (key == _key && _building != null) return _building!;
    _key = key;
    _places = null;
    return _building = _load(key, complete).then((p) {
      if (_key == key) _places = p;
      return p;
    });
  }

  Future<List<MapPlace>> _load(String key, List<OfflineRegion> regions) async {
    final saved = await _file.read();
    if (saved is Map && saved['key'] == key) {
      try {
        return [
          for (final p in saved['places'] as List) MapPlace.fromJson(p as List),
        ];
      } on Object {
        // Archivo de otra versión o dañado: se rehace
      }
    }
    if (regions.isEmpty) return const [];
    final jobs = <(int, int, int)>{
      for (final r in regions)
        for (final (x, y) in tileRange(
          r.bbox,
          r.maxZoomFor(MapSource.topo),
        ).tiles)
          (r.maxZoomFor(MapSource.topo), x, y),
    }.toList();
    final dir = topoDir;
    final places = await Isolate.run(() => buildPlaces(dir, jobs));
    await _file.write({
      'key': key,
      'places': [for (final p in places) p.toJson()],
    });
    return places;
  }
}
