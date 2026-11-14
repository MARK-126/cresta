import '../storage/json_store.dart';
import 'map_layers.dart';

/// Qué se ve en el video del recorrido. Se recuerda la última elección.
class VideoOptions {
  const VideoOptions({
    this.base = MapBase.night,
    this.streets = true,
    this.trails = false,
    this.contours = false,
    this.buildings = true,
    this.caption = true,
    this.fast = false,
  });

  /// Fondo del mapa.
  final MapBase base;

  /// Nombres de las calles a unas dos cuadras (~200 m) del recorrido.
  final bool streets;

  /// Senderos y brechas (en la ciudad son banquetas punteadas: apagado de inicio).
  final bool trails;

  /// Curvas de nivel.
  final bool contours;

  /// Edificios en volumen (solo de cerca y donde OpenStreetMap los tiene).
  final bool buildings;

  /// Título, cifras y barra de avance abajo.
  final bool caption;

  /// Más rápido (la mitad de tiempo de vuelo).
  final bool fast;

  VideoOptions copyWith({
    MapBase? base,
    bool? streets,
    bool? trails,
    bool? contours,
    bool? buildings,
    bool? caption,
    bool? fast,
  }) => VideoOptions(
    base: base ?? this.base,
    streets: streets ?? this.streets,
    trails: trails ?? this.trails,
    contours: contours ?? this.contours,
    buildings: buildings ?? this.buildings,
    caption: caption ?? this.caption,
    fast: fast ?? this.fast,
  );

  /// Lo que recibe `flyTrack` en `map.js`.
  Map<String, Object> toJson() => {
    'base': base.name,
    'streets': streets,
    'trails': trails,
    'contours': contours,
    'buildings': buildings,
    'caption': caption,
    'fast': fast,
  };

  factory VideoOptions.fromJson(Map<String, dynamic> j) {
    const d = VideoOptions();
    bool b(String k, bool def) => j[k] is bool ? j[k] as bool : def;
    return VideoOptions(
      base: MapBase.values.asNameMap()[j['base']] ?? d.base,
      streets: b('streets', d.streets),
      trails: b('trails', d.trails),
      contours: b('contours', d.contours),
      buildings: b('buildings', d.buildings),
      caption: b('caption', d.caption),
      fast: b('fast', d.fast),
    );
  }
}

/// Recuerda las opciones del último video (en `video.json`).
class VideoOptionsStore {
  VideoOptionsStore(this._file);
  final JsonStore _file;
  VideoOptions _value = const VideoOptions();

  VideoOptions get value => _value;

  Future<void> load() async {
    final saved = await _file.read();
    if (saved is Map<String, dynamic>) _value = VideoOptions.fromJson(saved);
  }

  Future<void> save(VideoOptions v) async {
    _value = v;
    await _file.write(v.toJson());
  }
}
