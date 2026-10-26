import 'package:xml/xml.dart';

import '../data/trail_route.dart';
import 'planned_route.dart';

/// Una ruta leída de un archivo, antes de calcular su perfil.
class ImportedRoute {
  ImportedRoute({
    required this.name,
    required this.line,
    required this.pois,
    required this.origin,
  });

  final String? name;

  /// Todos los tramos del archivo unidos en orden.
  final List<LngLat> line;
  final List<Poi> pois;
  final RouteOrigin origin;
}

class RouteImportException implements Exception {
  RouteImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Lee un GPX o un KML según la extensión del archivo (o su contenido, si no la tiene).
ImportedRoute parseRouteFile(String fileName, String content) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.kmz')) {
    throw RouteImportException(
      'Los archivos KMZ van comprimidos. Expórtalo como KML o GPX.',
    );
  }
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(content);
  } on XmlException {
    throw RouteImportException('El archivo no es un GPX ni un KML válido.');
  }
  final root = doc.rootElement.name.local.toLowerCase();
  if (lower.endsWith('.kml') || root == 'kml') return _kml(doc);
  if (lower.endsWith('.gpx') || root == 'gpx') return _gpx(doc);
  throw RouteImportException('Solo se pueden importar archivos GPX o KML.');
}

// Se compara solo el nombre local: así da igual el espacio de nombres (GPX 1.0/1.1, KML 2.2, gx:…)
Iterable<XmlElement> _all(XmlNode node, String local) => node.descendants
    .whereType<XmlElement>()
    .where((e) => e.name.local == local);

String? _text(XmlNode node, String local) {
  final v = _all(node, local).firstOrNull?.innerText.trim();
  return (v == null || v.isEmpty) ? null : v;
}

LngLat? _gpxPoint(XmlElement e) {
  final lat = double.tryParse(e.getAttribute('lat') ?? '');
  final lon = double.tryParse(e.getAttribute('lon') ?? '');
  return lat == null || lon == null ? null : LngLat(lon, lat);
}

ImportedRoute _gpx(XmlDocument doc) {
  final line = <LngLat>[];
  // Preferimos el track (lo grabado); si no hay, la ruta (puntos de paso)
  for (final p in _all(doc, 'trkpt')) {
    final pt = _gpxPoint(p);
    if (pt != null) line.add(pt);
  }
  if (line.length < 2) {
    line.clear();
    for (final p in _all(doc, 'rtept')) {
      final pt = _gpxPoint(p);
      if (pt != null) line.add(pt);
    }
  }
  if (line.length < 2) {
    throw RouteImportException(
      'El GPX no tiene un trazo con al menos dos puntos.',
    );
  }
  final pois = <Poi>[
    for (final w in _all(doc, 'wpt'))
      if (_gpxPoint(w) case final at?)
        Poi(
          kind: guessPoiKind(
            '${_text(w, 'name') ?? ''} ${_text(w, 'sym') ?? ''} ${_text(w, 'type') ?? ''}',
          ),
          at: at,
          name: _text(w, 'name'),
        ),
  ];
  final trk = _all(doc, 'trk').firstOrNull ?? _all(doc, 'rte').firstOrNull;
  final name =
      (trk == null ? null : _directText(trk, 'name')) ??
      _text(_all(doc, 'metadata').firstOrNull ?? doc, 'name');
  return ImportedRoute(
    name: name,
    line: line,
    pois: pois,
    origin: RouteOrigin.gpx,
  );
}

/// Texto de un hijo directo (no de cualquier descendiente: el nombre de un trkpt no es el del track).
String? _directText(XmlElement parent, String local) {
  final v = parent.childElements
      .where((e) => e.name.local == local)
      .firstOrNull
      ?.innerText
      .trim();
  return (v == null || v.isEmpty) ? null : v;
}

/// "lng,lat[,alt] lng,lat[,alt] …" de un `coordinates` de KML.
List<LngLat> _kmlCoordinates(String raw) => [
  for (final tuple in raw.trim().split(RegExp(r'\s+')))
    if (tuple.split(',') case [final lng, final lat, ...])
      if ((double.tryParse(lng), double.tryParse(lat)) case (
        final x?,
        final y?,
      ))
        LngLat(x, y),
];

ImportedRoute _kml(XmlDocument doc) {
  final line = <LngLat>[];
  for (final ls in _all(doc, 'LineString')) {
    line.addAll(_kmlCoordinates(_text(ls, 'coordinates') ?? ''));
  }
  // Tracks de Google Earth / Garmin: <gx:coord>lng lat alt</gx:coord>
  if (line.length < 2) {
    for (final c in _all(doc, 'coord')) {
      final parts = c.innerText.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final lng = double.tryParse(parts[0]), lat = double.tryParse(parts[1]);
      if (lng != null && lat != null) line.add(LngLat(lng, lat));
    }
  }
  if (line.length < 2) {
    throw RouteImportException(
      'El KML no tiene una línea con al menos dos puntos.',
    );
  }
  final pois = <Poi>[];
  for (final pm in _all(doc, 'Placemark')) {
    final point = _all(pm, 'Point').firstOrNull;
    if (point == null) continue;
    final coords = _kmlCoordinates(_text(point, 'coordinates') ?? '');
    if (coords.isEmpty) continue;
    final name = _directText(pm, 'name');
    pois.add(
      Poi(
        kind: guessPoiKind('${name ?? ''} ${_text(pm, 'description') ?? ''}'),
        at: coords.first,
        name: name,
      ),
    );
  }
  final docEl = _all(doc, 'Document').firstOrNull;
  final lineMark = _all(
    doc,
    'Placemark',
  ).where((pm) => _all(pm, 'LineString').isNotEmpty).firstOrNull;
  final name =
      (lineMark == null ? null : _directText(lineMark, 'name')) ??
      (docEl == null ? null : _directText(docEl, 'name'));
  return ImportedRoute(
    name: name,
    line: line,
    pois: pois,
    origin: RouteOrigin.kml,
  );
}

/// Adivina el tipo de punto por su nombre o símbolo (español e inglés).
PoiKind guessPoiKind(String text) {
  final t = text.toLowerCase();
  bool has(List<String> words) => words.any(t.contains);
  if (has(['agua', 'water', 'fuente', 'manantial', 'spring', 'arroyo'])) {
    return PoiKind.water;
  }
  if (has(['refugio', 'shelter', 'hut', 'albergue', 'cabaña'])) {
    return PoiKind.shelter;
  }
  if (has(['camp', 'vivac', 'bivouac', 'tent'])) return PoiKind.camp;
  if (has(['cumbre', 'cima', 'summit', 'peak', 'pico'])) return PoiKind.summit;
  if (has(['no retorno', 'turnaround', 'retorno'])) return PoiKind.noReturn;
  if (has(['peligro', 'danger', 'grieta', 'crevasse', 'caution', 'cuidado'])) {
    return PoiKind.danger;
  }
  return PoiKind.other;
}
