import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/asset_repository.dart';
import '../group/group_simulator.dart';
import '../location/location_service.dart';
import '../map/map_bridge.dart';
import '../map/map_layers.dart';
import 'format.dart';
import 'panels.dart';
import 'theme.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.data, required this.baseUri, required this.mode, required this.onModeChanged});

  final AppData data;
  final Uri baseUri;
  final AppMode mode;
  final ValueChanged<AppMode> onModeChanged;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _sheetMin = 0.14, _sheetInitial = 0.42, _sheetMax = 0.9;

  final _bridge = MapBridge();
  final _location = LocationService();
  late final GroupSimulator _group = GroupSimulator(widget.data.route);
  final _subs = <StreamSubscription<dynamic>>[];

  late Map<String, bool> _layers = layerPreset(widget.mode);
  bool _satellite = true;
  bool _is3d = true;
  double _exaggeration = 1.4;
  bool _flying = false;
  double? _cursor;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _bridge.load(widget.baseUri);
    _subs.add(_bridge.events.listen(_onMapEvent));
    _subs.add(_group.updates.listen((members) {
      if (mounted) setState(() {});
      _pushMembers(members);
    }));
    _bridge.ready.then((_) async {
      await _applyPadding();
      await _bridge.setLayers(_layers);
      _pushMembers(_group.members);
      await _bridge.fitRoute();
      _group.start();
    });
  }

  @override
  void didUpdateWidget(MapScreen old) {
    super.didUpdateWidget(old);
    if (old.mode != widget.mode) _enterMode(widget.mode);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _group.dispose();
    _bridge.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ Mapa

  void _onMapEvent(MapEvent e) {
    switch (e.type) {
      case 'flyProgress':
        setState(() => _cursor = (e.data['meters'] as num).toDouble());
      case 'flyEnd':
        setState(() => _flying = false);
      case 'markerTap':
        _showMarkerInfo(e.data['kind'] as String, e.data['id'] as String);
    }
  }

  Future<void> _applyPadding() async {
    final size = MediaQuery.sizeOf(context);
    await _bridge.setPadding(top: 110, bottom: size.height * _sheetInitial + 20, left: 30, right: 30);
  }

  void _pushMembers(List<GroupMember> members) {
    _bridge.setMembers([
      for (final m in members)
        {
          'id': m.id,
          'initials': m.initials,
          'color': '#${(m.color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
          'lng': _group.route.along(m.meters).position.lng,
          'lat': _group.route.along(m.meters).position.lat,
        },
    ]);
  }

  void _enterMode(AppMode mode) {
    setState(() {
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

  Future<void> _locateMe() async {
    final status = await _location.ensurePermission();
    if (!mounted) return;
    final message = switch (status) {
      LocationStatus.serviceOff => 'Activa la ubicación del teléfono para verte en el mapa.',
      LocationStatus.denied => 'Sin permiso de ubicación. Puedes darlo cuando quieras.',
      LocationStatus.deniedForever => 'El permiso de ubicación está bloqueado. Actívalo en Ajustes.',
      LocationStatus.granted => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    if (_locating) return;
    setState(() => _locating = true);
    var first = true;
    _subs.add(_location.positions().listen((p) {
      _bridge.setMyLocation(p.longitude, p.latitude);
      if (first) {
        first = false;
        _bridge.flyTo(p.longitude, p.latitude, zoom: 14);
      }
    }));
  }

  void _simulateAlert() {
    final civil = widget.data.civil;
    _setLayer('reports', true);
    _setLayer('ash', true);
    _bridge.pulseReport(civil.reports.first.id);
    _bridge.flyTo(-98.53, 19.05, zoom: 11.4, pitch: 58, bearing: 300);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Alerta de prueba: caída de ceniza en San Nicolás de los Ranchos. 3 albergues notificados.'),
    ));
  }

  void _showMarkerInfo(String kind, String id) {
    final d = widget.data;
    final (String title, String body) = switch (kind) {
      'peak' => () {
          final p = d.peaks.firstWhere((p) => p.name == id);
          final ele = p.elevation == null ? '' : '${fmtInt(p.elevation!)} m · ';
          final note = p.climbingForbidden
              ? 'Volcán activo. Ascenso prohibido desde 1994.'
              : switch (p.kind) { 'alpine_hut' => 'Albergue de alta montaña.', 'trailhead' => 'Inicio de ruta y control de acceso al parque.', _ => 'Cumbre' };
          return (p.name, '$ele$note');
        }(),
      'shelter' => () {
          final s = d.civil.shelters.firstWhere((s) => s.id == id);
          return ('Albergue ${s.name}', '${s.place}\n${fmtInt(s.free)} lugares libres de ${fmtInt(s.capacity)}');
        }(),
      'report' => () {
          final r = d.civil.reports.firstWhere((r) => r.id == id);
          return (r.type, '${r.by} · ${fmtAgo(r.minutesAgo)}');
        }(),
      'member' => () {
          final m = _group.members.firstWhere((m) => m.id == id);
          return (m.name, '${fmtInt(_group.route.along(m.meters).elevation)} m · km ${fmtKm(m.meters)}');
        }(),
      _ => (id, ''),
    };
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: signage(context, size: 22)),
            const SizedBox(height: 6),
            Text(body),
          ]),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = widget.data;
    final civil = widget.mode == AppMode.civil;

    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: WebViewWidget(controller: _bridge.controller)),
        // Barra superior: marca y modo
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: scheme.surface.withValues(alpha: .94), borderRadius: BorderRadius.circular(10)),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: 'CRESTA', style: signage(context, size: 20)),
                  TextSpan(text: '.', style: signage(context, size: 20).copyWith(color: scheme.primary)),
                ])),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: scheme.surface.withValues(alpha: .94), borderRadius: BorderRadius.circular(22)),
                  child: SegmentedButton<AppMode>(
                    segments: const [
                      ButtonSegment(value: AppMode.mountain, label: Text('Montaña'), icon: Icon(Icons.terrain_rounded)),
                      ButtonSegment(value: AppMode.civil, label: Text('Prot. civil'), icon: Icon(Icons.shield_outlined)),
                    ],
                    selected: {widget.mode},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => widget.onModeChanged(s.first),
                  ),
                ),
              ),
            ]),
          ),
        ),
        // Botones flotantes del mapa
        Positioned(
          right: 12,
          top: MediaQuery.paddingOf(context).top + 70,
          child: Column(children: [
            _MapButton(
              icon: _locating ? Icons.my_location_rounded : Icons.location_searching_rounded,
              tooltip: 'Mi ubicación',
              onPressed: _locateMe,
            ),
            const SizedBox(height: 8),
            _MapButton(
              label: _is3d ? '2D' : '3D',
              tooltip: _is3d ? 'Cambiar a 2D' : 'Cambiar a 3D',
              onPressed: () => _set3d(!_is3d),
            ),
          ]),
        ),
        DraggableScrollableSheet(
          minChildSize: _sheetMin,
          initialChildSize: _sheetInitial,
          maxChildSize: _sheetMax,
          snap: true,
          snapSizes: const [_sheetMin, _sheetInitial, _sheetMax],
          builder: (context, scroll) => Material(
            color: scheme.surface.withValues(alpha: .97),
            elevation: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: ListView(
              controller: scroll,
              padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.paddingOf(context).bottom),
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                if (!civil) ...[
                  RouteCard(
                    route: d.route,
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
                  GroupList(
                    route: d.route,
                    members: _group.members,
                    onTap: (m) {
                      final p = d.route.along(m.meters).position;
                      _bridge.flyTo(p.lng, p.lat, zoom: 14.6, pitch: 62);
                    },
                  ),
                ] else ...[
                  VolcanoAlertCard(civil: d.civil),
                  ShelterList(civil: d.civil, onTap: (s) => _bridge.flyTo(s.at.lng, s.at.lat, zoom: 13.2, pitch: 50)),
                  ReportList(
                    civil: d.civil,
                    onTap: (r) => _bridge.flyTo(r.at.lng, r.at.lat, zoom: 13.5),
                    onSimulateAlert: _simulateAlert,
                  ),
                ],
                ViewControls(
                  satellite: _satellite,
                  is3d: _is3d,
                  exaggeration: _exaggeration,
                  onSatellite: (v) {
                    setState(() {
                      _satellite = v;
                      if (!v) _layers['hillshade'] = true;
                    });
                    _bridge.setSatellite(v);
                    if (!v) _bridge.setLayer('hillshade', true);
                  },
                  on3d: _set3d,
                  onExaggeration: (x) {
                    setState(() => _exaggeration = x);
                    _bridge.setExaggeration(x);
                  },
                ),
                LayerList(states: _layers, onChanged: _setLayer),
                const SizedBox(height: 16),
                Text(
                  'Senderos y cumbres: © colaboradores de OpenStreetMap (ODbL). Relieve: Mapzen Terrain Tiles. '
                  'Imagen: Esri World Imagery. Zonas de peligro, albergues, reportes y grupo son ilustrativos, no información oficial.',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
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
}

class _MapButton extends StatelessWidget {
  const _MapButton({this.icon, this.label, required this.tooltip, required this.onPressed});
  final IconData? icon;
  final String? label;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surface.withValues(alpha: .94),
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(child: icon != null ? Icon(icon, size: 22) : Text(label!, style: const TextStyle(fontWeight: FontWeight.w700))),
          ),
        ),
      ),
    );
  }
}
