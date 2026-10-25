import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app_services.dart';
import '../map/map_bridge.dart';
import '../map/map_layers.dart';
import '../offline/map_sources.dart';
import '../offline/offline_region.dart';
import '../offline/tile_math.dart';
import '../search/place_search.dart';
import 'format.dart';
import 'offline_widgets.dart';
import 'theme.dart';

/// Elegir una zona en el mapa y descargarla: lo que queda dentro del recuadro es lo que se baja.
class AreaPickerScreen extends StatefulWidget {
  const AreaPickerScreen({super.key, required this.expeditionId});
  final String expeditionId;

  @override
  State<AreaPickerScreen> createState() => _AreaPickerScreenState();
}

class _AreaPickerScreenState extends State<AreaPickerScreen> {
  static const _panelHeight = 300.0;
  static const _topBar = 64.0;

  final _bridge = MapBridge();
  final _search = PlaceSearch();
  final _query = TextEditingController();
  final _name = TextEditingController();
  StreamSubscription<MapEvent>? _sub;

  BBox? _bbox;
  DetailLevel _detail = DetailLevel.detailed;
  final _sources = {MapSource.dem, MapSource.sat, MapSource.topo};
  MapBase _base = MapBase.topo;
  List<Place>? _results;
  bool _searching = false;
  String? _searchError;
  bool _nameEdited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sub != null) return;
    final services = AppScope.of(context);
    _bridge.load(services.server.baseUri);
    _sub = _bridge.events
        .where((e) => e.type == 'moveEnd')
        .listen((_) => _updateBounds());
    _bridge.ready.then((_) async {
      await _bridge.setPickerMode(true);
      await _bridge.setLayers({
        'contours': false,
        'trails': true,
        'labels': true,
        'regions': true,
        'hillshade': true,
      });
      await _bridge.setRegions(services.maps.regions);
      final e = services.expeditions.byId(widget.expeditionId);
      final existing = e == null
          ? null
          : services.expeditions.statusOf(e).bounds;
      if (existing != null) {
        await _bridge.fitBounds(existing.expandKm(3));
      } else {
        await _bridge.jumpTo(
          -99.1,
          19.3,
          7.5,
        ); // centro de México; el usuario busca o se mueve
      }
      _updateBounds();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _bridge.dispose();
    _query.dispose();
    _name.dispose();
    super.dispose();
  }

  /// El recuadro en coordenadas de la pantalla (las mismas que usa el WebView).
  Rect _frame(Size size, EdgeInsets padding) => Rect.fromLTRB(
    24,
    padding.top + _topBar + 24,
    size.width - 24,
    size.height - _panelHeight - padding.bottom - 24,
  );

  Future<void> _updateBounds() async {
    if (!mounted) return;
    final mq = MediaQuery.of(context);
    final b = await _bridge.boundsOfRect(_frame(mq.size, mq.padding));
    if (mounted && b != null) setState(() => _bbox = b);
  }

  Future<void> _runSearch(String q) async {
    if (q.trim().isEmpty) return;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final r = await _search.search(q.trim(), near: _bbox);
      setState(() => _results = r);
      if (r.isEmpty) _searchError = 'Sin resultados para "$q"';
    } on Exception {
      setState(() => _searchError = 'No se pudo buscar. ¿Hay conexión?');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _pick(Place p) {
    setState(() {
      _results = null;
      if (!_nameEdited) _name.text = p.name;
    });
    FocusScope.of(context).unfocus();
    final b = p.bbox;
    // Un punto (cumbre) o un área pequeña se abre con unos km alrededor
    if (b == null || b.widthKm < 4) {
      _bridge.flyTo(p.lng, p.lat, zoom: 12, pitch: 0);
    } else {
      _bridge.fitBounds(b);
    }
  }

  Future<void> _download() async {
    final b = _bbox;
    if (b == null) return;
    final services = AppScope.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim().isEmpty
        ? 'Zona ${services.maps.regions.length + 1}'
        : _name.text.trim();
    final region = await services.maps.add(
      name: name,
      bbox: b,
      detail: _detail,
      sources: _sources,
    );
    final e = services.expeditions.byId(widget.expeditionId);
    if (e != null) await services.expeditions.attachRegion(e, region.id);
    final reason = services.maps.blockedReason;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          reason == null
              ? 'Descargando "$name". Puedes seguir usando la app; mantenla abierta hasta que termine.'
              : '"$name" quedó en la cola: ${reason.toLowerCase()}.',
        ),
      ),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final mq = MediaQuery.of(context);
    final scheme = Theme.of(context).colorScheme;
    final frame = _frame(mq.size, mq.padding);
    final est = _bbox == null
        ? null
        : OfflineRegion.estimate(_bbox!, _detail, _sources);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _bridge.controller)),
          // Oscurece fuera del recuadro; no recibe toques para que el mapa se pueda mover
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _FramePainter(frame, scheme.primary)),
            ),
          ),
          // Selector de mapa base (solo para orientarse)
          Positioned(
            right: 36,
            top: frame.top + 12,
            child: Material(
              color: scheme.surface.withValues(alpha: .94),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final b in [MapBase.topo, MapBase.sat])
                      ChoiceChip(
                        label: Text(b.label),
                        selected: _base == b,
                        visualDensity: VisualDensity.compact,
                        showCheckmark: false,
                        onSelected: (_) {
                          setState(() => _base = b);
                          _bridge.setBase(b);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Barra superior: volver + buscador
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Material(
                            color: scheme.surface,
                            elevation: 2,
                            borderRadius: BorderRadius.circular(24),
                            child: TextField(
                              controller: _query,
                              autocorrect: false,
                              enableSuggestions: false,
                              textInputAction: TextInputAction.search,
                              onSubmitted: _runSearch,
                              decoration: InputDecoration(
                                hintText: 'Buscar cumbre, parque o pueblo',
                                prefixIcon: _searching
                                    ? const Padding(
                                        padding: EdgeInsets.all(14),
                                        child: SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : const Icon(Icons.search_rounded),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_results != null || _searchError != null)
                      Container(
                        margin: const EdgeInsets.only(left: 54, top: 6),
                        constraints: const BoxConstraints(maxHeight: 280),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(blurRadius: 8, color: Colors.black26),
                          ],
                        ),
                        child: _searchError != null
                            ? Padding(
                                padding: const EdgeInsets.all(14),
                                child: Text(_searchError!),
                              )
                            : ListView(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                children: [
                                  for (final p in _results!)
                                    ListTile(
                                      dense: true,
                                      title: Text(p.name),
                                      subtitle: Text(
                                        p.detail,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onTap: () => _pick(p),
                                    ),
                                ],
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Panel inferior
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              color: scheme.surface,
              elevation: 8,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: SizedBox(
                height: _panelHeight + mq.padding.bottom + mq.viewInsets.bottom,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    14,
                    16,
                    16 + mq.padding.bottom,
                  ),
                  children: [
                    Text(
                      'Mueve el mapa para encuadrar la zona',
                      style: signage(context, size: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      est == null
                          ? 'Calculando…'
                          : '${_bbox!.widthKm.toStringAsFixed(0)} × ${_bbox!.heightKm.toStringAsFixed(0)} km · ≈ ${fmtBytes(est.bytes)} · ${fmtInt(est.tiles)} mosaicos',
                      style: dataStyle(
                        context,
                        size: 12.5,
                        color: est?.tooBig == true
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    if (est?.tooBig == true)
                      Text(
                        'Zona demasiado grande: acerca el mapa o usa detalle Básico.',
                        style: TextStyle(color: scheme.error, fontSize: 12.5),
                      ),
                    const SizedBox(height: 10),
                    SegmentedButton<DetailLevel>(
                      segments: [
                        for (final d in DetailLevel.values)
                          ButtonSegment(value: d, label: Text(d.label)),
                      ],
                      selected: {_detail},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) =>
                          setState(() => _detail = s.first),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _detail.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final s in MapSource.values)
                          FilterChip(
                            label: Text(s.label),
                            selected: _sources.contains(s),
                            onSelected: s.required
                                ? null
                                : (on) => setState(
                                    () => on
                                        ? _sources.add(s)
                                        : _sources.remove(s),
                                  ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _name,
                      onChanged: (_) => _nameEdited = true,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la zona',
                        hintText: 'Ej. Nevado de Toluca',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListenableBuilder(
                      listenable: services.maps,
                      builder: (context, _) => Row(
                        children: [
                          Expanded(
                            child: Text(
                              services.maps.wifiOnly
                                  ? 'Solo con Wi-Fi'
                                  : 'Wi-Fi o datos móviles',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Switch(
                            value: services.maps.wifiOnly,
                            onChanged: services.maps.setWifiOnly,
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: est == null || est.tooBig ? null : _download,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Descargar zona'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    if (services.maps.blockedReason != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${services.maps.blockedReason}: la zona se guardará y se descargará en cuanto se pueda.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: warnColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.frame, this.color);
  final Rect frame;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(frame, const Radius.circular(10));
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(r);
    canvas.drawPath(
      outside,
      Paint()..color = Colors.black.withValues(alpha: .35),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.frame != frame || old.color != color;
}
