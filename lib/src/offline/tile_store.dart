import 'dart:io';

import 'package:flutter/foundation.dart';

import 'map_sources.dart';

/// Mosaicos guardados en disco como `<raíz>/<fuente>/<z>/<x>/<y>`.
///
/// Las zonas descargadas comparten mosaicos: si dos zonas se traslapan, el mosaico se guarda una vez.
class TileStore {
  TileStore(this.root);

  final Directory root;

  File file(MapSource source, int z, int x, int y) =>
      File('${root.path}/${source.name}/$z/$x/$y');

  Future<bool> has(MapSource source, int z, int x, int y) =>
      file(source, z, x, y).exists();

  Future<Uint8List?> read(MapSource source, int z, int x, int y) async {
    final f = file(source, z, x, y);
    return await f.exists() ? f.readAsBytes() : null;
  }

  /// Escribe a un archivo temporal y lo renombra, para no dejar mosaicos a medias si la app se cierra.
  Future<void> write(
    MapSource source,
    int z,
    int x,
    int y,
    List<int> bytes,
  ) async {
    final f = file(source, z, x, y);
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.part');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(f.path);
  }

  Future<int> delete(MapSource source, int z, int x, int y) async {
    final f = file(source, z, x, y);
    if (!await f.exists()) return 0;
    final size = await f.length();
    await f.delete();
    return size;
  }

  /// Bytes ocupados en disco.
  Future<int> sizeOnDisk() async {
    if (!await root.exists()) return 0;
    var total = 0;
    await for (final e in root.list(recursive: true, followLinks: false)) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  Future<void> clear() async {
    if (await root.exists()) await root.delete(recursive: true);
  }
}
