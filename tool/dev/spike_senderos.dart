// ignore_for_file: avoid_print, avoid_relative_lib_imports
// Experimento: leer los senderos de los mosaicos descargados, en Dart puro.
// Uso: dart tool/dev/spike_senderos.dart RUTA_DEL_PAQUETE   (carpeta con topo/z/x/y)
import 'dart:io';
import 'dart:typed_data';

import '../../lib/src/tiles/mvt.dart';

void main(List<String> args) {
  final root = Directory('${args.first}/topo');
  final files = [
    for (final f in root.listSync(recursive: true))
      if (f is File) f,
  ];
  final sw = Stopwatch()..start();
  final classes = <String, int>{};
  final layers = <String, int>{};
  var tiles = 0;
  for (final f in files) {
    final parts = f.path.split('/');
    final z = int.parse(parts[parts.length - 3]);
    final bytes = f.readAsBytesSync();
    final ls = decodeMvt(Uint8List.fromList(bytes));
    tiles++;
    for (final l in ls) {
      layers[l.name] = (layers[l.name] ?? 0) + l.features.length;
      if (l.name == 'transportation') {
        for (final ft in l.features) {
          final k = 'z$z ${ft.props['class']}/${ft.props['subclass'] ?? '-'}';
          classes[k] = (classes[k] ?? 0) + 1;
        }
      }
    }
  }
  sw.stop();
  print(
    '$tiles mosaicos en ${sw.elapsedMilliseconds} ms (${(sw.elapsedMilliseconds / tiles).toStringAsFixed(1)} ms cada uno)',
  );
  print('capas: $layers');
  final keys = classes.keys.toList()..sort();
  for (final k in keys) {
    print('  $k: ${classes[k]}');
  }
}
