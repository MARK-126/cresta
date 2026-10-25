import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../offline/map_sources.dart';
import '../offline/tile_math.dart';

class Place {
  const Place({
    required this.name,
    required this.detail,
    required this.lng,
    required this.lat,
    this.kind = '',
    this.rank = 3,
    this.bbox,
  });

  final String name;

  /// Tipo legible: "Cumbre", "Área protegida", "Calle"…
  final String kind;

  /// Menor es mejor: montaña antes que pueblos, y calles al final.
  final int rank;
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

  /// Busca en todo el mundo. No se da prioridad a la zona visible: con eso
  /// "Aconcagua" devolvía calles de México en lugar del cerro en Argentina.
  Future<List<Place>> search(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'limit': '10',
      'accept-language': 'es',
    });
    final r = await _client
        .get(uri, headers: {'User-Agent': userAgent})
        .timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) {
      throw PlaceSearchException('El buscador respondió ${r.statusCode}');
    }
    final places = [
      for (final p in jsonDecode(r.body) as List)
        parse(p as Map<String, dynamic>),
    ];
    // Orden estable: dentro del mismo tipo se respeta la relevancia de Nominatim
    return [
      for (final rank in places.map((p) => p.rank).toSet().toList()..sort())
        ...places.where((p) => p.rank == rank),
    ].take(6).toList();
  }

  static (String, int) _kind(String category, String type) => switch ((
    category,
    type,
  )) {
    ('natural', 'peak') => ('Cumbre', 0),
    ('natural', 'volcano') => ('Volcán', 0),
    ('natural', 'ridge' || 'arete' || 'mountain_range') => ('Sierra', 0),
    ('natural', 'glacier') => ('Glaciar', 0),
    ('natural', 'saddle') => ('Collado', 0),
    ('natural', 'valley') => ('Valle', 0),
    ('natural', _) => ('Naturaleza', 0),
    ('boundary', 'national_park' || 'protected_area') => ('Área protegida', 1),
    ('leisure', 'nature_reserve') => ('Reserva natural', 1),
    ('tourism', 'alpine_hut' || 'wilderness_hut') => ('Refugio', 1),
    ('place', 'city') => ('Ciudad', 2),
    ('place', 'town' || 'village' || 'hamlet') => ('Pueblo', 2),
    ('place', _) || ('boundary', _) => ('Lugar', 2),
    ('highway', _) => ('Calle o camino', 4),
    _ => ('', 3),
  };

  @visibleForTesting
  static Place parse(Map<String, dynamic> p) {
    final display = p['display_name'] as String;
    final parts = display.split(', ');
    // Región y país al final, sin códigos postales
    final where = parts
        .skip(1)
        .where((x) => int.tryParse(x.replaceAll(' ', '')) == null)
        .toList();
    final (kind, rank) = _kind('${p['category']}', '${p['type']}');
    final bb = (p['boundingbox'] as List?)
        ?.map((v) => double.parse('$v'))
        .toList(); // [sur, norte, oeste, este]
    return Place(
      name: (p['name'] as String?)?.isNotEmpty == true
          ? p['name'] as String
          : parts.first,
      detail: where.skip(where.length > 2 ? where.length - 2 : 0).join(', '),
      kind: kind,
      rank: rank,
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
