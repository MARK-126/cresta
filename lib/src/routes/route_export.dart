import 'planned_route.dart';

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// GPX 1.1 de una ruta planeada: el trazo como `<trk>` (con altitud) y los puntos de
/// interés como `<wpt>`. Se abre en Wikiloc, Garmin, Google Earth, etc.
String routeToGpx(PlannedRoute route) {
  final p = route.profile;
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<gpx version="1.1" creator="Cresta" xmlns="http://www.topografix.com/GPX/1/1">',
    )
    ..writeln('  <metadata><name>${_esc(route.name)}</name></metadata>');
  for (final poi in route.pois) {
    b.writeln(
      '  <wpt lat="${poi.at.lat.toStringAsFixed(6)}" lon="${poi.at.lng.toStringAsFixed(6)}">'
      '<name>${_esc(poi.name)}</name><type>${_esc(poi.kind.label)}</type></wpt>',
    );
  }
  b
    ..writeln('  <trk>')
    ..writeln('    <name>${_esc(route.name)}</name>')
    ..writeln('    <trkseg>');
  for (var i = 0; i < p.coordinates.length; i++) {
    final c = p.coordinates[i];
    b.writeln(
      '      <trkpt lat="${c.lat.toStringAsFixed(6)}" lon="${c.lng.toStringAsFixed(6)}">'
      '<ele>${p.elevations[i].toStringAsFixed(1)}</ele></trkpt>',
    );
  }
  b
    ..writeln('    </trkseg>')
    ..writeln('  </trk>')
    ..writeln('</gpx>');
  return b.toString();
}
