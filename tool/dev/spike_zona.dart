// ignore_for_file: avoid_print, avoid_relative_lib_imports
// Experimento 3: cuántos senderos trae una zona descargada y dónde están.
// Uso: dart tool/dev/spike_zona.dart RUTA_DEL_PAQUETE
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../lib/src/tiles/mvt.dart';
import '../../lib/src/tiles/tile_clip.dart';

double _m(double lng1, double lat1, double lng2, double lat2) {
  final dLat = (lat2 - lat1) * 111320;
  final dLng =
      (lng2 - lng1) * 111320 * math.cos((lat1 + lat2) / 2 * math.pi / 180);
  return math.sqrt(dLat * dLat + dLng * dLng);
}

void main(List<String> args) {
  final root = Directory('${args.first}/topo/14');
  var km = 0.0, lines = 0, tilesWith = 0, tiles = 0;
  var w = 999.0, s = 999.0, e = -999.0, n = -999.0;
  final perClass = <String, double>{};
  for (final f in root.listSync(recursive: true)) {
    if (f is! File) continue;
    final parts = f.path.split('/');
    final x = int.parse(parts[parts.length - 2]), y = int.parse(parts.last);
    tiles++;
    var any = false;
    for (final layer in decodeMvt(Uint8List.fromList(f.readAsBytesSync()))) {
      if (layer.name != 'transportation') continue;
      for (final ft in layer.features) {
        final c = ft.props['class'];
        if (ft.type != 2 || (c != 'path' && c != 'track')) continue;
        for (final part in ft.parts) {
          for (final run in clipLineToTile(part, layer.extent)) {
            final pts = [
              for (final q in run)
                tilePointToLngLat(14, x, y, q.$1, q.$2, layer.extent),
            ];
            for (var i = 0; i < pts.length; i++) {
              w = math.min(w, pts[i].$1);
              e = math.max(e, pts[i].$1);
              s = math.min(s, pts[i].$2);
              n = math.max(n, pts[i].$2);
              if (i > 0) {
                final d = _m(
                  pts[i - 1].$1,
                  pts[i - 1].$2,
                  pts[i].$1,
                  pts[i].$2,
                );
                km += d / 1000;
                perClass['$c'] = (perClass['$c'] ?? 0) + d / 1000;
              }
            }
            lines++;
            any = true;
          }
        }
      }
    }
    if (any) tilesWith++;
  }
  print(
    'z14: $tiles mosaicos, $tilesWith con senderos; $lines líneas, ${km.toStringAsFixed(1)} km',
  );
  print(
    'por clase: ${perClass.map((k, v) => MapEntry(k, v.toStringAsFixed(1)))}',
  );
  print(
    'caja de los senderos: oeste ${w.toStringAsFixed(3)} sur ${s.toStringAsFixed(3)} este ${e.toStringAsFixed(3)} norte ${n.toStringAsFixed(3)}',
  );
}
