import 'dart:math' as math;

/// Un lugar donde se consulta el clima: la salida, la cumbre o el centro de la zona.
class WeatherPoint {
  const WeatherPoint({
    required this.label,
    required this.lat,
    required this.lng,
    this.elevation,
  });

  factory WeatherPoint.fromJson(Map<String, dynamic> j) => WeatherPoint(
    label: j['label'] as String,
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    elevation: (j['elevation'] as num?)?.toDouble(),
  );

  final String label;
  final double lat;
  final double lng;

  /// Metros: Open-Meteo ajusta la temperatura a esta altitud (no a la de su celda de 1–11 km).
  /// Null si no hay relieve descargado: entonces se usa la que reporta Open-Meteo.
  final double? elevation;

  WeatherPoint withElevation(double e) =>
      WeatherPoint(label: label, lat: lat, lng: lng, elevation: e);

  Map<String, dynamic> toJson() => {
    'label': label,
    'lat': lat,
    'lng': lng,
    'elevation': elevation,
  };
}

/// Una hora del pronóstico en un punto.
class HourWeather {
  const HourWeather({
    required this.time,
    required this.temperature,
    required this.feelsLike,
    required this.precipitation,
    required this.precipitationChance,
    required this.wind,
    required this.gusts,
    required this.freezingLevel,
    required this.code,
  });

  final DateTime time;
  final double temperature;
  final double feelsLike;
  final double precipitation;
  final int precipitationChance;
  final double wind;
  final double gusts;

  /// Altitud donde la temperatura cruza 0 °C (null si el modelo no la da).
  final double? freezingLevel;
  final int code;
}

/// Resumen de un día en un punto.
class DayWeather {
  const DayWeather({
    required this.date,
    required this.code,
    required this.max,
    required this.min,
    required this.precipitation,
    required this.precipitationChance,
    required this.windMax,
    required this.gustMax,
    required this.uvMax,
    required this.sunrise,
    required this.sunset,
    required this.freezingLevelMin,
    required this.snowLikely,
  });

  final DateTime date;
  final int code;
  final double max;
  final double min;
  final double precipitation;
  final int precipitationChance;
  final double windMax;
  final double gustMax;
  final double? uvMax;
  final DateTime? sunrise;
  final DateTime? sunset;

  /// El nivel de congelación más bajo del día.
  final double? freezingLevelMin;

  /// Si la precipitación del día caería como nieve en este punto. Lo calculamos nosotros:
  /// la nieve que entrega el modelo es la de su celda, no la de la altitud pedida.
  final bool snowLikely;
}

/// Pronóstico de un punto, ya leído de la respuesta de Open-Meteo.
class PointForecast {
  PointForecast({required this.point, required this.days, required this.hours});

  final WeatherPoint point;
  final List<DayWeather> days;
  final List<HourWeather> hours;

  DayWeather? dayOf(DateTime d) => days
      .where(
        (x) =>
            x.date.year == d.year &&
            x.date.month == d.month &&
            x.date.day == d.day,
      )
      .firstOrNull;

  List<HourWeather> hoursOf(DateTime d) => hours
      .where(
        (h) =>
            h.time.year == d.year &&
            h.time.month == d.month &&
            h.time.day == d.day,
      )
      .toList();
}

/// Variables que se piden a Open-Meteo (las mismas que lee [parseForecast]).
const hourlyVars =
    'temperature_2m,apparent_temperature,precipitation,precipitation_probability,'
    'wind_speed_10m,wind_gusts_10m,freezing_level_height,weather_code';
const dailyVars =
    'weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,'
    'precipitation_probability_max,wind_speed_10m_max,wind_gusts_10m_max,'
    'uv_index_max,sunrise,sunset';

/// Lee la respuesta JSON de Open-Meteo de un punto.
PointForecast parseForecast(WeatherPoint requested, Map<String, dynamic> json) {
  final point = requested.elevation != null || json['elevation'] is! num
      ? requested
      : requested.withElevation((json['elevation'] as num).toDouble());
  final elevation = point.elevation ?? 0;
  final h = json['hourly'] as Map<String, dynamic>;
  final d = json['daily'] as Map<String, dynamic>;
  List<num?> nums(Map<String, dynamic> m, String k) =>
      (m[k] as List? ?? const []).cast<num?>();
  double at(List<num?> l, int i, [double fallback = 0]) =>
      i < l.length ? (l[i]?.toDouble() ?? fallback) : fallback;

  final hTime = (h['time'] as List).cast<String>();
  final temp = nums(h, 'temperature_2m');
  final feels = nums(h, 'apparent_temperature');
  final prec = nums(h, 'precipitation');
  final prob = nums(h, 'precipitation_probability');
  final wind = nums(h, 'wind_speed_10m');
  final gust = nums(h, 'wind_gusts_10m');
  final frz = nums(h, 'freezing_level_height');
  final hCode = nums(h, 'weather_code');
  final hours = [
    for (var i = 0; i < hTime.length; i++)
      HourWeather(
        time: DateTime.parse(hTime[i]),
        temperature: at(temp, i),
        feelsLike: at(feels, i, at(temp, i)),
        precipitation: at(prec, i),
        precipitationChance: at(prob, i).round(),
        wind: at(wind, i),
        gusts: at(gust, i),
        freezingLevel: i < frz.length ? frz[i]?.toDouble() : null,
        code: at(hCode, i).round(),
      ),
  ];

  final dTime = (d['time'] as List).cast<String>();
  DateTime? time(String k, int i) {
    final l = d[k] as List?;
    return l == null || i >= l.length || l[i] == null
        ? null
        : DateTime.tryParse(l[i] as String);
  }

  final days = <DayWeather>[];
  for (var i = 0; i < dTime.length; i++) {
    final date = DateTime.parse(dTime[i]);
    final dayHours = hours.where(
      (x) =>
          x.time.year == date.year &&
          x.time.month == date.month &&
          x.time.day == date.day,
    );
    final levels = dayHours.map((x) => x.freezingLevel).whereType<double>();
    // Nieve: alguna hora con precipitación y el punto a 0 °C o menos (o arriba del nivel de congelación)
    final snow = dayHours.any(
      (x) =>
          x.precipitation >= 0.1 &&
          (x.temperature <= 0.5 ||
              (x.freezingLevel != null && elevation >= x.freezingLevel!)),
    );
    days.add(
      DayWeather(
        date: date,
        code: at(nums(d, 'weather_code'), i).round(),
        max: at(nums(d, 'temperature_2m_max'), i),
        min: at(nums(d, 'temperature_2m_min'), i),
        precipitation: at(nums(d, 'precipitation_sum'), i),
        precipitationChance: at(
          nums(d, 'precipitation_probability_max'),
          i,
        ).round(),
        windMax: at(nums(d, 'wind_speed_10m_max'), i),
        gustMax: at(nums(d, 'wind_gusts_10m_max'), i),
        uvMax: i < nums(d, 'uv_index_max').length
            ? nums(d, 'uv_index_max')[i]?.toDouble()
            : null,
        sunrise: time('sunrise', i),
        sunset: time('sunset', i),
        freezingLevelMin: levels.isEmpty ? null : levels.reduce(math.min),
        snowLikely: snow,
      ),
    );
  }
  return PointForecast(point: point, days: days, hours: hours);
}

/// Descripción en español de un código WMO del tiempo.
String weatherLabel(int code) => switch (code) {
  0 => 'Despejado',
  1 => 'Mayormente despejado',
  2 => 'Parcialmente nublado',
  3 => 'Nublado',
  45 || 48 => 'Niebla',
  51 || 53 || 55 => 'Llovizna',
  56 || 57 => 'Llovizna helada',
  61 || 63 => 'Lluvia',
  65 => 'Lluvia fuerte',
  66 || 67 => 'Lluvia helada',
  71 || 73 => 'Nieve',
  75 => 'Nevada fuerte',
  77 => 'Granizo fino',
  80 || 81 => 'Chubascos',
  82 => 'Chubascos fuertes',
  85 || 86 => 'Chubascos de nieve',
  95 => 'Tormenta eléctrica',
  96 || 99 => 'Tormenta con granizo',
  _ => 'Sin dato',
};

/// Tormenta eléctrica: en la montaña, la razón principal para no salir o bajar ya.
bool isStorm(int code) => code >= 95;
