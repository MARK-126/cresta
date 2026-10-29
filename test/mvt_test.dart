import 'dart:typed_data';
import 'dart:io';
import 'dart:math' as math;

import 'package:cresta/src/tiles/mvt.dart';
import 'package:cresta/src/tiles/tile_clip.dart';
import 'package:flutter_test/flutter_test.dart';

/// Metros entre dos puntos (lng, lat), aproximado.
double _m((double, double) a, (double, double) b) {
  final dLat = (b.$2 - a.$2) * 111320;
  final dLng = (b.$1 - a.$1) * 111320 * math.cos(a.$2 * math.pi / 180);
  return math.sqrt(dLat * dLat + dLng * dLng);
}

void main() {
  // Un mosaico real (z14, x 3705, y 7304) del paquete del Izta, con 4 senderos
  final bytes = File('test/fixtures/topo_14_3705_7304.pbf').readAsBytesSync();

  group('Decodificar un mosaico vectorial', () {
    test('lee sus capas y los senderos con sus propiedades', () {
      final layers = decodeMvt(bytes);
      final transport = layers.firstWhere((l) => l.name == 'transportation');
      expect(transport.extent, 4096);
      final trails = [
        for (final f in transport.features)
          if (f.type == 2 &&
              (f.props['class'] == 'path' || f.props['class'] == 'track'))
            f,
      ];
      expect(trails.length, 4);
      for (final t in trails) {
        expect(t.parts, isNotEmpty);
        for (final part in t.parts) {
          expect(part.length, greaterThanOrEqualTo(2));
        }
      }
    });

    test('un mosaico vacío o sin capas no falla', () {
      expect(decodeMvt(Uint8List(0)), isEmpty);
    });
  });

  group('Coordenadas del mosaico', () {
    test('la esquina de un mosaico y su tamaño real', () {
      final nw = tilePointToLngLat(14, 3705, 7304, 0, 0, 4096);
      final ne = tilePointToLngLat(14, 3705, 7304, 4096, 0, 4096);
      final sw = tilePointToLngLat(14, 3705, 7304, 0, 4096, 4096);
      expect(ne.$1, greaterThan(nw.$1)); // al este
      expect(sw.$2, lessThan(nw.$2)); // al sur
      // A 19° N un mosaico z14 mide unos 2.3 km
      expect(_m(nw, ne), inInclusiveRange(2200, 2400));
      expect(_m(nw, sw), inInclusiveRange(2200, 2400));
      // El mosaico 0/0/0 empieza en −180° y llega al límite del mapa web
      final world = tilePointToLngLat(0, 0, 0, 0, 0, 4096);
      expect(world.$1, closeTo(-180, 1e-9));
      expect(world.$2, closeTo(85.0511, 1e-3));
    });

    test('los senderos del mosaico caen dentro de su cuadro tras recortar', () {
      final transport = decodeMvt(bytes)
          .firstWhere((l) => l.name == 'transportation');
      for (final f in transport.features) {
        if (f.type != 2) continue;
        for (final part in f.parts) {
          for (final run in clipLineToTile(part, transport.extent)) {
            for (final p in run) {
              expect(p.$1, inInclusiveRange(0, 4096));
              expect(p.$2, inInclusiveRange(0, 4096));
            }
          }
        }
      }
    });
  });

  group('Recortar líneas al mosaico', () {
    test('una línea adentro queda igual y sin partirse', () {
      final runs = clipLineToTile(const [
        (100, 100),
        (200, 200),
        (300, 300),
      ], 4096);
      expect(runs.length, 1);
      expect(runs.single, const [
        (100.0, 100.0),
        (200.0, 200.0),
        (300.0, 300.0),
      ]);
    });

    test('una línea que sale se corta justo en el borde', () {
      final runs = clipLineToTile(const [(4000, 100), (4200, 100)], 4096);
      expect(runs.single, const [(4000.0, 100.0), (4096.0, 100.0)]);
    });

    test(
      'una línea que atraviesa todo el mosaico se corta en los dos bordes',
      () {
        final runs = clipLineToTile(const [(-100, 500), (5000, 500)], 4096);
        expect(runs.single, const [(0.0, 500.0), (4096.0, 500.0)]);
      },
    );

    test('lo que cae por completo en el margen se descarta', () {
      expect(clipLineToTile(const [(5000, 100), (6000, 100)], 4096), isEmpty);
      expect(clipLineToTile(const [(100, -300), (200, -100)], 4096), isEmpty);
    });

    test('una línea que sale y vuelve a entrar da dos tramos', () {
      final runs = clipLineToTile(const [
        (10, 10),
        (-50, 10),
        (-50, 100),
        (10, 100),
      ], 4096);
      expect(runs.length, 2);
      expect(runs.first, const [(10.0, 10.0), (0.0, 10.0)]);
      expect(runs.last, const [(0.0, 100.0), (10.0, 100.0)]);
    });

    test('el corte en diagonal cae exactamente en el borde', () {
      final run = clipLineToTile(const [(4000, 0), (4196, 196)], 4096).single;
      expect(run.last.$1, 4096.0);
      expect(run.last.$2, closeTo(96, 1e-9));
    });
  });
}
