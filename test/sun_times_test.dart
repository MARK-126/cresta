import 'package:cresta/src/sun/sun_times.dart';
import 'package:flutter_test/flutter_test.dart';

/// Valores de referencia calculados con la biblioteca astral de Python, en la zona horaria de cada
/// lugar (así la fecha es la del día local).
void main() {
  void check(
    String name,
    double lat,
    double lng,
    DateTime date, {
    required String rise,
    required String set,
    required String dawn,
    required String dusk,
  }) {
    test(name, () {
      final s = sunTimes(date: date, lat: lat, lng: lng);
      void near(DateTime? got, String want, String what) {
        expect(got, isNotNull, reason: what);
        final diff = got!
            .toUtc()
            .difference(DateTime.parse(want))
            .inSeconds
            .abs();
        expect(diff, lessThanOrEqualTo(150), reason: '$what: $got vs $want');
      }

      near(s.sunrise, rise, 'amanecer');
      near(s.sunset, set, 'atardecer');
      near(s.dawn, dawn, 'alba');
      near(s.dusk, dusk, 'crepúsculo');
      expect(s.polarDay || s.polarNight, isFalse);
    });
  }

  check(
    'Ciudad de México, 28 oct 2026',
    19.4326,
    -99.1332,
    DateTime(2026, 10, 28),
    rise: '2026-10-28T12:35:50Z',
    set: '2026-10-29T00:04:25Z',
    dawn: '2026-10-28T12:12:55Z',
    dusk: '2026-10-29T00:27:20Z',
  );
  check(
    'Salida del Izta, 28 oct 2026',
    19.1789,
    -98.64,
    DateTime(2026, 10, 28),
    rise: '2026-10-28T12:33:36Z',
    set: '2026-10-29T00:02:43Z',
    dawn: '2026-10-28T12:10:43Z',
    dusk: '2026-10-29T00:25:35Z',
  );
  check(
    'Londres, solsticio de junio',
    51.5074,
    -0.1278,
    DateTime(2026, 6, 21),
    rise: '2026-06-21T03:43:27Z',
    set: '2026-06-21T20:21:12Z',
    dawn: '2026-06-21T02:54:45Z',
    dusk: '2026-06-21T21:09:54Z',
  );
  check(
    'Ecuador y Greenwich, equinoccio',
    0,
    0,
    DateTime(2026, 3, 20),
    rise: '2026-03-20T06:04:20Z',
    set: '2026-03-20T18:10:30Z',
    dawn: '2026-03-20T05:43:17Z',
    dusk: '2026-03-20T18:31:34Z',
  );
  check(
    'Mendoza, solsticio de diciembre',
    -32.8872,
    -68.8214,
    DateTime(2026, 12, 21),
    rise: '2026-12-21T09:23:54Z',
    set: '2026-12-21T23:43:00Z',
    dawn: '2026-12-21T08:54:39Z',
    dusk: '2026-12-22T00:12:15Z',
  );
  check(
    'Nueva York, solsticio de junio',
    40.7128,
    -74.006,
    DateTime(2026, 6, 21),
    rise: '2026-06-21T09:25:17Z',
    set: '2026-06-22T00:30:29Z',
    dawn: '2026-06-21T08:51:13Z',
    dusk: '2026-06-22T01:04:33Z',
  );
  check(
    'Tokio, 28 oct 2026 (al este de Greenwich)',
    35.6762,
    139.6503,
    DateTime(2026, 10, 28),
    rise: '2026-10-27T20:59:19Z',
    set: '2026-10-28T07:50:32Z',
    dawn: '2026-10-27T20:32:38Z',
    dusk: '2026-10-28T08:17:13Z',
  );

  test('en el polo: día polar en junio y noche polar en diciembre', () {
    final summer = sunTimes(date: DateTime(2026, 6, 21), lat: 80, lng: 0);
    expect(summer.polarDay, isTrue);
    expect(summer.sunrise, isNull);
    expect(summer.sunset, isNull);
    final winter = sunTimes(date: DateTime(2026, 12, 21), lat: 80, lng: 0);
    expect(winter.polarNight, isTrue);
    expect(winter.sunrise, isNull);
  });

  test('la hora límite sugerida deja 2 h de luz y se baja a múltiplo de 5', () {
    final s = sunTimes(date: DateTime(2026, 10, 28), lat: 19.1789, lng: -98.64);
    final last = lastSafeTurnaround(s)!;
    expect(s.sunset!.difference(last), descentMargin);
    expect(roundDownTo5(17 * 60 + 58), 17 * 60 + 55);
    expect(roundDownTo5(600), 600);
    expect(lastSafeTurnaround(const SunTimes(polarNight: true)), isNull);
  });

  test('la luz del día dura lo que va del amanecer al atardecer', () {
    final s = sunTimes(date: DateTime(2026, 3, 20), lat: 0, lng: 0);
    expect(s.daylight!.inMinutes, inInclusiveRange(724, 730));
  });
}
