import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Un paquete de mosaicos (relieve + satélite) incluido en la app como zip.
class OfflinePack {
  const OfflinePack({required this.id, required this.name, required this.asset, required this.version});

  final String id;
  final String name;
  final String asset;

  /// Súbelo cuando cambie el zip para que se vuelva a extraer.
  final int version;

  static const iztaPopo = OfflinePack(
    id: 'izta_popo',
    name: 'Iztaccíhuatl–Popocatépetl',
    asset: 'assets/packs/izta_popo.zip',
    version: 1,
  );

  /// Extrae el zip la primera vez y devuelve la carpeta con `<tipo>/<z>/<x>/<y>`.
  Future<Directory> install() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/packs/$id');
    final stamp = File('${dir.path}/.version');
    if (await stamp.exists() && (await stamp.readAsString()).trim() == '$version') return dir;

    if (await dir.exists()) await dir.delete(recursive: true);
    final data = await rootBundle.load(asset);
    final archive = ZipDecoder().decodeBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    for (final entry in archive) {
      if (!entry.isFile || entry.name.contains('..')) continue;
      final f = File('${dir.path}/${entry.name}');
      await f.parent.create(recursive: true);
      await f.writeAsBytes(entry.content);
    }
    await stamp.writeAsString('$version');
    return dir;
  }
}

Future<Directory> tileCacheDir() async {
  final cache = await getApplicationCacheDirectory();
  final dir = Directory('${cache.path}/tiles');
  await dir.create(recursive: true);
  return dir;
}
