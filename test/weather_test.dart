import 'dart:convert';
import 'dart:io';

import 'package:cresta/src/data/trail_route.dart';
import 'package:cresta/src/offline/tile_math.dart';
import 'package:cresta/src/storage/json_store.dart';
import 'package:cresta/src/weather/forecast.dart';
import 'package:cresta/src/weather/weather_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Respuesta mínima de Open-Meteo: 2 días, 3 horas por día (no hace falta que sean 24).
Map<String, dynamic> _response({
  double elevation = 5100,
  List<double> temps = const [-6, -7, -5, 1, 2, 3],
  List<double> precip = const [0, 0.4, 0, 0, 0, 0],
  List<double> freezing = const [4800, 4850, 4900, 5300, 5400, 5500],
}) => {
  'elevation': elevation,
  'hourly': {
    'time': [
      '2026-11-14T06:00',
      '2026-11-14T12:00',
      '2026-11-14T18:00',
      '2026-11-15T06:00',
      '2026-11-15T12:00',
      '2026-11-15T18:00',
    ],
    'temperature_2m': temps,
    'apparent_temperature': [for (final t in temps) t - 6],
    'precipitation': precip,
    'precipitation_probability': [10, 80, 20, 0, 5, 0],
    'wind_speed_10m': [20, 35, 25, 10, 12, 8],
    'wind_gusts_10m': [40, 70, 45, 20, 25, 15],
    'freezing_level_height': freezing,
    'weather_code': [3, 73, 3, 0, 1, 0],
  },
  'daily': {
    'time': ['2026-11-14', '2026-11-15'],
    'weather_code': [95, 0],
    'temperature_2m_max': [-4.5, 3.2],
    'temperature_2m_min': [-8.1, -2.0],
    'precipitation_sum': [0.4, 0],
    'precipitation_probability_max': [80, 5],
    'wind_speed_10m_max': [35, 12],
    'wind_gusts_10m_max': [70, 25],
    'uv_index_max': [8.5, null],
    'sunrise': ['2026-11-14T06:40', '2026-11-15T06:41'],
    'sunset': ['2026-11-14T17:55', null],
  },
};

const _summit = WeatherPoint(
  label: 'Cumbre',
  lat: 19.18,
  lng: -98.64,
  elevation: 5100,
);

void main() {
  test('lee días y horas de Open-Meteo', () {
    final f = parseForecast(_summit, _response());
    expect(f.days.length, 2);
    expect(f.hours.length, 6);
    final d = f.dayOf(DateTime(2026, 11, 14))!;
    expect(d.max, -4.5);
    expect(d.gustMax, 70);
    expect(d.uvMax, 8.5);
    expect(d.sunrise, DateTime(2026, 11, 14, 6, 40));
    expect(d.freezingLevelMin, 4800);
    expect(isStorm(d.code), isTrue);
    expect(weatherLabel(d.code), 'Tormenta eléctrica');
    expect(f.hoursOf(DateTime(2026, 11, 14)).length, 3);
    // Valores nulos no rompen la lectura
    expect(f.days.last.uvMax, isNull);
    expect(f.days.last.sunset, isNull);
  });

  test('la nieve se decide con la altitud del punto, no con la del modelo', () {
    final f = parseForecast(_summit, _response());
    expect(f.days.first.snowLikely, isTrue); // precipita a −7 °C
    expect(f.days.last.snowLikely, isFalse); // no precipita

    // A 3,500 m, con 4 °C y el nivel de congelación en 4,800 m, la misma precipitación es lluvia
    final low = parseForecast(
      const WeatherPoint(label: 'Salida', lat: 19, lng: -98, elevation: 3500),
      _response(temps: const [3, 4, 3, 5, 6, 7]),
    );
    expect(low.days.first.snowLikely, isFalse);
  });

  test('sin altitud propia se usa la de Open-Meteo', () {
    final f = parseForecast(
      const WeatherPoint(label: 'Zona', lat: 1, lng: 2),
      _response(elevation: 4321),
    );
    expect(f.point.elevation, 4321);
  });

  group('puntos de consulta', () {
    TrailRoute route(List<double> elevations) => TrailRoute(
      id: 'r',
      name: 'r',
      summary: '',
      coordinates: [
        for (var i = 0; i < elevations.length; i++)
          LngLat(-98.6 + i * 0.01, 19),
      ],
      distances: [for (var i = 0; i < elevations.length; i++) i * 1000.0],
      elevations: elevations,
      gain: 0,
      source: '',
    );
    Future<double?> none(double lng, double lat) async => null;

    test('salida y punto más alto si hay buen desnivel', () async {
      final p = await weatherPointsFor(
        route: route([3900, 4500, 5200, 4800]),
        elevation: none,
      );
      expect(p.map((x) => x.label), ['Salida', 'Punto más alto']);
      expect(p[1].elevation, 5200);
      expect(p[1].lng, closeTo(-98.58, 1e-9));
    });

    test('solo la salida si la ruta es casi plana', () async {
      final p = await weatherPointsFor(
        route: route([3900, 4000, 3950]),
        elevation: none,
      );
      expect(p.single.label, 'Salida');
    });

    test('sin ruta, el centro de la zona con su altitud', () async {
      final p = await weatherPointsFor(
        bounds: BBox(-70, -34, -69, -33),
        elevation: (lng, lat) async => 3000,
      );
      expect(p.single.lat, -33.5);
      expect(p.single.elevation, 3000);
    });
  });

  test('consulta, guarda y se lee sin conexión; sin red avisa', () async {
    final dir = Directory.systemTemp.createTempSync('cresta_weather');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = JsonStore(File('${dir.path}/weather.json'));
    final asked = <Uri>[];
    final ok = MockClient((req) async {
      asked.add(req.url);
      return http.Response(jsonEncode(_response()), 200);
    });
    final service = WeatherService(client: ok, file: file);
    await service.load();
    final snap = await service.refresh('exp', [_summit]);
    expect(snap.points.single.days.length, 2);
    expect(asked.single.queryParameters['elevation'], '5100');
    expect(asked.single.queryParameters['forecast_days'], '16');

    final offline = WeatherService(
      client: MockClient((_) async => throw const SocketException('sin red')),
      file: file,
    );
    await offline.load();
    expect(offline.forExpedition('exp')!.points.single.point.label, 'Cumbre');
    expect(
      () => offline.refresh('exp', [_summit]),
      throwsA(predicate((e) => '$e'.contains('Sin conexión'))),
    );
  });
}
