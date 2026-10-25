import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
      ..setBackgroundColor(const Color(0xFF1D2426))
      ..addJavaScriptChannel('CrestaBridge', onMessageReceived: _onMessage);
  }

  late final WebViewController controller;
  final _events = StreamController<MapEvent>.broadcast();
  final _ready = Completer<void>();

  Stream<MapEvent> get events => _events.stream;
  Future<void> get ready => _ready.future;

  Future<void> load(Uri baseUri) => controller.loadRequest(baseUri.resolve('/index.html'));

  void _onMessage(JavaScriptMessage message) {
    final json = jsonDecode(message.message) as Map<String, dynamic>;
    final event = MapEvent(json['type'] as String, json);
    if (event.type == 'ready' && !_ready.isCompleted) _ready.complete();
    if (event.type == 'error') debugPrint('Mapa: ${json['message']}');
    _events.add(event);
  }

  Future<void> _call(String method, [List<Object?> args = const []]) async {
    final js = 'window.cresta && window.cresta.$method(${args.map(jsonEncode).join(',')});';
    try {
      await controller.runJavaScript(js);
    } catch (e) {
      debugPrint('MapBridge.$method: $e');
    }
  }

  Future<void> setPadding({double top = 40, double bottom = 40, double left = 40, double right = 40}) =>
      _call('setPadding', [{'top': top, 'bottom': bottom, 'left': left, 'right': right}]);
  Future<void> setLayers(Map<String, bool> states) => _call('setLayers', [states]);
  Future<void> setLayer(String id, bool on) => _call('setLayer', [id, on]);
  Future<void> setSatellite(bool satellite) => _call('setBase', [satellite ? 'sat' : 'rel']);
  Future<void> set3d(bool on) => _call('set3d', [on]);
  Future<void> setExaggeration(double x) => _call('setExaggeration', [x]);
  Future<void> fitRoute() => _call('fitRoute');
  Future<void> flyRoute() => _call('flyRoute');
  Future<void> stopFly() => _call('stopFly');
  Future<void> flyTo(double lng, double lat, {double zoom = 13.5, double pitch = 55, double? bearing}) =>
      _call('flyTo', [lng, lat, zoom, pitch, bearing]);
  Future<void> showCursorAtMeters(double m) => _call('showCursorAtMeters', [m]);
  Future<void> hideCursor() => _call('hideCursor');
  Future<void> setMembers(List<Map<String, Object>> members) => _call('setMembers', [members]);
  Future<void> setMyLocation(double lng, double lat) => _call('setMyLocation', [lng, lat]);
  Future<void> pulseReport(String id) => _call('pulseReport', [id]);

  void dispose() => _events.close();
}
