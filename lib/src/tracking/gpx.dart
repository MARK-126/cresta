import 'track.dart';

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// GPX 1.1 con un `<trkseg>` por tramo (las pausas separan tramos).
/// Lo abren Wikiloc, Strava, Garmin, Google Earth, etc.
String toGpx(Track track, List<TrackPoint> points) {
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<gpx version="1.1" creator="Cresta" xmlns="http://www.topografix.com/GPX/1/1">',
    )
    ..writeln(
      '  <metadata><name>${_esc(track.name)}</name><time>${track.startedAt.toUtc().toIso8601String()}</time></metadata>',
    )
    ..writeln('  <trk>')
    ..writeln('    <name>${_esc(track.name)}</name>');
  int? segment;
  for (final p in points) {
    if (p.segment != segment) {
      if (segment != null) b.writeln('    </trkseg>');
      b.writeln('    <trkseg>');
      segment = p.segment;
    }
    b.write(
      '      <trkpt lat="${p.lat.toStringAsFixed(6)}" lon="${p.lng.toStringAsFixed(6)}">',
    );
    if (p.altitude != null) {
      b.write('<ele>${p.altitude!.toStringAsFixed(1)}</ele>');
    }
    b.writeln('<time>${p.time.toUtc().toIso8601String()}</time></trkpt>');
  }
  if (segment != null) b.writeln('    </trkseg>');
  b
    ..writeln('  </trk>')
    ..writeln('</gpx>');
  return b.toString();
}
