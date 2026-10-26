import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'expeditions/expedition_store.dart';
import 'location/location_service.dart';
import 'offline/map_sources.dart';
import 'offline/offline_maps.dart';
import 'offline/region_downloader.dart';
import 'offline/sample_data.dart';
import 'offline/tile_store.dart';
import 'routes/route_store.dart';
import 'storage/json_store.dart';
import 'tiles/tile_server.dart';
import 'tracking/terrain_elevation.dart';
import 'tracking/track_recorder.dart';
import 'tracking/track_store.dart';

NetworkKind networkKindOf(List<ConnectivityResult> r) {
  if (r.contains(ConnectivityResult.wifi) ||
      r.contains(ConnectivityResult.ethernet)) {
    return NetworkKind.wifi;
  }
  if (r.contains(ConnectivityResult.mobile) ||
      r.contains(ConnectivityResult.vpn) ||
      r.contains(ConnectivityResult.other)) {
    return NetworkKind.mobile;
  }
  return NetworkKind.none;
}

/// Todo lo que vive mientras la app está abierta.
class AppServices {
  AppServices._(
    this.server,
    this.maps,
    this.expeditions,
    this.cache,
    this.tracks,
    this.recorder,
    this.location,
    this.routes,
    this.terrain,
  );

  final TileServer server;
  final OfflineMaps maps;
  final ExpeditionStore expeditions;
  final TrackStore tracks;
  final TrackRecorder recorder;
  final LocationService location;

  /// Rutas planeadas o importadas (una por expedición).
  final RouteStore routes;

  /// Altitud a partir del relieve descargado (perfil de rutas y desnivel del recorrido).
  final TerrainElevation terrain;

  /// Mosaicos vistos con conexión (no cuentan como descargados; se pueden borrar).
  final TileStore cache;

  static Future<AppServices> start() async {
    final support = await getApplicationSupportDirectory();
    final cacheRoot = await getApplicationCacheDirectory();
    final client = http.Client();
    final offline = TileStore(Directory('${support.path}/tiles'));
    final cache = TileStore(Directory('${cacheRoot.path}/tiles'));
    final topo = TopoTemplate(
      File('${support.path}/topo_tilejson.json'),
      client: client,
    );

    final connectivity = Connectivity();
    final maps = OfflineMaps(
      store: offline,
      downloader: RegionDownloader(
        store: offline,
        client: client,
        topoTemplate: topo.get,
      ),
      regionsFile: JsonStore(File('${support.path}/regions.json')),
      settingsFile: JsonStore(File('${support.path}/settings.json')),
      network: networkKindOf(await connectivity.checkConnectivity()),
      networkChanges: connectivity.onConnectivityChanged.map(networkKindOf),
      onDownloadingChanged: (on) =>
          WakelockPlus.toggle(enable: on).catchError((_) {}),
    );
    await maps.load();
    final expeditions = ExpeditionStore(
      JsonStore(File('${support.path}/expeditions.json')),
      maps,
    );
    await expeditions.load();
    await installSampleOnce(
      supportDir: support,
      maps: maps,
      expeditions: expeditions,
    );

    final tracks = TrackStore(Directory('${support.path}/tracks'));
    await tracks.load();
    final location = LocationService();
    final terrain = TerrainElevation([offline, cache]);
    final recorder = TrackRecorder(
      store: tracks,
      positions: location.recording,
      terrain: terrain.at,
    );
    await recorder.recover();
    final routes = RouteStore(JsonStore(File('${support.path}/routes.json')));
    await routes.load();

    final server = TileServer(
      offline: offline,
      cache: cache,
      topoTemplate: topo.get,
      client: client,
    );
    await server.start();
    unawaited(topo.get()); // deja lista la URL del mapa topográfico si hay red
    return AppServices._(
      server,
      maps,
      expeditions,
      cache,
      tracks,
      recorder,
      location,
      routes,
      terrain,
    );
  }
}

/// Da acceso a [AppServices] desde cualquier pantalla.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.services;

  @override
  bool updateShouldNotify(AppScope old) => old.services != services;
}
