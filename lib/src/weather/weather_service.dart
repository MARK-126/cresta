import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/trail_route.dart';
import '../offline/map_sources.dart' show userAgent;
import '../offline/tile_math.dart';
import '../routes/route_profile.dart' show ElevationAt;
import '../storage/json_store.dart';
import 'forecast.dart';

/// El pronóstico guardado de una expedición: se consulta con conexión y se lee sin ella.
class WeatherSnapshot {
  WeatherSnapshot({required this.fetchedAt, required this.points});

  final DateTime fetchedAt;
  final List<PointForecast> points;

  /// Último día que cubre el pronóstico.
  DateTime? get lastDay => points.isEmpty || points.first.days.isEmpty
      ? null
      : points.first.days.last.date;
}

class WeatherException implements Exception {
  WeatherException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Consulta Open-Meteo (gratuito, sin clave) y guarda la respuesta por expedición.
class WeatherService extends ChangeNotifier {
  WeatherService({required this.client, required this.file});

  final http.Client client;
  final JsonStore file;

  /// expediciónId → {fetchedAt, points: [{point, raw}]} tal como se guarda.
  final _saved = <String, Map<String, dynamic>>{};
  final _parsed = <String, WeatherSnapshot>{};

  Future<void> load() async {
    final v = await file.read();
    if (v is Map) {
      for (final e in v.entries) {
        _saved[e.key as String] = e.value as Map<String, dynamic>;
      }
    }
    notifyListeners();
  }

  WeatherSnapshot? forExpedition(String id) {
    final cached = _parsed[id];
    if (cached != null) return cached;
    final raw = _saved[id];
    if (raw == null) return null;
    try {
      return _parsed[id] = WeatherSnapshot(
        fetchedAt: DateTime.parse(raw['fetchedAt'] as String),
        points: [
          for (final p in raw['points'] as List)
            parseForecast(
              WeatherPoint.fromJson(p['point'] as Map<String, dynamic>),
              p['raw'] as Map<String, dynamic>,
            ),
        ],
      );
    } catch (e) {
      debugPrint('WeatherService: pronóstico ilegible de $id: $e');
      return null;
    }
  }

  /// Pide el pronóstico de cada punto y lo guarda. Lanza [WeatherException] con un mensaje
  /// para el usuario si no hay conexión o el servicio falla.
  Future<WeatherSnapshot> refresh(
    String expeditionId,
    List<WeatherPoint> points,
  ) async {
    final results = <Map<String, dynamic>>[];
    for (final p in points) {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': p.lat.toStringAsFixed(4),
        'longitude': p.lng.toStringAsFixed(4),
        if (p.elevation != null) 'elevation': p.elevation!.round().toString(),
        'hourly': hourlyVars,
        'daily': dailyVars,
        'timezone': 'auto',
        'forecast_days': '16',
      });
      final http.Response res;
      try {
        res = await client
            .get(uri, headers: {'User-Agent': userAgent})
            .timeout(const Duration(seconds: 20));
      } on TimeoutException {
        throw WeatherException(
          'Open-Meteo tardó demasiado. Intenta de nuevo con mejor conexión.',
        );
      } catch (_) {
        throw WeatherException(
          'Sin conexión: el clima se consulta con internet y luego queda guardado.',
        );
      }
      if (res.statusCode != 200) {
        throw WeatherException(
          'Open-Meteo no respondió (error ${res.statusCode}). Intenta más tarde.',
        );
      }
      final raw = jsonDecode(res.body) as Map<String, dynamic>;
      // Se guarda el punto con la altitud resuelta (la nuestra o la del modelo)
      final resolved = parseForecast(p, raw).point;
      results.add({'point': resolved.toJson(), 'raw': raw});
    }
    _saved[expeditionId] = {
      'fetchedAt': DateTime.now().toIso8601String(),
      'points': results,
    };
    _parsed.remove(expeditionId);
    notifyListeners();
    await file.write(_saved);
    return forExpedition(expeditionId)!;
  }

  Future<void> delete(String expeditionId) async {
    if (_saved.remove(expeditionId) == null) return;
    _parsed.remove(expeditionId);
    notifyListeners();
    await file.write(_saved);
  }
}

/// Dónde consultar el clima: la salida y la parte más alta de la ruta (si hay ruta y la
/// diferencia vale la pena); si no, el centro de la zona descargada.
Future<List<WeatherPoint>> weatherPointsFor({
  TrailRoute? route,
  BBox? bounds,
  required ElevationAt elevation,
}) async {
  if (route != null && route.coordinates.isNotEmpty) {
    final start = route.coordinates.first;
    var top = 0;
    for (var i = 1; i < route.elevations.length; i++) {
      if (route.elevations[i] > route.elevations[top]) top = i;
    }
    final hasRelief = route.maxElevation > 0;
    final points = [
      WeatherPoint(
        label: 'Salida',
        lat: start.lat,
        lng: start.lng,
        elevation: hasRelief ? route.elevations.first : null,
      ),
    ];
    // Con menos de 300 m de diferencia el pronóstico sería prácticamente igual
    if (hasRelief && route.elevations[top] - route.elevations.first >= 300) {
      final c = route.coordinates[top];
      points.add(
        WeatherPoint(
          label: 'Punto más alto',
          lat: c.lat,
          lng: c.lng,
          elevation: route.elevations[top],
        ),
      );
    }
    return points;
  }
  if (bounds != null) {
    final lat = (bounds.south + bounds.north) / 2;
    final lng = (bounds.west + bounds.east) / 2;
    return [
      WeatherPoint(
        label: 'Centro de la zona',
        lat: lat,
        lng: lng,
        elevation: await elevation(lng, lat),
      ),
    ];
  }
  return const [];
}
