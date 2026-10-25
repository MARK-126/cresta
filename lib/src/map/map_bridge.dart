import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../offline/offline_region.dart';
import '../offline/tile_math.dart';
import '../tracking/track.dart';
import 'map_layers.dart';

/// Evento enviado por `assets/web/map.js` a través del canal `CrestaBridge`.
class MapEvent {
  MapEvent(this.type, this.data);
  final String type;
  final Map<String, dynamic> data;
}

/// Puente entre Flutter y el motor de mapa (MapLibre GL JS en un WebView).
///
/// Está separado de la UI para que, cuando MapLibre Native soporte terreno 3D,
/// se pueda cambiar el motor sin tocar las pantallas.
class MapBridge {
  MapBridge() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFECE8DF))
      ..addJavaScriptChannel('CrestaBridge', onMessageReceived: _onMessage);
  }

  late final WebViewController controller;
  final _events = StreamController<MapEvent>.broadcast();
  final _ready = Completer<void>();

  Stream<MapEvent> get events => _events.stream;
  Future<void> get ready => _ready.future;

  Future<void> load(Uri baseUri) =>
      controller.loadRequest(baseUri.resolve('/index.html'));

  void _onMessage(JavaScriptMessage message) {
    final json = jsonDecode(message.message) as Map<String, dynamic>;
    final event = MapEvent(json['type'] as String, json);
    if (event.type == 'ready' && !_ready.isCompleted) _ready.complete();
    if (event.type == 'error') debugPrint('Mapa: ${json['message']}');
    if (!_events.isClosed) _events.add(event);
  }

  Future<void> _call(String method, [List<Object?> args = const []]) async {
    final js =
        'window.cresta && window.cresta.$method(${args.map(jsonEncode).join(',')});';
    try {
      await controller.runJavaScript(js);
    } catch (e) {
      debugPrint('MapBridge.$method: $e');
    }
  }

  /// Llama a un método que devuelve datos. iOS entrega el texto tal cual y Android lo entrega
  /// entre comillas, por eso se decodifica hasta obtener el objeto.
  Future<Object?> _query(String method, [List<Object?> args = const []]) async {
    final js =
        'JSON.stringify(window.cresta.$method(${args.map(jsonEncode).join(',')}))';
    Object? value = await controller.runJavaScriptReturningResult(js);
    while (value is String) {
      try {
        value = jsonDecode(value);
      } on FormatException {
        break;
      }
    }
    return value;
  }

  Future<void> setPadding({
    double top = 40,
    double bottom = 40,
    double left = 40,
    double right = 40,
  }) => _call('setPadding', [
    {'top': top, 'bottom': bottom, 'left': left, 'right': right},
  ]);
  Future<void> setLayers(Map<String, bool> states) =>
      _call('setLayers', [states]);
  Future<void> setLayer(String id, bool on) => _call('setLayer', [id, on]);
  Future<void> setBase(MapBase base) => _call('setBase', [base.name]);
  Future<void> set3d(bool on) => _call('set3d', [on]);
  Future<void> setExaggeration(double x) => _call('setExaggeration', [x]);
  Future<void> setPickerMode(bool on) => _call('setPickerMode', [on]);

  /// Dibuja un recorrido grabado; cada pausa empieza un tramo nuevo.
  Future<void> setTrack(List<TrackPoint> points) {
    final segments = <List<List<double>>>[];
    int? seg;
    for (final p in points) {
      if (p.segment != seg) {
        segments.add([]);
        seg = p.segment;
      }
      segments.last.add([p.lng, p.lat]);
    }
    return _call('setTrack', [segments]);
  }

  Future<void> setRoute(Map<String, dynamic>? route) =>
      _call('setRoute', [route]);
  Future<void> setCivil(Map<String, dynamic> civil) =>
      _call('setCivil', [civil]);
  Future<void> setRegions(List<OfflineRegion> regions) => _call('setRegions', [
    [
      for (final r in regions)
        {'name': r.name, 'bbox': r.bbox.toJson(), 'complete': r.isComplete},
    ],
  ]);
  Future<void> fitBounds(BBox b) =>
      _call('fitBounds', [b.west, b.south, b.east, b.north]);
  Future<void> fitRoute() => _call('fitRoute');
  Future<void> flyRoute() => _call('flyRoute');
  Future<void> stopFly() => _call('stopFly');
  Future<void> flyTo(
    double lng,
    double lat, {
    double zoom = 13.5,
    double pitch = 55,
    double? bearing,
  }) => _call('flyTo', [lng, lat, zoom, pitch, bearing]);
  Future<void> jumpTo(double lng, double lat, double zoom) =>
      _call('jumpTo', [lng, lat, zoom]);
  Future<void> showCursorAtMeters(double m) => _call('showCursorAtMeters', [m]);
  Future<void> hideCursor() => _call('hideCursor');
  Future<void> setMembers(List<Map<String, Object>> members) =>
      _call('setMembers', [members]);
  Future<void> setMyLocation(double lng, double lat) =>
      _call('setMyLocation', [lng, lat]);

  /// Centra el mapa en tu posición en cada lectura, hasta que muevas el mapa con el dedo.
  Future<void> setFollow(bool on, {double? zoom}) =>
      _call('setFollow', [on, zoom]);
  Future<void> pulseReport(String id) => _call('pulseReport', [id]);

  /// Zona geográfica que queda dentro de un rectángulo de la pantalla.
  Future<BBox?> boundsOfRect(Rect r) async {
    final v = await _query('boundsOfRect', [r.left, r.top, r.right, r.bottom]);
    if (v is! List || v.length != 4) return null;
    return BBox.fromJson(v);
  }

  void dispose() => _events.close();
}
