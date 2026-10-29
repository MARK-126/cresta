import 'dart:math' as math;

/// Cuánta luz hace falta después de la hora límite para bajar sin linterna.
const descentMargin = Duration(hours: 2);

const _j2000 = 2451545.0;

double _rad(double deg) => deg * math.pi / 180;

/// Amanecer, atardecer y crepúsculo civil de un día en un lugar, calculados en el teléfono
/// (ecuación de salida del sol, con error de un par de minutos). Las horas son [DateTime] locales
/// del teléfono. No cuentan la altitud del lugar ni la sombra de las montañas.
class SunTimes {
  const SunTimes({
    this.sunrise,
    this.sunset,
    this.dawn,
    this.dusk,
    this.polarDay = false,
    this.polarNight = false,
  });

  final DateTime? sunrise;
  final DateTime? sunset;

  /// Inicio y fin del crepúsculo civil (sol a 6° bajo el horizonte): hay luz para ver sin linterna.
  final DateTime? dawn;
  final DateTime? dusk;

  /// El sol no se pone (día polar) o no sale (noche polar) ese día.
  final bool polarDay;
  final bool polarNight;

  /// Horas entre el amanecer y el atardecer.
  Duration? get daylight =>
      sunrise != null && sunset != null ? sunset!.difference(sunrise!) : null;
}

class _Solar {
  _Solar(
    this.transit,
    this.halfDay, {
    this.polarDay = false,
    this.polarNight = false,
  });
  final double transit;

  /// Mitad del día solar, en días (null si el sol no cruza esa altura).
  final double? halfDay;
  final bool polarDay, polarNight;
}

_Solar _solar(int n, double lat, double lng, double altitudeDeg) {
  final jStar = n - lng / 360;
  final m = _rad((357.5291 + 0.98560028 * jStar) % 360);
  final c =
      1.9148 * math.sin(m) +
      0.0200 * math.sin(2 * m) +
      0.0003 * math.sin(3 * m);
  final lambda = _rad((_deg(m) + c + 180 + 102.9372) % 360);
  final transit =
      _j2000 + jStar + 0.0053 * math.sin(m) - 0.0069 * math.sin(2 * lambda);
  final sinDec = math.sin(lambda) * math.sin(_rad(23.4397));
  final cosDec = math.sqrt(1 - sinDec * sinDec);
  final cosW =
      (math.sin(_rad(altitudeDeg)) - math.sin(_rad(lat)) * sinDec) /
      (math.cos(_rad(lat)) * cosDec);
  if (cosW > 1) return _Solar(transit, null, polarNight: true);
  if (cosW < -1) return _Solar(transit, null, polarDay: true);
  return _Solar(transit, _deg(math.acos(cosW)) / 360);
}

double _deg(double rad) => rad * 180 / math.pi;

DateTime _local(double julian) => DateTime.fromMillisecondsSinceEpoch(
  ((julian - 2440587.5) * 86400000).round(),
  isUtc: true,
).toLocal();

/// Las horas del sol del día de [date] (solo cuenta año, mes y día: el día en ese lugar).
SunTimes sunTimes({
  required DateTime date,
  required double lat,
  required double lng,
}) {
  // Día juliano de la medianoche UTC de la fecha; el día solar del lugar va desplazado lng/360
  final jd00 =
      DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch /
          86400000 +
      2440587.5;
  final lo = jd00 - lng / 360, hi = lo + 1;
  final n0 = (jd00 + 0.5 - _j2000).round();
  // La culminación de ese día en el lugar cae en uno de tres días julianos seguidos
  var n = n0;
  for (final k in [n0 - 1, n0, n0 + 1]) {
    final t = _solar(k, lat, lng, -0.833).transit;
    if (t >= lo && t < hi) {
      n = k;
      break;
    }
  }
  final sun = _solar(n, lat, lng, -0.833);
  final twilight = _solar(n, lat, lng, -6);
  final h = sun.halfDay, t = twilight.halfDay;
  return SunTimes(
    sunrise: h == null ? null : _local(sun.transit - h),
    sunset: h == null ? null : _local(sun.transit + h),
    dawn: t == null ? null : _local(twilight.transit - t),
    dusk: t == null ? null : _local(twilight.transit + t),
    polarDay: sun.polarDay,
    polarNight: sun.polarNight,
  );
}

/// La hora límite más tarde que aún deja [descentMargin] de luz para bajar (atardecer menos el
/// margen); null si ese día no hay atardecer.
DateTime? lastSafeTurnaround(SunTimes s) => s.sunset?.subtract(descentMargin);

/// Los minutos del día, bajados a un múltiplo de 5 (así lo fija el reloj de la hora límite).
int roundDownTo5(int minutes) => minutes - minutes % 5;
