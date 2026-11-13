import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app_services.dart';
import '../data/asset_repository.dart';
import '../data/civil_data.dart';
import '../data/trail_route.dart';
import '../expeditions/expedition.dart';
import '../group/group_simulator.dart';
import '../location/location_service.dart';
import '../map/map_bridge.dart';
import '../map/map_layers.dart';
import '../offline/tile_math.dart';
import '../places/places.dart';
import '../tips/tips.dart';
import '../routes/planned_route.dart';
import '../routes/route_planner.dart';
import '../tracking/track.dart';
import '../tracking/track_recorder.dart';
import 'area_picker_screen.dart';
import 'route_destination.dart';
import '../routes/route_compare.dart';
import 'format.dart';
import 'offline_widgets.dart';
import 'panels.dart';
import 'planner_panel.dart';
import 'photo_screen.dart';
import 'map_chrome.dart';
import 'place_search_sheet.dart';
import 'recording_panel.dart';
import 'route_actions.dart';
import 'sos_screen.dart';
import 'theme.dart';
import 'tip_dialog.dart';
import 'track_screen.dart';

/// El mapa de una expedición, en 2D o 3D, con lo descargado y (si hay red) lo demás.
/// Sin [expeditionId] es el mapa libre: se explora, se trazan rutas y se graba sin expedición
/// (el recorrido queda libre, en la Bitácora).
/// "Ruta hasta aquí" sale de tu posición solo si el lugar está a menos de esto; más
/// lejos se pregunta desde dónde sales (nadie camina 200 km desde su casa).
const routeFromMeMaxMeters = 50000.0;

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    this.expeditionId,
    this.routeId,
    this.compareRouteIds,
    this.showTrackId,
    this.plan = false,
    this.record = false,
    this.video = false,
  });
  final String? expeditionId;

  /// Ruta guardada que se muestra (y se edita) al abrir; sin ella, la de la expedición.
  final String? routeId;

  /// Rutas que se superponen para compararlas (mapa libre, sin planear ni grabar).
  final List<String>? compareRouteIds;

  /// Abrir directo en modo planificar ruta.
  final bool plan;

  /// Abrir y empezar a grabar ("Grabar desde aquí" del inicio).
  final bool record;

  /// Recorrido ya grabado que se muestra al abrir (desde su detalle).
  final String? showTrackId;

  /// Con [showTrackId]: sobrevuelo 3D del recorrido grabado a video, y compartirlo.
  final bool video;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _bridge = MapBridge();

  /// Lo que hay abajo (barra, tarjeta o tira): se mide para centrar el mapa en lo visible.
  final _bottomKey = GlobalKey();
  double _bottomInset = 0;
  late final LocationService _location = _services.location;
  late final TrackRecorder _recorder = _services.recorder;
  DateTime _lastTrackPush = DateTime.fromMillisecondsSinceEpoch(0);
  bool _following = false;
  bool _centeredOnFirstFix = false;
  final _subs = <StreamSubscription<dynamic>>[];
  late AppServices _services;
  late Expedition _expedition;

  /// Mapa abierto desde el inicio, sin expedición.
  bool get _free => widget.expeditionId == null;

  bool get _comparing => widget.compareRouteIds != null;

  /// Las rutas comparadas con su color, para el mapa y la leyenda.
  List<PlannedRoute> get _compared => [
    for (final id in widget.compareRouteIds ?? const <String>[])
      if (_services.routes.byId(id) != null) _services.routes.byId(id)!,
  ];

  /// La ruta para el mapa: su perfil más los tramos y si siguen sendero (los rectos van punteados).
  Map<String, dynamic> _mapJson(PlannedRoute r) => {
    ...r.profile.toJson(),
    'legs': [
      for (var i = 0; i < r.legs.length; i++)
        {
          'coordinates': [
            for (final p in r.legs[i]) [p.lng, p.lat],
          ],
          'snapped': r.snapped[i],
        },
    ],
  };

  List<Map<String, Object>> _compareLines() => [
    for (var i = 0; i < _compared.length; i++)
      {
        'coordinates': [
          for (final p in _compared[i].profile.coordinates) [p.lng, p.lat],
        ],
        'color': compareHex[i],
      },
  ];

  /// Ruta guardada que se muestra y se edita: la pedida, o la de la expedición.
  String? _routeId;

  PlannedRoute? get _savedRoute {
    final id = _routeId;
    if (id != null) return _services.routes.byId(id);
    return _free ? null : _services.routes.forExpedition(_expedition.id);
  }

  TrailRoute? _route;
  Map<String, dynamic>? _routeJson;

  /// Mientras se planea la ruta (null fuera del modo planificar).
  RoutePlanner? _planner;
  PoiKind? _placingPoi;
  CivilData? _civil;
  GroupSimulator? _group;

  AppMode _mode = AppMode.mountain;
  late Map<String, bool> _layers = layerPreset(_mode);
  MapBase _base = MapBase.topo;
  bool _is3d = true;
  double _exaggeration = 1.4;
  bool _flying = false;
  double? _cursor;
  bool _locating = false;

  /// Última posición leída en el mapa (para "Mi ubicación" sin grabar).
  (double, double)? _myPos;
  bool _centerOnFix = false;

  /// Lugar elegido en la búsqueda (marcado en el mapa hasta cerrarlo).
  MapPlace? _found;

  /// Giro del mapa en grados (0 = norte arriba), para la brújula.
  double _bearing = 0;

  /// Video del recorrido en curso (sobrevuelo grabándose o guardándose).
  _VideoJob? _video;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _services = AppScope.of(context);
    _routeId = widget.routeId;
    _expedition = _free
        ? Expedition(
            id: '',
            name: 'Mapa libre',
            regionIds: [for (final r in _services.maps.regions) r.id],
          )
        : _services.expeditions.byId(widget.expeditionId!)!;
    _services.maps.addListener(_pushRegions);
    _recorder.addListener(_onRecorder);
    _bridge.load(_services.server.baseUri);
    _subs.add(_bridge.events.listen(_onMapEvent));
    _boot();
  }

  Future<void> _boot() async {
    const assets = AssetData();
    Map<String, dynamic>? civilJson;
    // La ruta guardada (planeada o importada) tiene prioridad sobre la de ejemplo
    final saved = _savedRoute;
    if (saved != null) {
      _route = saved.profile;
      _routeJson = _mapJson(saved);
    } else if (_expedition.routeAsset != null) {
      final (route, json) = await assets.route(_expedition.routeAsset!);
      _routeJson = json;
      _route = route;
      _group = GroupSimulator(route);
      _subs.add(
        _group!.updates.listen((m) {
          if (mounted) setState(() {});
          _pushMembers(m);
        }),
      );
    }
    if (_expedition.sample) {
      final (civil, json) = await assets.civil();
      _civil = civil;
      civilJson = json;
    }
    if (mounted) setState(() {});

    await _bridge.ready;
    if (!mounted) return;
    await _pushPadding();
    await _bridge.setBase(_base);
    await _bridge.setLayers(_layers);
    _pushRegions();
    if (_routeJson != null) await _bridge.setRoute(_routeJson);
    if (saved != null) await _bridge.setPois(saved.pois);
    if (civilJson != null) await _bridge.setCivil(civilJson);
    await _bridge.set3d(true);
    // Mapa libre: encuadra la última zona descargada (todas juntas podrían abarcar medio mundo)
    final bounds = _free
        ? _services.maps.regions.lastOrNull?.bbox
        : _services.expeditions.statusOf(_expedition).bounds;
    if (_comparing) {
      if (mounted) setState(() => _is3d = false);
      await _bridge.set3d(false);
      await _bridge.setCompare(_compareLines());
    } else if (_route != null) {
      await _bridge.fitRoute();
    } else if (bounds != null) {
      await _bridge.fitBounds(bounds);
    }
    if (_group != null) {
      _pushMembers(_group!.members);
      _group!.start();
    }
    if (_recordingHere) {
      // Recorrido en curso o recuperado tras cerrar la app: vuelve a tener ruta y hora límite
      _recorder.route ??= _route;
      if (_recorder.pois.isEmpty) {
        _recorder.pois = _savedRoute?.pois ?? const [];
      }
      _recorder.turnaround ??= _expedition.turnaroundOn(
        _recorder.track!.startedAt,
      );
      await _bridge.setTrack(_recorder.points);
      await _bridge.setPhotos(_services.photos.forTrack(_recorder.track!.id));
      _recoverPhoto();
      final fix = _recorder.lastFix;
      if (fix != null) await _bridge.setMyLocation(fix.lng, fix.lat);
      _following = _centeredOnFirstFix = true;
      await _bridge.setFollow(true, zoom: 15);
    } else if (widget.showTrackId != null) {
      final points = await _services.tracks.readPoints(widget.showTrackId!);
      await _bridge.setTrack(points, showEnd: true);
      await _bridge.setPhotos(_services.photos.forTrack(widget.showTrackId!));
      if (widget.video && points.length > 1) {
        _startVideo(points);
      } else if (points.length > 1) {
        await _bridge.fitBounds(_boundsOf(points));
      }
    }
    if (widget.plan && mounted) _startPlanning();
    if (widget.record && mounted && !_recordingHere) await _startRecording();
    if (mounted && !widget.plan && !widget.record && !widget.video) {
      showTipOnce(context, Tips.map);
    }
    if (mounted) {
      await _autoLocate(
        center:
            _free &&
            _route == null &&
            widget.showTrackId == null &&
            !_comparing &&
            !widget.plan,
      );
    }
  }

  // ------------------------------------------------------------ Planificar ruta

  /// Tramo por senderos: primero con los mapas guardados (fase E, todo el camino aunque no
  /// se vea); si ahí no hay, con lo que muestra el mapa en pantalla.
  Future<List<LngLat>?> _snapLeg(LngLat from, LngLat to) async =>
      await _services.trails.route(from, to) ?? await _bridge.snapLeg(from, to);

  void _startPlanning() {
    if (_recordingHere) return;
    _bridge.stopFly();
    final saved = _savedRoute;
    final route = _route;
    final planner = RoutePlanner(
      snap: _snapLeg,
      overland: _services.overland.route,
      elevation: _services.terrain.at,
      // Sin ruta guardada pero con la de ejemplo: se parte de ella para poder ajustarla
      initial:
          saved ??
          (route == null
              ? null
              : PlannedRoute(
                  name: route.name,
                  waypoints: [route.coordinates.first, route.coordinates.last],
                  legs: [route.coordinates],
                  snapped: const [true],
                  pois: const [],
                  profile: route,
                )),
    )..addListener(_onPlanner);
    setState(() {
      _planner = planner;
      _flying = false;
      _is3d = false; // vista cenital: los toques caen donde se ve
    });
    _bridge.set3d(false);
    _bridge.setPlanMode(true);
    _bridge.setRoute(null);
    _pushPlan();
    showTipOnce(context, Tips.plan);
  }

  void _onPlanner() {
    if (!mounted) return;
    setState(() {});
    _pushPlan();
  }

  void _pushPlan() {
    final p = _planner;
    if (p == null) return;
    _bridge.setPlan(p.legs, snapped: p.snapped, waypoints: p.waypoints);
    _bridge.setPois(p.pois);
  }

  void _onMapTap(LngLat at) {
    final p = _planner;
    if (p == null) return;
    final kind = _placingPoi;
    if (kind != null) {
      p.addPoi(Poi(kind: kind, at: at));
      setState(() => _placingPoi = null);
    } else {
      p.addPoint(at);
    }
  }

  Future<void> _savePlan() async {
    final p = _planner;
    if (p == null || !p.canSave) return;
    final saved = _savedRoute;
    final name = await askRouteName(
      context,
      saved?.name ??
          (_free
              ? 'Ruta del ${fmtDate(DateTime.now())}, ${_hhmm(DateTime.now())}'
              : 'Ruta de ${_expedition.name}'),
    );
    if (name == null || !mounted) return;
    // En el mapa libre una ruta nueva puede quedar sola o ir a una expedición
    var expeditionId = saved?.expeditionId ?? (_free ? null : _expedition.id);
    if (_free && saved == null) {
      final dest = await askRouteDestination(context);
      if (dest == null || !mounted) return;
      expeditionId = dest.expeditionId;
    }
    final route = p.toRoute(name, id: saved?.id, expeditionId: expeditionId);
    await _services.routes.save(route);
    _routeId = route.id;
    _route = route.profile;
    _routeJson = _mapJson(route);
    _endPlanning();
    if (!mounted) return;
    _setLayer('route', true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Ruta guardada: ${fmtKm(route.profile.totalMeters)} km · +${fmtInt(route.profile.gain)} m',
        ),
      ),
    );
  }

  Future<bool> _cancelPlan() async {
    final p = _planner;
    if (p == null) return true;
    final saved = _savedRoute;
    final changed = saved == null ? !p.isEmpty : true;
    if (changed) {
      final ok = await confirmDialog(
        context,
        title: '¿Salir sin guardar?',
        body: 'Se pierden los cambios de la ruta.',
        action: 'Salir',
      );
      if (!ok) return false;
    }
    _endPlanning();
    return true;
  }

  void _endPlanning() {
    _planner
      ?..removeListener(_onPlanner)
      ..dispose();
    _bridge.setPlanMode(false);
    _bridge.setPlan(null);
    _bridge.setRoute(_routeJson);
    _bridge.setPois(_savedRoute?.pois ?? []);
    if (mounted) {
      setState(() {
        _planner = null;
        _placingPoi = null;
      });
    }
  }

  BBox _boundsOf(List<TrackPoint> pts) {
    var w = pts.first.lng, e = w, s = pts.first.lat, n = s;
    for (final p in pts) {
      w = math.min(w, p.lng);
      e = math.max(e, p.lng);
      s = math.min(s, p.lat);
      n = math.max(n, p.lat);
    }
    // Un recorrido muy corto se agranda para que el encuadre tenga sentido
    return BBox(
      w,
      s,
      e == w ? e + 0.001 : e,
      n == s ? n + 0.001 : n,
    ).expandKm(0.3);
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ------------------------------------------------------------ Grabación

  /// Expedición de los recorridos que se graban aquí (null en el mapa libre).
  String? get _trackExpeditionId => _free ? null : _expedition.id;

  /// Hay un recorrido en curso de esta expedición (o libre, en el mapa libre).
  bool get _recordingHere =>
      _recorder.isActive && _recorder.track?.expeditionId == _trackExpeditionId;

  void _onRecorder() {
    if (!mounted) return;
    setState(() {});
    if (!_recordingHere) return;
    final fix = _recorder.lastFix;
    if (fix != null) {
      _bridge.setMyLocation(fix.lng, fix.lat);
      if (_following && !_centeredOnFirstFix) {
        _centeredOnFirstFix = true;
        _bridge.setFollow(true, zoom: 15);
      }
    }
    // Redibujar la línea a lo sumo cada 2 s
    final now = DateTime.now();
    if (now.difference(_lastTrackPush) > const Duration(seconds: 2)) {
      _lastTrackPush = now;
      _bridge.setTrack(_recorder.points);
    }
  }

  Future<void> _startRecording() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_recorder.isActive) {
      final other = _services.expeditions.byId(_recorder.track!.expeditionId);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            other == null
                ? 'Ya hay un recorrido libre en curso (en el mapa libre). Termínalo primero.'
                : 'Ya hay un recorrido en curso en "${other.name}". Termínalo primero.',
          ),
        ),
      );
      return;
    }
    final status = await _location.ensurePermission();
    if (!mounted) return;
    if (status != LocationStatus.granted) {
      messenger.showSnackBar(_permissionSnack(status));
      return;
    }
    await showTipOnce(context, Tips.record);
    if (!mounted) return;
    final mode = await askRecordingMode(context);
    if (mode == null || !mounted) return;
    // Si lo niega se graba igual, pero avisamos del riesgo
    if (!await _location.ensureNotifications()) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Sin permiso de notificaciones no verás el aviso de grabación y Android podría detenerla con la pantalla bloqueada. Puedes activarlo en Ajustes.',
          ),
        ),
      );
    }
    if (!mounted) return;
    // Samsung "optimiza" la batería de las apps y puede cortar la grabación a media montaña
    if (!await _location.batteryUnrestricted() && mounted) {
      final ok = await confirmDialog(
        context,
        title: 'Que Android no detenga la grabación',
        body: 'Con la optimización de batería, Android puede cortar la grabación con la pantalla apagada. Permite que Cresta siga en segundo plano: solo gasta batería mientras grabas.',
        action: 'Permitir',
        cancel: 'Ahora no',
      );
      if (ok) await _location.requestBatteryUnrestricted();
    }
    if (!mounted) return;
    final now = DateTime.now();
    final n =
        _services.tracks.all
            .where((t) => t.expeditionId == _trackExpeditionId)
            .length +
        1;
    _following = true;
    _centeredOnFirstFix = false;
    await _recorder.start(
      expeditionId: _trackExpeditionId,
      name: 'Recorrido $n · ${fmtDate(now)}',
      route: _route,
      pois: _savedRoute?.pois ?? const [],
      turnaround: _expedition.turnaroundOn(now),
      mode: mode,
    );
    await _bridge.setTrack(const []);
    _setLayer('track', true);
  }

  /// Guía de regreso por lo recorrido: la traza al revés pasa a ser la ruta a seguir
  /// (avance, lo que falta y aviso al salirse); la línea ya se ve en el mapa.
  void _toggleBacktrack() {
    if (_recorder.backtracking) {
      _recorder.stopBacktrack();
      return;
    }
    if (_recorder.startBacktrack()) {
      _following = true;
      _bridge.setFollow(true);
    }
  }

  Future<void> _stopRecording() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminar recorrido'),
        content: Text(
          _recorder.points.isEmpty
              // Sin puntos no hay nada que guardar: mejor decirlo que dejar un recorrido vacío
              ? 'No se grabó ningún punto: el GPS no entregó tu posición. Puedes descartarlo o seguir grabando.'
              : '${fmtKm(_recorder.stats.meters, decimals: 2)} km · +${fmtInt(_recorder.stats.gain)} m · ${fmtClock(_recorder.activeTime)} en total, ${fmtDuration(_recorder.stats.moving)} en movimiento',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Descartar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Seguir grabando'),
          ),
          if (_recorder.points.isNotEmpty)
            FilledButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('Guardar'),
            ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'discard') {
      final ok = await confirmDialog(
        context,
        title: '¿Descartar el recorrido?',
        body: 'Se borra todo lo grabado. No se puede deshacer.',
        action: 'Descartar',
      );
      if (!ok) return;
      await _recorder.discard();
      await _bridge.setTrack(const []);
      return;
    }
    final t = await _recorder.stop();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => TrackScreen(trackId: t.id)),
    );
  }

  /// Aviso de ubicación con un botón al ajuste que la destraba (sin él, el
  /// usuario tenía que buscarlo por su cuenta).
  SnackBar _permissionSnack(LocationStatus status) => SnackBar(
    content: Text(_permissionMessage(status)),
    action: status == LocationStatus.denied
        ? null
        : SnackBarAction(
            label: 'Abrir ajustes',
            onPressed: () => _location.openSettings(status),
          ),
  );

  String _permissionMessage(LocationStatus status) => switch (status) {
    LocationStatus.serviceOff =>
      'Activa la ubicación del teléfono para verte en el mapa.',
    LocationStatus.denied =>
      'Sin permiso de ubicación. Puedes darlo cuando quieras.',
    LocationStatus.deniedForever =>
      'El permiso de ubicación está bloqueado. Actívalo en Ajustes.',
    LocationStatus.granted => '',
  };

  @override
  void dispose() {
    _services.maps.removeListener(_pushRegions);
    _recorder.removeListener(_onRecorder);
    for (final s in _subs) {
      s.cancel();
    }
    _group?.dispose();
    _planner?.dispose();
    _bridge.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ Mapa

  void _pushRegions() =>
      _bridge.setRegions(_services.expeditions.statusOf(_expedition).regions);

  void _onMapEvent(MapEvent e) {
    switch (e.type) {
      case 'flyProgress':
        setState(() => _cursor = (e.data['meters'] as num).toDouble());
      case 'flyEnd':
        setState(() => _flying = false);
      case 'photoTap':
        final photo = _services.photos.byId(e.data['id'] as String);
        if (photo != null) {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  PhotoScreen(trackId: photo.trackId, photoId: photo.id),
            ),
          ).then((_) {
            // Pudo borrarse
            if (mounted) {
              _bridge.setPhotos(_services.photos.forTrack(photo.trackId));
            }
          });
        }
      case 'bearing':
        setState(() => _bearing = (e.data['deg'] as num).toDouble());
      case 'videoProgress':
        if (_video != null) {
          setState(() => _video!.progress = (e.data['p'] as num).toDouble());
        }
      case 'videoChunk':
        _video?.chunks[(e.data['i'] as num).toInt()] = e.data['data'] as String;
      case 'videoEnd':
        _saveVideo(e.data['mime'] as String);
      case 'videoError':
        setState(() => _video = null);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.data['message'] as String)));
      case 'followOff':
        setState(() => _following = false);
      case 'markerTap':
        _showMarkerInfo(e.data['kind'] as String, e.data['id'] as String);
      case 'mapTap':
        _onMapTap(
          LngLat(
            (e.data['lng'] as num).toDouble(),
            (e.data['lat'] as num).toDouble(),
          ),
        );
    }
  }

  void _pushMembers(List<GroupMember> members) {
    final route = _route;
    if (route == null) return;
    _bridge.setMembers([
      for (final m in members)
        {
          'id': m.id,
          'initials': m.initials,
          'color':
              '#${(m.color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
          'lng': route.along(m.meters).position.lng,
          'lat': route.along(m.meters).position.lat,
        },
    ]);
  }

  void _setMode(AppMode mode) {
    setState(() {
      _mode = mode;
      _layers = layerPreset(mode);
      _flying = false;
    });
    _bridge.stopFly();
    _bridge.setLayers(_layers);
    if (mode == AppMode.civil) {
      _bridge.flyTo(-98.64, 19.04, zoom: 10.3, pitch: 52, bearing: 20);
    } else {
      _bridge.fitRoute();
    }
  }

  void _setLayer(String id, bool on) {
    setState(() => _layers[id] = on);
    _bridge.setLayer(id, on);
  }

  void _set3d(bool on) {
    setState(() => _is3d = on);
    if (!on && _flying) _toggleFly();
    _bridge.set3d(on);
  }

  void _toggleFly() {
    if (_flying) {
      _bridge.stopFly();
      setState(() => _flying = false);
    } else {
      setState(() {
        _flying = true;
        _is3d = true;
      });
      _bridge.flyRoute();
    }
  }

  /// Busca en los mapas descargados; mide distancias desde tu posición o, si no se
  /// conoce, desde el centro del mapa. El lugar elegido queda marcado.
  Future<void> _searchPlaces() async {
    final fix = _services.recorder.lastFix;
    final me = _myPos ?? (fix == null ? null : (fix.lng, fix.lat));
    final from = me ?? await _bridge.center();
    if (!mounted) return;
    final p = await showPlaceSearch(
      context,
      lng: from?.$1,
      lat: from?.$2,
      fromMe: me != null,
    );
    if (p == null || !mounted) return;
    setState(() => _found = p);
    await _bridge.setFound(p);
    await _bridge.flyTo(p.lng, p.lat, zoom: 14, pitch: null);
  }

  /// Trazar ruta: agrega el siguiente punto (salida, parada o destino) escribiendo su
  /// nombre. Busca en los mapas descargados y, con conexión, en todo el mundo.
  Future<void> _addPointByName() async {
    final planner = _planner;
    if (planner == null) return;
    final fix = _services.recorder.lastFix;
    final me = _myPos ?? (fix == null ? null : (fix.lng, fix.lat));
    final from = me ?? await _bridge.center();
    if (!mounted) return;
    final p = await showPlaceSearch(
      context,
      lng: from?.$1,
      lat: from?.$2,
      fromMe: me != null,
      title: planner.waypoints.isEmpty
          ? '¿Desde dónde sales?'
          : 'Agregar parada o destino',
      offerMe: true,
      online: true,
    );
    if (p == null || !mounted || _planner != planner) return;
    await planner.addPoint(LngLat(p.lng, p.lat));
    if (!mounted) return;
    await _framePlan(planner);
  }

  /// Encuadra lo trazado; con un solo punto, ve a él.
  Future<void> _framePlan(RoutePlanner planner) async {
    if (planner.waypoints.isEmpty) return;
    if (planner.waypoints.length > 1) {
      final pts = planner.line.isEmpty ? planner.waypoints : planner.line;
      await _bridge.fitBounds(
        BBox(
          pts.map((e) => e.lng).reduce(math.min) - 0.002,
          pts.map((e) => e.lat).reduce(math.min) - 0.002,
          pts.map((e) => e.lng).reduce(math.max) + 0.002,
          pts.map((e) => e.lat).reduce(math.max) + 0.002,
        ),
      );
    } else {
      final p = planner.waypoints.first;
      await _bridge.flyTo(p.lng, p.lat, zoom: 14, pitch: null);
    }
  }

  /// Trazar ruta hasta el lugar encontrado. Trazando, lo agrega como siguiente punto;
  /// si no, empieza a trazar (o sigue la ruta que ya hay) desde tu posición. Sin tu
  /// posición, o si estás lejos, pregunta desde dónde sales.
  Future<void> _routeToFound() async {
    final dest = _found;
    if (dest == null) return;
    if (_planner == null) _startPlanning();
    final planner = _planner;
    if (planner == null) return;
    if (planner.waypoints.isEmpty) {
      final fix = _services.recorder.lastFix;
      final me = _myPos ?? (fix == null ? null : (fix.lng, fix.lat));
      final near =
          me != null &&
          haversine(me.$2, me.$1, dest.lat, dest.lng) <= routeFromMeMaxMeters;
      if (near) {
        await planner.addPoint(LngLat(me.$1, me.$2));
      } else {
        // Lejos de ti: las salidas que se sugieren son las cercanas al destino
        final start = await showPlaceSearch(
          context,
          lng: dest.lng,
          lat: dest.lat,
          near: dest.name,
          me: me,
          title: '¿Desde dónde sales?',
          offerMe: true,
          online: true,
        );
        if (start == null || !mounted || _planner != planner) return;
        await planner.addPoint(LngLat(start.lng, start.lat));
      }
    }
    if (!mounted || _planner != planner) return;
    await planner.addPoint(LngLat(dest.lng, dest.lat));
    if (!mounted) return;
    _clearFound();
    await _framePlan(planner);
  }

  /// Graba el sobrevuelo del recorrido a video. El mapa queda a pantalla completa y sin
  /// tocar (un toque detendría el vuelo).
  void _startVideo(List<TrackPoint> points) {
    setState(() {
      _video = _VideoJob();
      _is3d = true;
    });
    final t = _services.tracks.byId(widget.showTrackId!);
    final s = t?.summary;
    _bridge.flyTrack(
      points,
      record: true,
      title: t?.name,
      detail: s == null
          ? null
          : '${fmtKm(s.meters, decimals: 2)} km · +${fmtInt(s.gain)} m · ${fmtDuration(s.moving)} en movimiento',
    );
  }

  Future<void> _saveVideo(String type) async {
    final job = _video;
    if (job == null) return;
    setState(() => job.saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = BytesBuilder(copy: false);
      for (final c in [
        for (final k in job.chunks.keys.toList()..sort()) job.chunks[k]!,
      ]) {
        bytes.add(base64Decode(c));
      }
      final ext = type.contains('mp4') ? 'mp4' : 'webm';
      final dir = await getTemporaryDirectory();
      final t = _services.tracks.byId(widget.showTrackId!);
      final safe = (t?.name ?? 'recorrido')
          .replaceAll(RegExp(r'[^\w\- áéíóúñÁÉÍÓÚÑ]'), '')
          .trim();
      final file = File(
        '${dir.path}/${safe.isEmpty ? 'recorrido' : safe}.$ext',
      );
      await file.writeAsBytes(bytes.takeBytes(), flush: true);
      if (!mounted) return;
      setState(() => _video = null);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'video/$ext')],
          subject: t?.name,
        ),
      );
    } on Object catch (e) {
      if (mounted) setState(() => _video = null);
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo guardar el video: $e')),
      );
    }
  }

  /// Foto durante la grabación: abre la cámara del teléfono y la guarda en el recorrido con
  /// la posición del GPS (la grabación sigue mientras la cámara está abierta).
  Future<void> _takePhoto() async {
    final messenger = ScaffoldMessenger.of(context);
    final XFile? shot;
    try {
      shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 85,
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la cámara.')),
      );
      return;
    }
    if (shot != null) await _savePhoto(shot);
  }

  Future<void> _savePhoto(XFile shot) async {
    final messenger = ScaffoldMessenger.of(context);
    final track = _recorder.track;
    if (track == null) return;
    final fix = _recorder.lastFix;
    final fresh =
        fix != null &&
        DateTime.now().difference(fix.time) < const Duration(minutes: 2);
    await _services.photos.add(
      trackId: track.id,
      source: File(shot.path),
      time: DateTime.now(),
      lat: fresh ? fix.lat : null,
      lng: fresh ? fix.lng : null,
      altitude: fresh ? (_recorder.stats.altitude ?? fix.altitude) : null,
    );
    await _bridge.setPhotos(_services.photos.forTrack(track.id));
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          fresh ? 'Foto guardada en el recorrido, en el mapa.' : 'Foto guardada en el recorrido, sin ubicación (el GPS aún no tenía tu posición).',
        ),
      ),
    );
  }

  /// En Android, si el sistema cerró la app mientras la cámara estaba abierta, la foto
  /// queda pendiente: se recupera al volver.
  Future<void> _recoverPhoto() async {
    if (!Platform.isAndroid) return;
    try {
      final lost = await ImagePicker().retrieveLostData();
      final f = lost.file;
      if (f != null && mounted) await _savePhoto(f);
    } on Object {
      // Nada pendiente
    }
  }

  // ------------------------------------------------------------ Abajo y hojas

  /// Lo de abajo según el modo: la tira al trazar o grabar; si no, la barra flotante y,
  /// si hay algo que mostrar, una tarjeta de vistazo encima.
  Widget _bottomChrome(bool civil) {
    if (_planner != null) {
      return PlannerStrip(
        planner: _planner!,
        placingPoi: _placingPoi,
        onCancelPoi: () => setState(() => _placingPoi = null),
        onSave: _savePlan,
        onMore: _openPlanner,
      );
    }
    if (_recordingHere) {
      return RecordingStrip(
        recorder: _recorder,
        onPause: _recorder.pause,
        onResume: _recorder.resume,
        onStop: _stopRecording,
        onPhoto: _takePhoto,
        onMore: _openRecording,
      );
    }
    if (_flying) {
      return Center(
        child: Glass(
          child: TextButton.icon(
            onPressed: _toggleFly,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Detener el recorrido en 3D'),
          ),
        ),
      );
    }
    final route = _route;
    final Widget? peek = civil && _civil != null
        ? PeekCard(
            icon: Icons.shield_outlined,
            iconColor: Andes.terracottaContainer,
            title: 'Protección civil (ejemplo)',
            detail: '${_civil!.alertLabel} · albergues y reportes',
            onTap: _openCivil,
          )
        : _comparing
        ? PeekCard(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _compared.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: CircleAvatar(
                      backgroundColor: compareColor(i),
                      radius: 6,
                    ),
                  ),
              ],
            ),
            title: 'Comparando ${_compared.length} rutas',
            detail: _compared.map((r) => r.name).join(' · '),
            onTap: _openCompare,
          )
        : route != null
        ? PeekCard(
            icon: Icons.route_rounded,
            title: route.name,
            detail:
                '${fmtKm(route.totalMeters)} km · +${fmtInt(route.gain)} m · ≈ ${fmtDuration(route.estimatedTime)}',
            onTap: _openRoute,
          )
        : null;
    final simple = civil || _comparing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (peek != null) ...[peek, const SizedBox(height: 8)],
        MapDock(
          onLayers: _openLayers,
          onRecord: simple ? null : _startRecording,
          onRoute: simple ? null : _startPlanning,
          routeLabel: route == null ? 'Ruta' : 'Editar ruta',
        ),
      ],
    );
  }

  /// Envuelve el contenido de una hoja con el tema del modo (protección civil tiene el suyo).
  Widget _themed(Widget child) => Theme(
    data: crestaTheme(civil: _mode == AppMode.civil),
    child: child,
  );

  /// Capas: mapa base, 2D/3D, relieve, capas, zonas de la expedición y créditos del mapa.
  void _openLayers() => showMapSheet(
    context,
    builder: (context, setSheet) {
      final status = _services.expeditions.statusOf(_expedition);
      final scheme = Theme.of(context).colorScheme;
      return _themed(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_free)
              _OfflineSummary(
                status: status,
                onAddZone: () {
                  Navigator.pop(context);
                  _addZone();
                },
                onFit: () {
                  Navigator.pop(context);
                  final b = status.bounds;
                  if (b != null) _bridge.fitBounds(b);
                },
              ),
            ViewControls(
              base: _base,
              is3d: _is3d,
              exaggeration: _exaggeration,
              onBase: (b) {
                setState(() => _base = b);
                setSheet(() {});
                _bridge.setBase(b);
              },
              on3d: (v) {
                _set3d(v);
                setSheet(() {});
              },
              onExaggeration: (x) {
                setState(() => _exaggeration = x);
                setSheet(() {});
                _bridge.setExaggeration(x);
              },
            ),
            LayerList(
              layers: _availableLayers,
              states: _layers,
              onChanged: (id, on) {
                _setLayer(id, on);
                setSheet(() {});
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Mapa: OpenFreeMap, © OpenMapTiles, © colaboradores de OpenStreetMap. Satélite: Sentinel-2 cloudless 2024 de EOX '
              '(datos Copernicus). Relieve: Mapzen Terrain Tiles.'
              '${_civil != null ? ' Los datos de protección civil y el grupo son ilustrativos, no información oficial.' : ''}',
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    },
  );

  /// La ruta: cifras, perfil (deslizar ubica en el mapa), recorrerla en 3D y el grupo.
  void _openRoute() {
    final route = _route;
    if (route == null) return;
    showMapSheet(
      context,
      builder: (context, setSheet) => _themed(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RouteCard(
              route: route,
              cursorMeters: _cursor,
              flying: _flying,
              onScrub: (m) {
                setState(() => _cursor = m);
                setSheet(() {});
                _bridge.showCursorAtMeters(m);
              },
              onScrubEnd: () {},
              onFly: () {
                Navigator.pop(context);
                _toggleFly();
              },
              onFit: () {
                Navigator.pop(context);
                _bridge.stopFly();
                _bridge.fitRoute();
              },
            ),
            if (_group != null)
              GroupList(
                route: route,
                members: _group!.members,
                onTap: (m) {
                  Navigator.pop(context);
                  final p = route.along(m.meters).position;
                  _bridge.flyTo(p.lng, p.lat, zoom: 14.6, pitch: 62);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openCivil() {
    final civil = _civil;
    if (civil == null) return;
    showMapSheet(
      context,
      builder: (context, setSheet) => _themed(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VolcanoAlertCard(civil: civil),
            ShelterList(
              civil: civil,
              onTap: (s) {
                Navigator.pop(context);
                _bridge.flyTo(s.at.lng, s.at.lat, zoom: 13.2, pitch: 50);
              },
            ),
            ReportList(
              civil: civil,
              onTap: (r) {
                Navigator.pop(context);
                _bridge.flyTo(r.at.lng, r.at.lat, zoom: 13.5);
              },
              onSimulateAlert: () {
                Navigator.pop(context);
                _simulateAlert();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openCompare() => showMapSheet(
    context,
    builder: (context, setSheet) => _themed(_CompareLegend(routes: _compared)),
  );

  /// Todo lo de la grabación: cifras, avisos, llegada, regreso por la traza.
  void _openRecording() => showMapSheet(
    context,
    builder: (context, setSheet) => _themed(
      ListenableBuilder(
        listenable: _recorder,
        builder: (context, _) => !_recorder.isActive
            ? const SizedBox.shrink()
            : RecordingPanel(
                recorder: _recorder,
                onPause: _recorder.pause,
                onResume: _recorder.resume,
                onStop: () {
                  Navigator.pop(context);
                  _stopRecording();
                },
                onBacktrack: _toggleBacktrack,
              ),
      ),
    ),
  );

  /// El planificador completo: perfil, ajustar a senderos, puntos de interés, invertir…
  void _openPlanner() {
    final planner = _planner;
    if (planner == null) return;
    showMapSheet(
      context,
      builder: (context, setSheet) => _themed(
        ListenableBuilder(
          listenable: planner,
          builder: (context, _) => PlannerPanel(
            planner: planner,
            placingPoi: _placingPoi,
            onPlacePoi: (k) {
              Navigator.pop(context);
              setState(() => _placingPoi = k);
            },
            onSave: () {
              Navigator.pop(context);
              _savePlan();
            },
            onCancel: () {
              Navigator.pop(context);
              _cancelPlan();
            },
          ),
        ),
      ),
    );
  }

  void _clearFound() {
    setState(() => _found = null);
    _bridge.setFound(null);
  }

  Future<void> _locateMe() async {
    if (_recordingHere) {
      // Mientras se graba, el botón vuelve a centrar y seguir tu posición
      setState(() => _following = true);
      await _bridge.setFollow(true, zoom: 15);
      return;
    }
    final status = await _location.ensurePermission();
    if (!mounted) return;
    if (status != LocationStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(_permissionSnack(status));
      return;
    }
    await _follow();
  }

  /// Centra en tu posición y la sigue mientras te mueves, hasta que muevas el mapa con
  /// el dedo (antes había que tocar "Mi ubicación" cada vez para ver dónde estabas).
  Future<void> _follow() async {
    _watchMe();
    setState(() => _following = true);
    final known = _myPos;
    if (known != null) {
      await _bridge.setFollow(true, zoom: 15);
      return;
    }
    // Sin lectura aún: centra en la última conocida y otra vez al llegar la nueva
    _centerOnFix = true;
    final last = await _location.lastKnown();
    if (!mounted) return;
    if (last != null && _myPos == null) {
      _bridge.setMyLocation(last.longitude, last.latitude);
      _centerOn((last.longitude, last.latitude));
    }
  }

  /// Muestra tu posición en el mapa en vivo (sin pedir permiso: solo si ya lo diste).
  void _watchMe() {
    if (_locating) return;
    setState(() => _locating = true);
    _subs.add(
      _location.watch().listen((p) {
        _myPos = (p.lng, p.lat);
        // Grabando, la posición la pone el grabador
        if (_recordingHere) return;
        _bridge.setMyLocation(p.lng, p.lat);
        if (_centerOnFix) {
          _centerOnFix = false;
          _bridge.setFollow(_following, zoom: 15);
          if (!_following) _centerOn(_myPos!);
        }
      }, onError: (_) {}),
    );
  }

  /// Al abrir el mapa: si ya hay permiso, muestra tu posición; en el mapa libre sin nada
  /// que encuadrar (ruta, recorrido), además te centra y te sigue.
  Future<void> _autoLocate({required bool center}) async {
    if (_recordingHere || !await _location.isGranted()) return;
    if (!mounted) return;
    if (center) {
      await _follow();
    } else {
      _watchMe();
    }
  }

  /// Centra en tu posición sin cambiar la inclinación ni el giro que tenga el mapa.
  void _centerOn((double, double) p) =>
      _bridge.flyTo(p.$1, p.$2, zoom: 15, pitch: null);

  /// El centro del mapa es el de la parte que no tapan la barra de arriba ni lo de abajo
  /// (barra, tarjeta o tira, que cambian de alto según el modo).
  Future<void> _pushPadding() => _bridge.setPadding(
    top: 110,
    bottom: _bottomInset + 20,
    left: 30,
    right: 30,
  );

  /// Mide lo de abajo después de dibujar y, si cambió, recentra el mapa.
  void _syncPadding() {
    if (!mounted) return;
    final box = _bottomKey.currentContext?.findRenderObject() as RenderBox?;
    final h = widget.video || box == null || !box.hasSize
        ? 0.0
        : box.size.height + 12 + MediaQuery.paddingOf(context).bottom;
    if ((h - _bottomInset).abs() < 4) return;
    _bottomInset = h;
    _pushPadding();
  }

  void _simulateAlert() {
    final civil = _civil;
    if (civil == null) return;
    _setLayer('reports', true);
    _setLayer('ash', true);
    _bridge.pulseReport(civil.reports.first.id);
    _bridge.flyTo(-98.53, 19.05, zoom: 11.4, pitch: 58, bearing: 300);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Alerta de prueba: caída de ceniza en San Nicolás de los Ranchos. 3 albergues notificados.',
        ),
      ),
    );
  }

  void _showMarkerInfo(String kind, String id) {
    final (String title, String body) = switch (kind) {
      'shelter' => () {
        final s = _civil!.shelters.firstWhere((s) => s.id == id);
        return (
          'Albergue ${s.name}',
          '${s.place}\n${fmtInt(s.free)} lugares libres de ${fmtInt(s.capacity)}',
        );
      }(),
      'report' => () {
        final r = _civil!.reports.firstWhere((r) => r.id == id);
        return (r.type, '${r.by} · ${fmtAgo(r.minutesAgo)}');
      }(),
      'member' => () {
        final m = _group!.members.firstWhere((m) => m.id == id);
        return (
          m.name,
          '${fmtInt(_route!.along(m.meters).elevation)} m · km ${fmtKm(m.meters)}',
        );
      }(),
      _ => (id, ''),
    };
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: signage(context, size: 22)),
              const SizedBox(height: 6),
              Text(body),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ UI

  List<MapLayer> get _availableLayers => [
    for (final l in mapLayers)
      if ((!l.needsRoute || _route != null) &&
          (l.group != LayerGroup.civil || _civil != null))
        l,
  ];

  @override
  Widget build(BuildContext context) {
    final civil = _mode == AppMode.civil;
    return Theme(
      data: crestaTheme(civil: civil),
      child: Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _syncPadding());
          return PopScope(
            canPop: _planner == null,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              final navigator = Navigator.of(context);
              if (await _cancelPlan() && mounted) navigator.pop();
            },
            child: Scaffold(
              // A todo el alto: sin el panel fijo, nada estira la pila
              body: SizedBox.expand(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: WebViewWidget(controller: _bridge.controller),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                        child: Row(
                          children: [
                            _MapButton(
                              icon: Icons.arrow_back_rounded,
                              tooltip: 'Regresar',
                              onPressed: () => Navigator.maybePop(context),
                            ),
                            const SizedBox(width: 8),
                            if (_civil != null)
                              Expanded(
                                child: Glass(
                                  child: SegmentedButton<AppMode>(
                                    segments: const [
                                      ButtonSegment(
                                        value: AppMode.mountain,
                                        label: Text('Montaña'),
                                        icon: Icon(Icons.terrain_rounded),
                                      ),
                                      ButtonSegment(
                                        value: AppMode.civil,
                                        label: Text('Prot. civil'),
                                        icon: Icon(Icons.shield_outlined),
                                      ),
                                    ],
                                    selected: {_mode},
                                    showSelectedIcon: false,
                                    onSelectionChanged: (s) =>
                                        _setMode(s.first),
                                  ),
                                ),
                              )
                            else if (_planner != null)
                              // Trazando: arriba se escribe la salida, las paradas y el destino
                              Expanded(
                                child: _SearchPill(
                                  text: _planner!.waypoints.isEmpty
                                      ? '¿Desde dónde sales?'
                                      : 'Agregar parada o destino',
                                  onTap: _planner!.busy
                                      ? null
                                      : _addPointByName,
                                ),
                              )
                            else if (_recordingHere)
                              Expanded(
                                child: RecordingBar(
                                  recorder: _recorder,
                                  onTap: _openRecording,
                                ),
                              )
                            else
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  heightFactor: 1,
                                  child: Glass(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _planner != null
                                                ? 'PLANEANDO RUTA'
                                                : _recordingHere
                                                ? 'GRABANDO'
                                                : _comparing
                                                ? 'COMPARAR'
                                                : _free
                                                ? 'EXPLORAR'
                                                : 'EXPEDICIÓN',
                                            style: labelStyle(
                                              context,
                                              color: _recordingHere
                                                  ? recordColor
                                                  : Andes.gold,
                                            ).copyWith(fontSize: 9.5),
                                          ),
                                          Text(
                                            _comparing
                                                ? 'Rutas'
                                                : _free
                                                ? (_savedRoute?.name ??
                                                      'Mapa libre')
                                                : _expedition.name,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (_planner == null) ...[
                              const SizedBox(width: 8),
                              _MapButton(
                                icon: Icons.search_rounded,
                                tooltip: 'Buscar en tus mapas',
                                onPressed: _searchPlaces,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: MediaQuery.paddingOf(context).top + 70,
                      child: Column(
                        children: [
                          // Brújula: solo con el mapa girado; la aguja apunta al norte y al
                          // tocarla el mapa vuelve a quedar con el norte arriba
                          if (_bearing.abs() > 2) ...[
                            _MapButton(
                              icon: Icons.navigation_rounded,
                              iconAngle: -_bearing * math.pi / 180,
                              color: Andes.terracottaContainer,
                              tooltip: 'Norte arriba',
                              onPressed: _bridge.resetNorth,
                            ),
                            const SizedBox(height: 8),
                          ],
                          _MapButton(
                            icon: Icons.sos_rounded,
                            color: Andes.terracottaContainer,
                            tooltip: 'SOS: tu ubicación y llamar a emergencias',
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => SosScreen(
                                  expeditionName: _free
                                      ? null
                                      : _expedition.name,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _MapButton(
                            icon: _following
                                ? Icons.my_location_rounded
                                : Icons.location_searching_rounded,
                            tooltip: _following
                                ? 'Siguiendo tu posición'
                                : 'Seguir mi posición',
                            onPressed: _locateMe,
                          ),
                          const SizedBox(height: 8),
                          _MapButton(
                            label: _is3d ? '2D' : '3D',
                            tooltip: _is3d ? 'Cambiar a 2D' : 'Cambiar a 3D',
                            onPressed: () => _set3d(!_is3d),
                          ),
                        ],
                      ),
                    ),
                    if (_found != null)
                      Positioned(
                        left: 8,
                        right: 76,
                        top: MediaQuery.paddingOf(context).top + 70,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          heightFactor: 1,
                          child: _FoundCard(
                            place: _found!,
                            from: _myPos,
                            // Con una ruta abierta o trazando, el lugar se suma al final
                            routeLabel:
                                _planner != null ||
                                    _route != null ||
                                    _savedRoute != null
                                ? 'Agregar a la ruta'
                                : 'Ruta hasta aquí',
                            onRoute:
                                _recordingHere ||
                                    _comparing ||
                                    widget.video ||
                                    civil
                                ? null
                                : _routeToFound,
                            onTap: () => _bridge.flyTo(
                              _found!.lng,
                              _found!.lat,
                              zoom: 14,
                              pitch: null,
                            ),
                            onClose: _clearFound,
                          ),
                        ),
                      ),
                    // Abajo solo lo que hace falta: la barra flotante al explorar, una
                    // tarjeta de vistazo si hay ruta, o la tira de control al grabar o trazar
                    if (!widget.video)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12 + MediaQuery.paddingOf(context).bottom,
                        child: KeyedSubtree(
                          key: _bottomKey,
                          child: _bottomChrome(civil),
                        ),
                      ),
                    if (_video != null) _VideoOverlay(job: _video!),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _addZone() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => AreaPickerScreen(expeditionId: _expedition.id),
    ),
  );
}

/// Leyenda del mapa en modo comparar: cada ruta con su color y sus cifras.
class _CompareLegend extends StatelessWidget {
  const _CompareLegend({required this.routes});
  final List<PlannedRoute> routes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Rutas comparadas'),
        for (var i = 0; i < routes.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: compareColor(i), radius: 6),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    routes[i].name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${fmtKm(routes[i].profile.totalMeters)} km · +${fmtInt(routes[i].profile.gain)} m',
                  style: dataStyle(context, size: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Panel del mapa libre: qué se puede hacer sin expedición y cómo crear una.
/// Resumen de mapas cuando la expedición todavía no tiene ruta.
class _OfflineSummary extends StatelessWidget {
  const _OfflineSummary({
    required this.status,
    required this.onAddZone,
    required this.onFit,
  });
  final ExpeditionStatus status;
  final VoidCallback onAddZone;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Mapas sin conexión'),
        ReadinessChip(status),
        const SizedBox(height: 8),
        Text(
          status.regions.isEmpty
              ? 'Esta expedición aún no tiene zonas descargadas. Con conexión verás el mapa igual, pero en la montaña necesitarás descargarlo.'
              : 'Las líneas punteadas marcan lo descargado. Fuera de ellas el mapa solo carga con conexión.',
          style: TextStyle(color: muted, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (status.regions.isNotEmpty)
              OutlinedButton(
                onPressed: onFit,
                child: const Text('Ver zona descargada'),
              ),
            FilledButton.tonalIcon(
              onPressed: onAddZone,
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: const Text('Agregar zona'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Buscador de arriba al trazar una ruta: escribir la salida, las paradas y el destino.
class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.text, required this.onTap});
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Glass(
    opacity: .94,
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: Andes.cyan, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Video del recorrido: los pedazos que manda el mapa (base64) hasta 'videoEnd'.
class _VideoJob {
  final chunks = <int, String>{};
  bool saving = false;

  /// Avance de la generación (0–1); null mientras se prepara el inicio.
  double? progress;
}

/// Mientras se prepara el video, tapa el mapa (si no, se ve el punto por defecto y el salto
/// al recorrido); mientras se genera, muestra el avance. El mapa no se toca: un toque movería
/// la cámara de un cuadro.
class _VideoOverlay extends StatelessWidget {
  const _VideoOverlay({required this.job});
  final _VideoJob job;

  @override
  Widget build(BuildContext context) {
    final p = job.progress;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final text = job.saving
        ? 'Guardando el video…'
        : p == null
        ? 'Preparando el video…'
        : 'Generando el video… ${(p * 100).round()} %';
    final card = Glass(
      opacity: .92,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: job.saving ? null : p),
            const SizedBox(height: 8),
            Text(
              p == null ? 'Cargando el mapa y el relieve del inicio.' : 'Cada cuadro espera a que cargue el mapa: así sale fluido. No toques el mapa.',
              style: TextStyle(color: muted, fontSize: 12.5, height: 1.35),
            ),
          ],
        ),
      ),
    );
    return Positioned.fill(
      child: AbsorbPointer(
        child: p == null && !job.saving
            ? ColoredBox(
                color: Andes.surface,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: card,
                  ),
                ),
              )
            : Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.paddingOf(context).top + 76,
                    left: 16,
                    right: 80,
                  ),
                  child: card,
                ),
              ),
      ),
    );
  }
}

/// Lugar elegido en la búsqueda: nombre, tipo y, si se sabe dónde estás, distancia.
class _FoundCard extends StatelessWidget {
  const _FoundCard({
    required this.place,
    required this.from,
    required this.onTap,
    required this.onClose,
    required this.routeLabel,
    this.onRoute,
  });
  final MapPlace place;
  final (double, double)? from;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final String routeLabel;

  /// Null: no se ofrece (grabando, comparando).
  final VoidCallback? onRoute;

  @override
  Widget build(BuildContext context) {
    final p = place, f = from;
    final detail = [
      placeDetail(p),
      if (f != null)
        placeDistance(p, haversine(f.$2, f.$1, p.lat, p.lng), f.$2, f.$1),
    ].join(' · ');
    return Glass(
      opacity: .9,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 0, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(placeIcon(p.kind), color: Andes.gold, size: 22),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      detail,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onRoute != null)
                IconButton(
                  tooltip: routeLabel,
                  icon: const Icon(Icons.directions_rounded, color: Andes.cyan),
                  onPressed: onRoute,
                ),
              IconButton(
                tooltip: 'Quitar del mapa',
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    this.icon,
    this.iconAngle = 0,
    this.label,
    this.color,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData? icon;

  /// Giro del ícono en radianes (la aguja de la brújula).
  final double iconAngle;
  final String? label;
  final Color? color;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Glass(
        radius: 14,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: icon != null
                    ? Transform.rotate(
                        angle: iconAngle,
                        child: Icon(
                          icon,
                          size: 22,
                          color: color ?? Andes.onSurface,
                        ),
                      )
                    : Text(
                        label!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: .5,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
