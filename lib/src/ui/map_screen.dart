import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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
import '../routes/planned_route.dart';
import '../routes/route_planner.dart';
import '../tracking/track.dart';
import '../tracking/track_recorder.dart';
import 'area_picker_screen.dart';
import 'format.dart';
import 'offline_widgets.dart';
import 'panels.dart';
import 'planner_panel.dart';
import 'recording_panel.dart';
import 'route_actions.dart';
import 'theme.dart';
import 'track_screen.dart';

/// El mapa de una expedición, en 2D o 3D, con lo descargado y (si hay red) lo demás.
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.expeditionId,
    this.showTrackId,
    this.plan = false,
  });
  final String expeditionId;

  /// Abrir directo en modo planificar ruta.
  final bool plan;

  /// Recorrido ya grabado que se muestra al abrir (desde su detalle).
  final String? showTrackId;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _sheetMin = 0.14, _sheetInitial = 0.38, _sheetMax = 0.9;

  final _bridge = MapBridge();
  final _sheet = DraggableScrollableController();
  late final LocationService _location = _services.location;
  late final TrackRecorder _recorder = _services.recorder;
  DateTime _lastTrackPush = DateTime.fromMillisecondsSinceEpoch(0);
  bool _following = false;
  bool _centeredOnFirstFix = false;
  final _subs = <StreamSubscription<dynamic>>[];
  late AppServices _services;
  late Expedition _expedition;

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
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _services = AppScope.of(context);
    _expedition = _services.expeditions.byId(widget.expeditionId)!;
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
    final saved = _services.routes.forExpedition(_expedition.id);
    if (saved != null) {
      _route = saved.profile;
      _routeJson = saved.profile.toJson();
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
    final size = MediaQuery.sizeOf(context);
    await _bridge.setPadding(
      top: 110,
      bottom: size.height * _sheetInitial + 20,
      left: 30,
      right: 30,
    );
    await _bridge.setBase(_base);
    await _bridge.setLayers(_layers);
    _pushRegions();
    if (_routeJson != null) await _bridge.setRoute(_routeJson);
    if (saved != null) await _bridge.setPois(saved.pois);
    if (civilJson != null) await _bridge.setCivil(civilJson);
    await _bridge.set3d(true);
    final bounds = _services.expeditions.statusOf(_expedition).bounds;
    if (_route != null) {
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
      _recorder.turnaround ??= _expedition.turnaroundOn(
        _recorder.track!.startedAt,
      );
      await _bridge.setTrack(_recorder.points);
      final fix = _recorder.lastFix;
      if (fix != null) await _bridge.setMyLocation(fix.lng, fix.lat);
      _following = _centeredOnFirstFix = true;
      await _bridge.setFollow(true, zoom: 15);
    } else if (widget.showTrackId != null) {
      final points = await _services.tracks.readPoints(widget.showTrackId!);
      await _bridge.setTrack(points);
      if (points.length > 1) await _bridge.fitBounds(_boundsOf(points));
    }
    if (widget.plan && mounted) _startPlanning();
  }

  // ------------------------------------------------------------ Planificar ruta

  void _startPlanning() {
    if (_recordingHere) return;
    _bridge.stopFly();
    final saved = _services.routes.forExpedition(_expedition.id);
    final route = _route;
    final planner = RoutePlanner(
      snap: _bridge.snapLeg,
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
    _moveSheet(_sheetInitial);
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
    final saved = _services.routes.forExpedition(_expedition.id);
    final name = await askRouteName(
      context,
      saved?.name ?? 'Ruta de ${_expedition.name}',
    );
    if (name == null || !mounted) return;
    final route = p.toRoute(name);
    await _services.routes.save(_expedition.id, route);
    _route = route.profile;
    _routeJson = route.profile.toJson();
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
    final saved = _services.routes.forExpedition(_expedition.id);
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
    _bridge.setPois(_services.routes.forExpedition(_expedition.id)?.pois ?? []);
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

  // ------------------------------------------------------------ Grabación

  /// Hay un recorrido en curso de esta expedición.
  bool get _recordingHere =>
      _recorder.isActive && _recorder.track?.expeditionId == _expedition.id;

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
            'Ya hay un recorrido en curso en "${other?.name ?? 'otra expedición'}". Termínalo primero.',
          ),
        ),
      );
      return;
    }
    final status = await _location.ensurePermission();
    if (!mounted) return;
    if (status != LocationStatus.granted) {
      messenger.showSnackBar(
        SnackBar(content: Text(_permissionMessage(status))),
      );
      return;
    }
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
    final now = DateTime.now();
    final n = _services.tracks.forExpedition(_expedition.id).length + 1;
    _following = true;
    _centeredOnFirstFix = false;
    await _recorder.start(
      expeditionId: _expedition.id,
      name: 'Recorrido $n · ${fmtDate(now)}',
      route: _route,
      turnaround: _expedition.turnaroundOn(now),
      mode: mode,
    );
    await _bridge.setTrack(const []);
    _setLayer('track', true);
  }

  Future<void> _stopRecording() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminar recorrido'),
        content: Text(
          '${fmtKm(_recorder.stats.meters, decimals: 2)} km · +${fmtInt(_recorder.stats.gain)} m · ${fmtClock(_recorder.activeTime)} en total, ${fmtDuration(_recorder.stats.moving)} en movimiento',
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
        _moveSheet(_sheetInitial);
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

  /// Baja el panel durante el vuelo 3D para que no lo tape, y lo sube al terminar.
  void _moveSheet(double size) {
    if (!_sheet.isAttached) return;
    _sheet.animateTo(
      size,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void _toggleFly() {
    if (_flying) {
      _bridge.stopFly();
      setState(() => _flying = false);
      _moveSheet(_sheetInitial);
    } else {
      setState(() {
        _flying = true;
        _is3d = true;
      });
      _moveSheet(_sheetMin);
      _bridge.flyRoute();
    }
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_permissionMessage(status))));
      return;
    }
    if (_locating) return;
    setState(() => _locating = true);
    var first = true;
    _subs.add(
      _location.positions().listen((p) {
        _bridge.setMyLocation(p.longitude, p.latitude);
        if (first) {
          first = false;
          _bridge.flyTo(p.longitude, p.latitude, zoom: 14);
        }
      }),
    );
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
          final scheme = Theme.of(context).colorScheme;
          final status = _services.expeditions.statusOf(_expedition);
          return PopScope(
            canPop: _planner == null,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              final navigator = Navigator.of(context);
              if (await _cancelPlan() && mounted) navigator.pop();
            },
            child: Scaffold(
              body: Stack(
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
                                  onSelectionChanged: (s) => _setMode(s.first),
                                ),
                              ),
                            )
                          else
                            Flexible(
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
                                            : 'EXPEDICIÓN',
                                        style: labelStyle(
                                          context,
                                          color: _recordingHere
                                              ? recordColor
                                              : Andes.gold,
                                        ).copyWith(fontSize: 9.5),
                                      ),
                                      Text(
                                        _expedition.name,
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
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: MediaQuery.paddingOf(context).top + 70,
                    child: Column(
                      children: [
                        _MapButton(
                          icon: (_recordingHere ? _following : _locating)
                              ? Icons.my_location_rounded
                              : Icons.location_searching_rounded,
                          tooltip: _recordingHere && !_following
                              ? 'Seguir mi posición'
                              : 'Mi ubicación',
                          onPressed: _locateMe,
                        ),
                        const SizedBox(height: 8),
                        _MapButton(
                          icon: _recordingHere
                              ? Icons.fiber_manual_record_rounded
                              : Icons.radio_button_checked_rounded,
                          color: recordColor,
                          tooltip: _recordingHere
                              ? 'Grabando'
                              : 'Grabar recorrido',
                          onPressed: _recordingHere ? () {} : _startRecording,
                        ),
                        if (!_recordingHere && _planner == null && !civil) ...[
                          const SizedBox(height: 8),
                          _MapButton(
                            icon: Icons.edit_road_rounded,
                            color: Andes.gold,
                            tooltip: _route == null
                                ? 'Planear ruta'
                                : 'Editar ruta',
                            onPressed: _startPlanning,
                          ),
                        ],
                        const SizedBox(height: 8),
                        _MapButton(
                          label: _is3d ? '2D' : '3D',
                          tooltip: _is3d ? 'Cambiar a 2D' : 'Cambiar a 3D',
                          onPressed: () => _set3d(!_is3d),
                        ),
                      ],
                    ),
                  ),
                  DraggableScrollableSheet(
                    controller: _sheet,
                    minChildSize: _sheetMin,
                    initialChildSize: _sheetInitial,
                    maxChildSize: _sheetMax,
                    snap: true,
                    snapSizes: const [_sheetMin, _sheetInitial, _sheetMax],
                    builder: (context, scroll) => Material(
                      // Opaco: sobre el WebView cualquier transparencia deja ver las etiquetas del mapa
                      color: Andes.surfaceLow,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListView(
                        controller: scroll,
                        padding: EdgeInsets.fromLTRB(
                          20,
                          0,
                          20,
                          24 + MediaQuery.paddingOf(context).bottom,
                        ),
                        children: [
                          Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: scheme.outlineVariant,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          if (_planner != null)
                            PlannerPanel(
                              planner: _planner!,
                              placingPoi: _placingPoi,
                              onPlacePoi: (k) {
                                setState(() => _placingPoi = k);
                                // Baja el panel para dejar libre el mapa donde hay que tocar
                                if (k != null) {
                                  // Después del cuadro: el selector aún se está cerrando
                                  WidgetsBinding.instance.addPostFrameCallback(
                                    (_) => _moveSheet(_sheetMin),
                                  );
                                }
                              },
                              onSave: _savePlan,
                              onCancel: _cancelPlan,
                            )
                          else ...[
                            if (_recordingHere)
                              RecordingPanel(
                                recorder: _recorder,
                                onPause: _recorder.pause,
                                onResume: _recorder.resume,
                                onStop: _stopRecording,
                              ),
                            if (civil && _civil != null) ...[
                              VolcanoAlertCard(civil: _civil!),
                              ShelterList(
                                civil: _civil!,
                                onTap: (s) => _bridge.flyTo(
                                  s.at.lng,
                                  s.at.lat,
                                  zoom: 13.2,
                                  pitch: 50,
                                ),
                              ),
                              ReportList(
                                civil: _civil!,
                                onTap: (r) => _bridge.flyTo(
                                  r.at.lng,
                                  r.at.lat,
                                  zoom: 13.5,
                                ),
                                onSimulateAlert: _simulateAlert,
                              ),
                            ] else if (_route != null) ...[
                              RouteCard(
                                route: _route!,
                                cursorMeters: _cursor,
                                flying: _flying,
                                onScrub: (m) {
                                  setState(() => _cursor = m);
                                  _bridge.showCursorAtMeters(m);
                                },
                                onScrubEnd: () {},
                                onFly: _toggleFly,
                                onFit: () {
                                  _bridge.stopFly();
                                  _bridge.fitRoute();
                                },
                              ),
                              if (_group != null)
                                GroupList(
                                  route: _route!,
                                  members: _group!.members,
                                  onTap: (m) {
                                    final p = _route!.along(m.meters).position;
                                    _bridge.flyTo(
                                      p.lng,
                                      p.lat,
                                      zoom: 14.6,
                                      pitch: 62,
                                    );
                                  },
                                ),
                            ] else
                              _OfflineSummary(
                                status: status,
                                onAddZone: _addZone,
                                onFit: () {
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
                                _bridge.setBase(b);
                              },
                              on3d: _set3d,
                              onExaggeration: (x) {
                                setState(() => _exaggeration = x);
                                _bridge.setExaggeration(x);
                              },
                            ),
                            LayerList(
                              layers: _availableLayers,
                              states: _layers,
                              onChanged: _setLayer,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Mapa: © OpenMapTiles, © colaboradores de OpenStreetMap. Satélite: Sentinel-2 cloudless 2024 de EOX '
                              '(datos Copernicus). Relieve: Mapzen Terrain Tiles.'
                              '${_civil != null ? ' Los datos de protección civil y el grupo son ilustrativos, no información oficial.' : ''}',
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
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

class _MapButton extends StatelessWidget {
  const _MapButton({
    this.icon,
    this.label,
    this.color,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData? icon;
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
                    ? Icon(icon, size: 22, color: color ?? Andes.onSurface)
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
