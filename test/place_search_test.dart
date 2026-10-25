import 'dart:convert';

import 'package:cresta/src/search/place_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _result(
  String category,
  String type,
  String display, {
  double importance = 0.1,
}) => {
  'category': category,
  'type': type,
  'name': display.split(', ').first,
  'display_name': display,
  'lat': '-32.65',
  'lon': '-70.01',
  'importance': importance,
  'boundingbox': ['-32.66', '-32.64', '-70.02', '-70.00'],
};

void main() {
  test('busca en todo el mundo, sin dar prioridad a la zona visible', () async {
    late Uri asked;
    final client = MockClient((req) async {
      asked = req.url;
      return http.Response('[]', 200);
    });
    await PlaceSearch(client: client).search('Aconcagua');
    expect(asked.queryParameters.containsKey('viewbox'), isFalse);
    expect(asked.queryParameters['q'], 'Aconcagua');
  });

  test('las cumbres van antes que las calles con el mismo nombre', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode([
          _result(
            'highway',
            'residential',
            'Aconcagua, Tlalnepantla, Estado de México, 54187, México',
          ),
          _result(
            'natural',
            'peak',
            'Aconcagua, Distrito Las Cuevas, Departamento Las Heras, Mendoza, Argentina',
          ),
          _result(
            'boundary',
            'protected_area',
            'Parque Provincial Aconcagua, Las Heras, Mendoza, Argentina',
          ),
        ]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final places = await PlaceSearch(client: client).search('Aconcagua');
    expect(places.map((p) => p.kind), [
      'Cumbre',
      'Área protegida',
      'Calle o camino',
    ]);
    expect(places.first.detail, 'Mendoza, Argentina');
    expect(
      places.last.detail,
      'Estado de México, México',
      reason: 'sin código postal',
    );
  });
}
