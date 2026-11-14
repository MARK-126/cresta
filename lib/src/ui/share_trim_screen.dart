import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app_services.dart';
import '../map/map_bridge.dart';
import '../offline/tile_math.dart';
import '../tracking/share_trim.dart';
import '../tracking/track.dart';
import 'format.dart';
import 'theme.dart';

/// Elegir qué parte del recorrido se ve al compartirlo (video, GPX, imagen): con dos
/// tiradores se ocultan el inicio y el fin, para no mostrar dónde vives, como las zonas de
/// privacidad de Strava (hubo robos de bicis a gente que salía de su casa). Lo oculto se
/// ve gris en el mapa; dentro de la app el recorrido sigue completo.
class ShareTrimScreen extends StatefulWidget {
  const ShareTrimScreen({super.key, required this.track, required this.points});
  final Track track;
  final List<TrackPoint> points;

  @override
  State<ShareTrimScreen> createState() => _ShareTrimScreenState();
}

class _ShareTrimScreenState extends State<ShareTrimScreen> {
  final _bridge = MapBridge();
  late final double _total = cumulativeMeters(widget.points).last;
  late RangeValues _range = RangeValues(
    widget.track.hideStart.clamp(0, _total),
    (_total - widget.track.hideEnd).clamp(0, _total),
  );
  bool _started = false;
  bool _ready = false;

  /// Lo visible nunca baja de esto: un recorrido de 0 m no se puede compartir.
  double get _minVisible => math.min(100, _total / 2);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final services = AppScope.of(context);
    _bridge.load(services.server.baseUri);
    _bridge.ready.then((_) async {
      if (!mounted) return;
      await _bridge.setBase(services.mapBase.value);
      await _bridge.set3d(false);
      await _bridge.setLayers({'track': true, 'labels': true});
      await _bridge.setPadding(top: 90, bottom: 40, left: 40, right: 40);
      await _push();
      await _bridge.fitBounds(_boundsOf(widget.points));
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _bridge.dispose();
    super.dispose();
  }

  Future<void> _push() async {
    final s = splitForSharing(widget.points, _range.start, _total - _range.end);
    await _bridge.setTrack(s.visible, showEnd: true);
    await _bridge.setHidden([s.before, s.after]);
  }

  BBox _boundsOf(List<TrackPoint> pts) {
    var w = pts.first.lng, e = w, s = pts.first.lat, n = s;
    for (final p in pts) {
      w = math.min(w, p.lng);
      e = math.max(e, p.lng);
      s = math.min(s, p.lat);
      n = math.max(n, p.lat);
    }
    return BBox(w, s, e == w ? e + 0.001 : e, n == s ? n + 0.001 : n);
  }

  Future<void> _save({bool clear = false}) async {
    final t = widget.track;
    t
      ..hideStart = clear ? 0 : _range.start.roundToDouble()
      ..hideEnd = clear ? 0 : (_total - _range.end).roundToDouble();
    await AppScope.of(context).tracks.save();
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final start = _range.start, end = _total - _range.end;
    final summary = start <= 0 && end <= 0
        ? 'Se comparte completo.'
        : 'Se ocultan ${fmtDistance(start)} al inicio y ${fmtDistance(end)} al final.';
    return Scaffold(
      appBar: AppBar(title: const Text('Recortar para compartir')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: WebViewWidget(controller: _bridge.controller),
                ),
                if (!_ready)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Andes.surface,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('LO QUE SE VE AL COMPARTIR', style: labelStyle(context)),
                  const SizedBox(height: 4),
                  Text(
                    'Mueve los extremos para no mostrar dónde empiezas y terminas (tu casa, por ejemplo). Se aplica al video, al GPX y a la imagen; en la app lo sigues viendo completo.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Andes.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  RangeSlider(
                    values: _range,
                    max: _total,
                    labels: RangeLabels(
                      'Oculto: ${fmtDistance(start)}',
                      'Oculto: ${fmtDistance(end)}',
                    ),
                    onChanged: (v) {
                      if (v.end - v.start < _minVisible) return;
                      setState(() => _range = v);
                      _push();
                    },
                  ),
                  Text(
                    summary,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Se ven ${fmtDistance(_range.end - _range.start)} de ${fmtDistance(_total)}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Andes.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GlowButton(
                    label: 'Guardar recorte',
                    icon: Icons.check_rounded,
                    onPressed: _save,
                  ),
                  if (widget.track.trimmed)
                    TextButton(
                      onPressed: () => _save(clear: true),
                      child: const Text('Quitar el recorte'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
