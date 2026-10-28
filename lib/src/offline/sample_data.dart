import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';

import '../expeditions/expedition.dart';
import '../expeditions/expedition_store.dart';
import '../storage/json_store.dart';
import 'map_sources.dart';
import 'offline_maps.dart';
import 'offline_region.dart';
import 'tile_math.dart';

/// Zona del paquete incluido en la app. Debe coincidir con `tool/download_tiles.py` (WIDE).
final samplePackRegion = OfflineRegion(
  id: 'sample-izta-popo',
  name: 'Iztaccíhuatl–Popocatépetl',
  bbox: const BBox(-98.82, 18.92, -98.46, 19.24),
  detail: DetailLevel.basic,
  sources: {MapSource.dem, MapSource.sat, MapSource.topo},
  status: RegionStatus.complete,
  bundled: true,
);

/// Id de la expedición de ejemplo.
const sampleExpeditionId = 'sample-arista-del-sol';

/// La primera vez: copia el paquete del Izta–Popo al almacén de mosaicos y crea la expedición de ejemplo.
/// Si el usuario borra el ejemplo, no se vuelve a crear.
Future<void> installSampleOnce({
  required Directory supportDir,
  required OfflineMaps maps,
  required ExpeditionStore expeditions,
  AssetBundle? bundle,
}) async {
  final flag = JsonStore(File('${supportDir.path}/sample_installed.json'));
  if (await flag.read() == true) {
    // Versiones anteriores dejaban borrar la zona incluida y el ejemplo se
    // quedaba sin mapas: si sigue ahí sin ellos, se reinstalan.
    final sample = expeditions.byId(sampleExpeditionId);
    if (sample == null) return;
    if (maps.byId(samplePackRegion.id) == null) {
      await _installPack(maps, bundle);
    }
    if (!sample.regionIds.contains(samplePackRegion.id)) {
      await expeditions.attachRegion(sample, samplePackRegion.id);
    }
    return;
  }

  await _installPack(maps, bundle);
  await expeditions.addExisting(
    Expedition(
      id: sampleExpeditionId,
      name: 'Iztaccíhuatl por La Arista del Sol',
      notes: 'Expedición de ejemplo. Sus mapas vienen incluidos en la app, así que funciona sin conexión desde el primer momento.',
      regionIds: [samplePackRegion.id],
      routeAsset: 'assets/data/arista_del_sol.json',
      sample: true,
    ),
  );
  await flag.write(true);
}

/// Descomprime el paquete en el almacén de mosaicos y registra su zona.
Future<void> _installPack(OfflineMaps maps, AssetBundle? bundle) async {
  final data = await (bundle ?? rootBundle).load('assets/packs/izta_popo.zip');
  final archive = ZipDecoder().decodeBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  var bytes = 0;
  for (final entry in archive) {
    if (!entry.isFile || entry.name.contains('..')) continue;
    final f = File('${maps.store.root.path}/${entry.name}');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(entry.content);
    bytes += entry.size;
  }
  await maps.addExisting(
    samplePackRegion
      ..doneTiles = samplePackRegion.totalTiles
      ..bytes = bytes,
  );
}
