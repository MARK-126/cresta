import 'dart:math' as math;

import 'emergency_profile.dart';

/// Coordenadas en grados, minutos y segundos: 19°10'42.3" N 98°38'24.1" O.
String formatDms(double lat, double lng) {
  String part(double v, String pos, String neg) {
    final a = v.abs();
    final d = a.floor();
    final mFull = (a - d) * 60;
    var m = mFull.floor();
    var s = (mFull - m) * 60;
    var deg = d;
    // 59.95" se redondea a 60.0": se pasa al minuto siguiente
    if (double.parse(s.toStringAsFixed(1)) >= 60) {
      s = 0;
      m++;
      if (m == 60) {
        m = 0;
        deg++;
      }
    }
    return '$deg°${m.toString().padLeft(2, '0')}\'${s.toStringAsFixed(1).padLeft(4, '0')}" ${v >= 0 ? pos : neg}';
  }

  // "O" (oeste) en español; los rescatistas lo entienden igual que la W
  return '${part(lat, 'N', 'S')}  ${part(lng, 'E', 'O')}';
}

/// Coordenadas decimales con 5 decimales (≈ 1 m): 19.17842, -98.64003.
String formatDecimal(double lat, double lng) =>
    '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

/// Posición UTM (WGS84), el formato de las cartas topográficas y de muchos rescatistas.
class Utm {
  const Utm(this.zone, this.band, this.easting, this.northing);
  final int zone;
  final String band;
  final double easting;
  final double northing;

  /// "14Q 541234 2119876"
  @override
  String toString() =>
      '$zone$band ${easting.round().toString().padLeft(6, '0')} ${northing.round().toString().padLeft(7, '0')}';
}

/// Conversión de latitud/longitud a UTM (fórmulas de Krüger, error < 1 m).
Utm toUtm(double lat, double lng) {
  const a = 6378137.0, f = 1 / 298.257223563, k0 = 0.9996;
  final zone = ((lng + 180) / 6).floor() % 60 + 1;
  final lon0 = (zone - 1) * 6 - 180 + 3;
  const bands = 'CDEFGHJKLMNPQRSTUVWX';
  final band =
      bands[((lat.clamp(-80.0, 83.999) + 80) / 8).floor().clamp(0, 19)];

  final e2 = f * (2 - f);
  final ep2 = e2 / (1 - e2);
  final phi = lat * math.pi / 180;
  final dl = (lng - lon0) * math.pi / 180;
  final n = a / math.sqrt(1 - e2 * math.pow(math.sin(phi), 2));
  final t = math.pow(math.tan(phi), 2).toDouble();
  final c = ep2 * math.pow(math.cos(phi), 2);
  final aa = math.cos(phi) * dl;
  final m =
      a *
      ((1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * math.pow(e2, 3) / 256) * phi -
          (3 * e2 / 8 + 3 * e2 * e2 / 32 + 45 * math.pow(e2, 3) / 1024) *
              math.sin(2 * phi) +
          (15 * e2 * e2 / 256 + 45 * math.pow(e2, 3) / 1024) *
              math.sin(4 * phi) -
          (35 * math.pow(e2, 3) / 3072) * math.sin(6 * phi));

  final easting =
      k0 *
          n *
          (aa +
              (1 - t + c) * math.pow(aa, 3) / 6 +
              (5 - 18 * t + t * t + 72 * c - 58 * ep2) *
                  math.pow(aa, 5) /
                  120) +
      500000;
  var northing =
      k0 *
      (m +
          n *
              math.tan(phi) *
              (aa * aa / 2 +
                  (5 - t + 9 * c + 4 * c * c) * math.pow(aa, 4) / 24 +
                  (61 - 58 * t + t * t + 600 * c - 330 * ep2) *
                      math.pow(aa, 6) /
                      720));
  if (lat < 0) northing += 10000000; // hemisferio sur
  return Utm(zone, band, easting, northing);
}

/// Texto del SMS de auxilio. Corto: un SMS de más de 160 caracteres se parte y, con poca
/// señal, cada parte es otra oportunidad de que no llegue.
String sosMessage({
  required double lat,
  required double lng,
  double? altitude,
  double? accuracy,
  DateTime? at,
  EmergencyProfile? profile,
  String? expedition,
}) {
  final who = (profile?.name.isNotEmpty ?? false) ? profile!.name : 'Necesito';
  final b = StringBuffer(
    who == 'Necesito' ? 'SOS. Necesito ayuda. ' : 'SOS. $who necesita ayuda. ',
  )..write('Ubicación: ${formatDecimal(lat, lng)}');
  if (altitude != null) b.write(', ${altitude.round()} m');
  if (accuracy != null) b.write(' (±${accuracy.round()} m)');
  if (at != null) {
    b.write(
      ' a las ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
    );
  }
  b.write(
    '. https://maps.google.com/?q=${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}',
  );
  if (expedition != null && expedition.isNotEmpty) {
    b.write(' Exp.: $expedition.');
  }
  if (profile != null && profile.bloodType.isNotEmpty) {
    b.write(' Sangre ${profile.bloodType}.');
  }
  if (profile != null && profile.allergies.isNotEmpty) {
    b.write(' Alergias: ${profile.allergies}.');
  }
  return b.toString();
}
