import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'expeditions/expedition_store.dart';
import 'gear/gear.dart';
import 'location/location_service.dart';
import 'map/map_prefs.dart';
import 'map/video_options.dart';
import 'offline/map_sources.dart';
import 'photos/photo_store.dart';
import 'places/place_index.dart';
import 'tips/tips.dart';
import 'offline/offline_maps.dart';
import 'offline/region_downloader.dart';
import 'offline/sample_data.dart';
import 'offline/tile_store.dart';
import 'profile/emergency_profile.dart';
import 'references/references.dart';
import 'routes/route_store.dart';
import 'routing/terrain_router.dart';
import 'routing/trail_router.dart';
import 'storage/json_store.dart';
import 'tiles/tile_server.dart';
import 'tracking/poi_alerts.dart';
import 'tracking/terrain_elevation.dart';
import 'tracking/track_recorder.dart';
import 'tracking/turnaround_alerts.dart';
import 'tracking/track_store.dart';
import 'weather/weather_service.dart';

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
    this.profile,
    this.weather,
    this.gear,
    this.references,
    this.trails,
    this.overland,
    this.places,
    this.tips,
    this.photos,
    this.video,
    this.mapBase,
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

  /// Datos de emergencia del usuario (solo en el teléfono).
  final ProfileStore profile;

  /// Pronósticos guardados por expedición (Open-Meteo).
  final WeatherService weather;

  /// Listas de equipo por expedición.
  final GearStore gear;

  /// Fotos, PDF, enlaces y teléfonos guardados con cada expedición.
  final ReferenceStore references;

  /// Mosaicos vistos con conexión (no cuentan como descargados; se pueden borrar).
  final TileStore cache;

  /// Camino por senderos entre dos puntos con los mapas guardados (sin conexión).
  final TrailRouter trails;

  /// Camino a campo traviesa sobre el relieve guardado, donde no hay sendero.
  final TerrainRouter overland;

  /// Lugares con nombre de las zonas descargadas, para buscar sin señal.
  final PlaceIndex places;

  /// Qué indicaciones de la primera vez ya vio el usuario.
  final TipStore tips;

  /// Fotos tomadas durante los recorridos, con su ubicación.
  final PhotoStore photos;

  /// Opciones del último video del recorrido.
  final VideoOptionsStore video;

  /// Mapa base elegido (Noche de inicio).
  final MapBaseStore mapBase;

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

    final photos = PhotoStore(Directory('${support.path}/photos'));
    await photos.load();
    final tracks = TrackStore(
      Directory('${support.path}/tracks'),
      onDeleted: photos.deleteForTrack,
    );
    await tracks.load();
    final location = LocationService();
    final terrain = TerrainElevation([offline, cache]);
    final recorder = TrackRecorder(
      store: tracks,
      positions: location.recording,
      terrain: terrain.at,
    );
    await recorder.recover();
    TurnaroundAlerts(
      recorder: recorder,
      sink: const SystemAlertSink(),
    ).attach();
    PoiAlerts(recorder: recorder, sink: const SystemAlertSink()).attach();
    final routes = RouteStore(JsonStore(File('${support.path}/routes.json')));
    await routes.load();
    final profile = ProfileStore(
      JsonStore(File('${support.path}/profile.json')),
    );
    await profile.load();
    final tips = TipStore(JsonStore(File('${support.path}/tips.json')));
    await tips.load();
    final video = VideoOptionsStore(
      JsonStore(File('${support.path}/video.json')),
    );
    await video.load();
    final mapBase = MapBaseStore(JsonStore(File('${support.path}/map.json')));
    await mapBase.load();
    final weather = WeatherService(
      client: client,
      file: JsonStore(File('${support.path}/weather.json')),
    );
    await weather.load();
    final gear = GearStore(JsonStore(File('${support.path}/gear.json')));
    await gear.load();
    final references = ReferenceStore(
      JsonStore(File('${support.path}/references.json')),
      Directory('${support.path}/references'),
    );
    await references.load();

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
      profile,
      weather,
      gear,
      references,
      TrailRouter.fromStores([offline, cache], dem: terrain.grid),
      TerrainRouter(terrain.grid),
      PlaceIndex(
        regions: () => maps.regions,
        topoDir: '${offline.root.path}/${MapSource.topo.name}',
        file: File('${support.path}/places.json'),
      ),
      tips,
      photos,
      video,
      mapBase,
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
