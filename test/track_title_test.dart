import 'package:cresta/src/tracking/track.dart';
import 'package:cresta/src/ui/format.dart';
import 'package:cresta/src/ui/route_silhouette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el título quita la fecha que el nombre automático ya trae', () {
    final start = DateTime(2026, 11, 13, 19, 7);
    final t = Track(
      id: 'a',
      name: 'Recorrido 3 · ${fmtDate(start)}',
      startedAt: start,
    );
    expect(trackTitle(t), 'Recorrido 3');
  });

  test('un nombre propio queda igual', () {
    final t = Track(
      id: 'b',
      name: 'Subida al Cerro Arco',
      startedAt: DateTime(2026, 11, 13),
    );
    expect(trackTitle(t), 'Subida al Cerro Arco');
  });
}
