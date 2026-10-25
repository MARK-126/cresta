import 'dart:async';

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
import 'area_picker_screen.dart';
import 'format.dart';
import 'offline_widgets.dart';
import 'panels.dart';
import 'theme.dart';

/// El mapa de una expedición, en 2D o 3D, con lo descargado y (si hay red) lo demás.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.expeditionId});
  final String expeditionId;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _sheetMin = 0.14, _sheetInitial = 0.38, _sheetMax = 0.9;

  final _bridge = MapBridge();
  final _location = LocationService();
  final _subs = <StreamSubscription<dynamic>>[];
  late AppServices _services;
  late Expedition _expedition;

  TrailRoute? _route;
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
    _bridge.load(_services.server.baseUri);
    _subs.add(_bridge.events.listen(_onMapEvent));
    _boot();
  }

  Future<void> _boot() async {
    const assets = AssetData();
    Map<String, dynamic>? routeJson, civilJson;
    if (_expedition.routeAsset != null) {
      final (route, json) = await assets.route(_expedition.routeAsset!);
      routeJson = json;
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
    if (routeJson != null) await _bridge.setRoute(routeJson);
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
  }

  @override
  void dispose() {
    _services.maps.removeListener(_pushRegions);
    for (final s in _subs) {
      s.cancel();
    }
    _group?.dispose();
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
      case 'markerTap':
        _showMarkerInfo(e.data['kind'] as String, e.data['id'] as String);
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

  Future<void> _locateMe() async {
    final status = await _location.ensurePermission();
    if (!mounted) return;
    final message = switch (status) {
      LocationStatus.serviceOff =>
        'Activa la ubicación del teléfono para verte en el mapa.',
      LocationStatus.denied =>
        'Sin permiso de ubicación. Puedes darlo cuando quieras.',
      LocationStatus.deniedForever =>
        'El permiso de ubicación está bloqueado. Actívalo en Ajustes.',
      LocationStatus.granted => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
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
    final brightness = Theme.of(context).brightness;
    return Theme(
      data: crestaTheme(brightness, civil: civil),
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          final status = _services.expeditions.statusOf(_expedition);
          return Scaffold(
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
                        IconButton.filledTonal(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 6),
                        if (_civil != null)
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: scheme.surface.withValues(alpha: .94),
                                borderRadius: BorderRadius.circular(22),
                              ),
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
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surface.withValues(alpha: .94),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Text(
                                _expedition.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
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
                        icon: _locating
                            ? Icons.my_location_rounded
                            : Icons.location_searching_rounded,
                        tooltip: 'Mi ubicación',
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
                DraggableScrollableSheet(
                  minChildSize: _sheetMin,
                  initialChildSize: _sheetInitial,
                  maxChildSize: _sheetMax,
                  snap: true,
                  snapSizes: const [_sheetMin, _sheetInitial, _sheetMax],
                  builder: (context, scroll) => Material(
                    color: scheme.surface.withValues(alpha: .97),
                    elevation: 8,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListView(
                      controller: scroll,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        24 + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: scheme.outlineVariant,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
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
                            onTap: (r) =>
                                _bridge.flyTo(r.at.lng, r.at.lat, zoom: 13.5),
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
                    ),
                  ),
                ),
              ],
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
    required this.tooltip,
    required this.onPressed,
  });
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
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 22)
                  : Text(
                      label!,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
