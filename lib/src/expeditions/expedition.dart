import '../offline/offline_region.dart';
import '../offline/tile_math.dart';

/// Una salida a la montaña: reúne sus zonas de mapas descargadas (y, en próximas fases,
/// la ruta, el clima guardado, las referencias y los recorridos).
class Expedition {
  Expedition({
    required this.id,
    required this.name,
    this.date,
    this.notes = '',
    List<String>? regionIds,
    this.routeAsset,
    this.sample = false,
    DateTime? createdAt,
  }) : regionIds = regionIds ?? [],
       createdAt = createdAt ?? DateTime.now();

  factory Expedition.fromJson(Map<String, dynamic> j) => Expedition(
    id: j['id'] as String,
    name: j['name'] as String,
    date: DateTime.tryParse('${j['date']}'),
    notes: j['notes'] as String? ?? '',
    regionIds: [
      for (final r in j['regionIds'] as List? ?? const []) r as String,
    ],
    routeAsset: j['routeAsset'] as String?,
    sample: j['sample'] as bool? ?? false,
    createdAt: DateTime.tryParse('${j['createdAt']}'),
  );

  final String id;
  String name;
  DateTime? date;
  String notes;
  final List<String> regionIds;

  /// Ruta incluida en la app (solo el ejemplo, hasta que exista el planificador de rutas).
  final String? routeAsset;
  final bool sample;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'date': date?.toIso8601String(),
    'notes': notes,
    'regionIds': regionIds,
    'routeAsset': routeAsset,
    'sample': sample,
    'createdAt': createdAt.toIso8601String(),
  };
}

enum Readiness { noMaps, downloading, incomplete, ready }

/// Qué tan lista está la expedición para usarse sin conexión.
class ExpeditionStatus {
  ExpeditionStatus(this.regions);

  final List<OfflineRegion> regions;

  Readiness get readiness {
    if (regions.isEmpty) return Readiness.noMaps;
    if (regions.every((r) => r.isComplete)) return Readiness.ready;
    if (regions.any((r) => r.isActive)) return Readiness.downloading;
    return Readiness.incomplete;
  }

  double get progress {
    final total = regions.fold(0, (s, r) => s + r.totalTiles);
    return total == 0 ? 0 : regions.fold(0, (s, r) => s + r.doneTiles) / total;
  }

  int get bytes => regions.fold(0, (s, r) => s + r.bytes);

  /// Área que cubre todo lo descargado, para encuadrar el mapa.
  BBox? get bounds {
    if (regions.isEmpty) return null;
    return regions
        .map((r) => r.bbox)
        .reduce(
          (a, b) => BBox(
            a.west < b.west ? a.west : b.west,
            a.south < b.south ? a.south : b.south,
            a.east > b.east ? a.east : b.east,
            a.north > b.north ? a.north : b.north,
          ),
        );
  }
}
