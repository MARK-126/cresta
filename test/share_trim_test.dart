import 'package:cresta/src/tracking/share_trim.dart';
import 'package:cresta/src/tracking/track.dart';
import 'package:flutter_test/flutter_test.dart';

/// Recorrido recto hacia el norte: un punto cada ~111 m durante [n] puntos.
List<TrackPoint> line(int n, {int pauseAt = -1}) => [
  for (var i = 0; i < n; i++)
    TrackPoint(
      time: DateTime(2026, 11, 14, 10).add(Duration(minutes: i)),
      lng: -68.85,
      lat: -32.9 + i * 0.001,
      altitude: 800.0 + i,
      segment: pauseAt >= 0 && i >= pauseAt ? 1 : 0,
    ),
];

double len(List<TrackPoint> p) => p.length < 2 ? 0 : cumulativeMeters(p).last;

void main() {
  test('sin recorte, todo visible', () {
    final p = line(10);
    final s = splitForSharing(p, 0, 0);
    expect(s.visible, same(p));
    expect(s.before, isEmpty);
    expect(s.after, isEmpty);
  });

  test('oculta los metros pedidos al inicio y al final', () {
    final p = line(11); // ~1,112 m
    final total = len(p);
    final s = splitForSharing(p, 250, 400);
    expect(len(s.before), closeTo(250, 0.5));
    expect(len(s.after), closeTo(400, 0.5));
    expect(len(s.visible), closeTo(total - 650, 0.5));
    // Las partes se tocan: el corte es el mismo punto
    expect(s.before.last.lat, s.visible.first.lat);
    expect(s.visible.last.lat, s.after.first.lat);
    // La altitud y la hora del corte se interpolan
    expect(s.visible.first.altitude, closeTo(802.25, 0.05));
  });

  test('entre pausas no cuenta el salto', () {
    final p = line(10, pauseAt: 5);
    final d = cumulativeMeters(p);
    expect(d[5] - d[4], 0);
  });

  test('recorte mayor que el recorrido: nada visible, sin romperse', () {
    final s = splitForSharing(line(3), 5000, 5000);
    expect(len(s.visible), 0);
  });

  test('el recorrido guarda el recorte (y lo omite si no hay)', () {
    final t = Track(id: 'a', name: 'x', startedAt: DateTime(2026))
      ..hideStart = 420
      ..hideEnd = 310;
    final back = Track.fromJson(t.toJson());
    expect(back.hideStart, 420);
    expect(back.hideEnd, 310);
    expect(back.trimmed, isTrue);
    final plain = Track(id: 'b', name: 'y', startedAt: DateTime(2026));
    expect(plain.toJson().containsKey('hideStartM'), isFalse);
    expect(Track.fromJson(plain.toJson()).trimmed, isFalse);
  });

  test('forSharing usa el recorte del recorrido', () {
    final p = line(11);
    final t = Track(id: 'a', name: 'x', startedAt: DateTime(2026))
      ..hideStart = 300;
    expect(len(forSharing(t, p)), closeTo(len(p) - 300, 0.5));
  });
}
