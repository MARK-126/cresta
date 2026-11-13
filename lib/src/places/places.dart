import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../tiles/mvt.dart';
import '../tracking/track.dart' show haversine;

/// Tipos de lugar que se pueden buscar sin señal. El orden decide cuál va primero cuando
/// dos nombres coinciden igual de bien.
enum PlaceKind {
  peak('Cumbre'),
  volcano('Volcán'),
  hut('Refugio'),
  water('Agua'),
  lake('Laguna'),
  camp('Campamento'),
  saddle('Collado'),
  viewpoint('Mirador'),
  town('Pueblo'),
  hamlet('Paraje'),
  trail('Sendero'),
  river('Río o arroyo'),
  park('Parque'),
  police('Policía'),
  health('Salud'),
  parking('Estacionamiento'),

  /// Un lugar que no viene de los mapas: tu ubicación o un resultado de la búsqueda en
  /// línea. Nunca está en el índice.
  other('Lugar');

  const PlaceKind(this.label);
  final String label;

  /// Los que son líneas (un río, un sendero) se repiten en cada mosaico que cruzan.
  bool get isLine => this == trail || this == river;
}

/// Un lugar con nombre de los mapas descargados.
class MapPlace {
  const MapPlace(this.name, this.kind, this.lng, this.lat, [this.ele]);

  factory MapPlace.fromJson(List j) => MapPlace(
    j[0] as String,
    PlaceKind.values.byName(j[1] as String),
    (j[2] as num).toDouble(),
    (j[3] as num).toDouble(),
    j[4] as int?,
  );

  final String name;
  final PlaceKind kind;
  final double lng;
  final double lat;

  /// Altitud en metros (solo cumbres, volcanes y collados).
  final int? ele;

  List<Object?> toJson() => [
    name,
    kind.name,
    double.parse(lng.toStringAsFixed(6)),
    double.parse(lat.toStringAsFixed(6)),
    ele,
  ];
}

/// Capas de OpenMapTiles que tienen lugares; las demás (calles, edificios) ni se decodifican.
const _layers = {
  'mountain_peak',
  'place',
  'poi',
  'water_name',
  'waterway',
  'transportation_name',
  'park',
};

PlaceKind? _kindOf(String layer, MvtFeature f) {
  final c = f.props['class'], sub = f.props['subclass'];
  return switch (layer) {
    'mountain_peak' when f.type == 1 => switch (c) {
      'peak' => PlaceKind.peak,
      'volcano' => PlaceKind.volcano,
      'saddle' => PlaceKind.saddle,
      _ => null,
    },
    'place' => switch (c) {
      'city' || 'town' || 'village' => PlaceKind.town,
      'hamlet' || 'locality' || 'isolated_dwelling' => PlaceKind.hamlet,
      _ => null,
    },
    'poi' => switch (sub) {
      'alpine_hut' || 'shelter' || 'wilderness_hut' => PlaceKind.hut,
      'camp_site' => PlaceKind.camp,
      'drinking_water' || 'spring' || 'water_point' => PlaceKind.water,
      'viewpoint' => PlaceKind.viewpoint,
      'police' => PlaceKind.police,
      'hospital' || 'clinic' => PlaceKind.health,
      'parking' => PlaceKind.parking,
      _ => null,
    },
    'water_name' when f.type == 1 => PlaceKind.lake,
    'waterway' when c == 'river' || c == 'stream' => PlaceKind.river,
    'transportation_name' when c == 'path' || c == 'track' => PlaceKind.trail,
    // Los parques son polígonos; su nombre viene aparte, como punto
    'park' when f.type == 1 => PlaceKind.park,
    _ => null,
  };
}

/// Lugares con nombre de un mosaico topográfico (MVT sin comprimir).
List<MapPlace> placesInTile(Uint8List bytes, int z, int x, int y) {
  final out = <MapPlace>[];
  for (final layer in decodeMvt(bytes, keep: _layers.contains)) {
    for (final f in layer.features) {
      final name = f.props['name'];
      if (name is! String || name.trim().isEmpty) continue;
      final kind = _kindOf(layer.name, f);
      if (kind == null || f.parts.isEmpty || f.parts.first.isEmpty) continue;
      // Un punto: el suyo. Una línea: su punto de en medio (dentro del mosaico)
      final part = f.parts.reduce((a, b) => a.length >= b.length ? a : b);
      final (px, py) = part[part.length ~/ 2];
      final e = layer.extent;
      // Los mosaicos repiten lo del borde de sus vecinos: solo cuenta lo que cae dentro
      if (px < 0 || py < 0 || px > e || py > e) continue;
      final (lng, lat) = _lngLat(z, x + px / e, y + py / e);
      final ele = f.props['ele'];
      out.add(
        MapPlace(
          name.trim(),
          kind,
          lng,
          lat,
          ele is num && kind.index <= PlaceKind.saddle.index
              ? ele.round()
              : null,
        ),
      );
    }
  }
  return out;
}

(double, double) _lngLat(int z, double tx, double ty) {
  final n = math.pow(2, z);
  final lng = tx / n * 360 - 180;
  final lat = math.atan(_sinh(math.pi * (1 - 2 * ty / n))) * 180 / math.pi;
  return (lng, lat);
}

double _sinh(double v) => (math.exp(v) - math.exp(-v)) / 2;

/// Junta los lugares repetidos: el mismo nombre y tipo a menos de 300 m (un punto en dos
/// zonas que se enciman) o a menos de 2 km si es un río o un sendero (uno por mosaico).
List<MapPlace> mergePlaces(Iterable<MapPlace> places) {
  final groups = <String, List<MapPlace>>{};
  for (final p in places) {
    final kept = groups.putIfAbsent(
      '${p.kind.name}|${normalize(p.name)}',
      () => [],
    );
    final radius = p.kind.isLine ? 2000 : 300;
    if (kept.any((k) => haversine(k.lat, k.lng, p.lat, p.lng) < radius)) {
      continue;
    }
    kept.add(p);
  }
  return [for (final g in groups.values) ...g];
}

/// Lee los mosaicos de [jobs] (z, x, y) de la carpeta topográfica [topoDir] y arma el
/// índice. Es sincrónico a propósito: corre en otro isolate.
List<MapPlace> buildPlaces(String topoDir, List<(int, int, int)> jobs) {
  final all = <MapPlace>[];
  for (final (z, x, y) in jobs) {
    final f = File('$topoDir/$z/$x/$y');
    if (!f.existsSync()) continue;
    try {
      all.addAll(placesInTile(f.readAsBytesSync(), z, x, y));
    } on Object {
      // Un mosaico dañado no impide buscar en los demás
    }
  }
  return mergePlaces(all);
}

/// Minúsculas y sin acentos, para que "cerro adolfo" encuentre "Cerro Adolfo Calle".
String normalize(String s) {
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    b.write(_plain[r] ?? String.fromCharCode(r));
  }
  return b.toString();
}

const _plain = {
  0xe1: 'a', 0xe0: 'a', 0xe4: 'a', 0xe2: 'a', 0xe3: 'a', //
  0xe9: 'e', 0xe8: 'e', 0xeb: 'e', 0xea: 'e',
  0xed: 'i', 0xec: 'i', 0xef: 'i', 0xee: 'i',
  0xf3: 'o', 0xf2: 'o', 0xf6: 'o', 0xf4: 'o', 0xf5: 'o',
  0xfa: 'u', 0xf9: 'u', 0xfc: 'u', 0xfb: 'u',
  0xf1: 'n', 0xe7: 'c',
};

/// Un resultado de búsqueda, con la distancia desde donde estás (o desde el centro del
/// mapa) si se conoce.
class PlaceHit {
  const PlaceHit(this.place, this.meters);
  final MapPlace place;
  final double? meters;
}

/// Busca [query] en [places]. Cada palabra de la búsqueda debe aparecer en el nombre;
/// primero los que empiezan así, luego los que tienen una palabra que empieza así, luego
/// el resto y al final los que coinciden por su tipo ("agua", "cumbre"); entre iguales, el
/// más cercano a [lat], [lng]. Sin búsqueda, lo más cercano de lo útil en la montaña
/// (cumbres, refugios, agua, campamentos). De un río o sendero, solo el tramo más cercano.
List<PlaceHit> searchPlaces(
  List<MapPlace> places,
  String query, {
  double? lat,
  double? lng,
  int limit = 40,
}) {
  double? dist(MapPlace p) =>
      lat == null || lng == null ? null : haversine(lat, lng, p.lat, p.lng);
  final words = normalize(query).split(RegExp(r'\s+'))..remove('');
  final scored = <(int, double, PlaceHit)>[];
  for (final p in places) {
    final int rank;
    if (words.isEmpty) {
      if (p.kind.index > PlaceKind.camp.index) continue;
      rank = 0;
    } else {
      final name = normalize(p.name);
      if (!words.every(name.contains)) {
        final withKind = '$name ${normalize(p.kind.label)}';
        if (!words.every(withKind.contains)) continue;
        rank = 3;
      } else {
        final q = words.join(' ');
        final starts = RegExp('(^|[^a-z0-9])${RegExp.escape(words.first)}');
        rank = name.startsWith(q)
            ? 0
            : starts.hasMatch(name)
            ? 1
            : 2;
      }
    }
    final d = dist(p);
    scored.add((rank, d ?? 0, PlaceHit(p, d)));
  }
  scored.sort((a, b) {
    if (a.$1 != b.$1) return a.$1 - b.$1;
    // Sin búsqueda manda la cercanía; con búsqueda, a igual coincidencia, el tipo y luego la cercanía
    if (words.isNotEmpty && lat == null) {
      final k = a.$3.place.kind.index - b.$3.place.kind.index;
      if (k != 0) return k;
    }
    return a.$2.compareTo(b.$2);
  });
  final out = <PlaceHit>[];
  final lines = <String>{};
  for (final (_, _, hit) in scored) {
    final p = hit.place;
    if (p.kind.isLine && !lines.add('${p.kind.name}|${normalize(p.name)}')) {
      continue;
    }
    out.add(hit);
    if (out.length == limit) break;
  }
  return out;
}
