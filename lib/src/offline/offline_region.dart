import 'map_sources.dart';
import 'tile_math.dart';

enum DetailLevel {
  basic('Básico', 'Hasta zoom 13: vista general y senderos principales'),
  detailed('Detallado', 'Hasta zoom 14: más detalle de senderos y satélite');

  const DetailLevel(this.label, this.description);
  final String label;
  final String description;
}

enum RegionStatus { queued, downloading, paused, complete, failed }

/// Límite por zona para no abusar de los servicios gratuitos ni llenar el teléfono.
const maxTilesPerRegion = 40000;

/// Una zona de mapas elegida por el usuario para usar sin conexión.
class OfflineRegion {
  OfflineRegion({
    required this.id,
    required this.name,
    required this.bbox,
    required this.detail,
    required this.sources,
    this.status = RegionStatus.queued,
    this.doneTiles = 0,
    int? totalTiles,
    this.bytes = 0,
    this.message,
    this.bundled = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.topoAt,
    this.refreshAfter,
  }) : totalTiles = totalTiles ?? estimate(bbox, detail, sources).tiles,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory OfflineRegion.fromJson(Map<String, dynamic> j) => OfflineRegion(
    id: j['id'] as String,
    name: j['name'] as String,
    bbox: BBox.fromJson(j['bbox'] as List),
    detail: DetailLevel.values.byName(j['detail'] as String),
    sources: {
      for (final s in j['sources'] as List) ?MapSource.byId(s as String),
    },
    // Una descarga interrumpida al cerrar la app vuelve como pausada
    status: switch (RegionStatus.values.byName(j['status'] as String)) {
      RegionStatus.downloading => RegionStatus.paused,
      final s => s,
    },
    doneTiles: j['doneTiles'] as int? ?? 0,
    totalTiles: j['totalTiles'] as int?,
    bytes: j['bytes'] as int? ?? 0,
    message: j['message'] as String?,
    bundled: j['bundled'] as bool? ?? false,
    createdAt: DateTime.tryParse('${j['createdAt']}'),
    updatedAt: DateTime.tryParse('${j['updatedAt']}'),
    topoAt: DateTime.tryParse('${j['topoAt']}'),
    refreshAfter: DateTime.tryParse('${j['refreshAfter']}'),
  );

  final String id;
  String name;
  final BBox bbox;
  final DetailLevel detail;
  final Set<MapSource> sources;
  RegionStatus status;
  int doneTiles;
  final int totalTiles;
  int bytes;

  /// Motivo de la pausa o del error, para mostrarlo al usuario.
  String? message;

  /// Viene incluida en la app (ejemplo del Izta–Popo).
  final bool bundled;
  final DateTime createdAt;
  DateTime updatedAt;

  /// Cuándo terminó de bajarse su mapa topográfico (senderos, calles, nombres).
  DateTime? topoAt;

  /// Actualizando: los mosaicos topo guardados antes de esta fecha se vuelven a pedir
  /// (así se puede pausar y reanudar). Null si no se está actualizando.
  DateTime? refreshAfter;

  /// Pasado este tiempo se ofrece actualizar el topográfico: OpenStreetMap se corrige
  /// seguido, pero los senderos de montaña cambian despacio (OpenFreeMap se rehace cada semana).
  static const staleAfter = Duration(days: 90);

  double get progress =>
      totalTiles == 0 ? 1 : (doneTiles / totalTiles).clamp(0, 1);

  /// Todos sus mosaicos están en el teléfono. También mientras se actualiza: los
  /// viejos siguen sirviendo hasta que llegan los nuevos.
  bool get isComplete => status == RegionStatus.complete || isRefreshing;
  bool get isRefreshing => refreshAfter != null;

  /// Marca la zona para actualizar su topográfico. El corte va 2 s antes: algunos sistemas
  /// guardan la fecha de los archivos al segundo, y un mosaico recién escrito parecería viejo.
  void startRefresh([DateTime? now]) => refreshAfter = (now ?? DateTime.now())
      .subtract(const Duration(seconds: 2));

  /// Fecha de su topográfico (las zonas anteriores a este campo usan la última descarga).
  DateTime get topoDate => topoAt ?? updatedAt;

  /// Se puede actualizar: terminada, con topográfico y dentro del tope de OpenFreeMap.
  bool get canRefresh {
    if (status != RegionStatus.complete || !sources.contains(MapSource.topo)) {
      return false;
    }
    final cap = MapSource.topo.maxTilesPerDownload;
    final n = countTiles(
      bbox,
      MapSource.topo.minZoom,
      maxZoomFor(MapSource.topo),
    );
    return cap == null || n <= cap;
  }

  /// Su topográfico tiene más de [staleAfter].
  bool isStale(DateTime now) =>
      canRefresh && now.difference(topoDate) > staleAfter;
  bool get isActive =>
      status == RegionStatus.downloading || status == RegionStatus.queued;

  int maxZoomFor(MapSource s) =>
      detail == DetailLevel.basic ? s.maxZoomBasic : s.maxZoomDetailed;

  /// Si el mosaico forma parte de esta zona.
  bool covers(MapSource s, int z, int x, int y) =>
      sources.contains(s) &&
      z >= s.minZoom &&
      z <= maxZoomFor(s) &&
      tileRange(bbox, z).contains(x, y);

  /// Todos los mosaicos de la zona, de menor a mayor zoom (así lo general queda listo primero).
  Iterable<TileJob> get jobs sync* {
    final ordered = MapSource.values.where(sources.contains).toList();
    final maxZ = ordered.map(maxZoomFor).fold(0, (a, b) => a > b ? a : b);
    for (var z = 0; z <= maxZ; z++) {
      for (final s in ordered) {
        if (z < s.minZoom || z > maxZoomFor(s)) continue;
        for (final (x, y) in tileRange(bbox, z).tiles) {
          yield TileJob(s, z, x, y);
        }
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'bbox': bbox.toJson(),
    'detail': detail.name,
    'sources': [for (final s in sources) s.name],
    'status': status.name,
    'doneTiles': doneTiles,
    'totalTiles': totalTiles,
    'bytes': bytes,
    'message': message,
    'bundled': bundled,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'topoAt': topoAt?.toIso8601String(),
    'refreshAfter': refreshAfter?.toIso8601String(),
  };

  static RegionEstimate estimate(
    BBox bbox,
    DetailLevel detail,
    Set<MapSource> sources,
  ) {
    var tiles = 0, bytes = 0;
    MapSource? over;
    for (final s in sources) {
      final max = detail == DetailLevel.basic
          ? s.maxZoomBasic
          : s.maxZoomDetailed;
      final n = countTiles(bbox, s.minZoom, max);
      tiles += n;
      bytes += n * s.avgBytes;
      final cap = s.maxTilesPerDownload;
      if (cap != null && n > cap) over ??= s;
    }
    return RegionEstimate(tiles, bytes, overSource: over);
  }
}

class RegionEstimate {
  const RegionEstimate(this.tiles, this.bytes, {this.overSource});
  final int tiles;
  final int bytes;

  /// Fuente que pasa su propio tope por descarga (p. ej. el topográfico).
  final MapSource? overSource;

  bool get tooBig => tiles > maxTilesPerRegion || overSource != null;
}

class TileJob {
  const TileJob(this.source, this.z, this.x, this.y);
  final MapSource source;
  final int z, x, y;
}
