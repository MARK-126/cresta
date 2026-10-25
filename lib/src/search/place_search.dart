import 'dart:convert';

import 'package:http/http.dart' as http;

import '../offline/map_sources.dart';
import '../offline/tile_math.dart';

class Place {
  const Place({
    required this.name,
    required this.detail,
    required this.lng,
    required this.lat,
    this.bbox,
  });

  final String name;
  final String detail;
  final double lng;
  final double lat;
  final BBox? bbox;
}

/// Búsqueda de lugares con Nominatim (OpenStreetMap). Solo con conexión.
///
/// Su política de uso pide como máximo una búsqueda por segundo y nada de autocompletar,
/// por eso se busca únicamente al confirmar el texto.
class PlaceSearch {
  PlaceSearch({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// [near] da prioridad a lo que está en esa zona, sin excluir lo demás.
  Future<List<Place>> search(String query, {BBox? near}) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'limit': '6',
      'accept-language': 'es',
      if (near != null)
        'viewbox': '${near.west},${near.north},${near.east},${near.south}',
    });
    final r = await _client
        .get(uri, headers: {'User-Agent': userAgent})
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) {
      throw PlaceSearchException('El buscador respondió ${r.statusCode}');
    }
    return [
      for (final p in jsonDecode(r.body) as List)
        _parse(p as Map<String, dynamic>),
    ];
  }

  static Place _parse(Map<String, dynamic> p) {
    final display = p['display_name'] as String;
    final parts = display.split(', ');
    final bb = (p['boundingbox'] as List?)
        ?.map((v) => double.parse('$v'))
        .toList(); // [sur, norte, oeste, este]
    return Place(
      name: (p['name'] as String?)?.isNotEmpty == true
          ? p['name'] as String
          : parts.first,
      detail: parts.skip(1).take(3).join(', '),
      lng: double.parse('${p['lon']}'),
      lat: double.parse('${p['lat']}'),
      bbox: bb == null || bb[2] >= bb[3] || bb[0] >= bb[1]
          ? null
          : BBox(bb[2], bb[0], bb[3], bb[1]),
    );
  }
}

class PlaceSearchException implements Exception {
  PlaceSearchException(this.message);
  final String message;

  @override
  String toString() => message;
}
