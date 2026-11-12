import 'dart:math' as math;
import 'dart:typed_data';

/// Velocidad a pie (km/h) según la pendiente, de Tobler (1993): máxima (6 km/h) bajando
/// suave al 5 %, y cae rápido subiendo o bajando fuerte. [grade] = desnivel / distancia
/// (positivo subiendo).
double toblerKmh(double grade) => 6 * math.exp(-3.5 * (grade + 0.05).abs());

/// Máxima velocidad de Tobler, en m/s (para que la estimación del A* nunca se pase).
const toblerMaxMs = 6 / 3.6;

/// Fuera de sendero se camina a 3/5 de la velocidad en sendero (Tobler).
const offTrailFactor = 0.6;

/// Altitudes del relieve en una ventana de píxeles de un zoom (Web Mercator), sin
/// depender de Flutter para poder usarla en otro isolate. NaN donde no hay relieve.
class DemGrid {
  DemGrid({
    required this.zoom,
    required this.x0,
    required this.y0,
    required this.width,
    required this.height,
    required this.ele,
  }) : assert(ele.length == width * height);

  /// Zoom y primer píxel global (esquina noroeste) de la ventana.
  final int zoom, x0, y0;
  final int width, height;

  /// Metros, fila por fila desde el norte.
  final Float32List ele;

  double get _worldPx => 256.0 * (1 << zoom);

  /// Píxel continuo de la ventana (el centro del píxel c está en c + 0.5).
  (double, double) toPixel(double lng, double lat) {
    final r = lat.clamp(-85.0, 85.0) * math.pi / 180;
    final px = (lng + 180) / 360 * _worldPx;
    final py =
        (1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2 * _worldPx;
    return (px - x0, py - y0);
  }

  /// Longitud y latitud de un píxel continuo de la ventana.
  (double, double) toLngLat(double x, double y) {
    final lng = (x + x0) / _worldPx * 360 - 180;
    final t = math.pi * (1 - 2 * (y + y0) / _worldPx);
    final lat = math.atan((math.exp(t) - math.exp(-t)) / 2) * 180 / math.pi;
    return (lng, lat);
  }

  /// Altitud del píxel (c, r), NaN fuera de la ventana o sin relieve.
  double elevation(int c, int r) => c < 0 || r < 0 || c >= width || r >= height
      ? double.nan
      : ele[r * width + c];

  /// Altitud interpolada en un punto, o null sin relieve.
  double? at(double lng, double lat) {
    final (x, y) = toPixel(lng, lat);
    final fx = x - .5, fy = y - .5;
    final c = fx.floor(), r = fy.floor();
    final e00 = elevation(c, r), e10 = elevation(c + 1, r);
    final e01 = elevation(c, r + 1), e11 = elevation(c + 1, r + 1);
    if ([e00, e10, e01, e11].any((e) => e.isNaN)) {
      final near = elevation(x.floor(), y.floor());
      return near.isNaN ? null : near;
    }
    final dx = fx - c, dy = fy - r;
    final top = e00 + (e10 - e00) * dx, bottom = e01 + (e11 - e01) * dx;
    return top + (bottom - top) * dy;
  }

  /// Metros que mide un píxel a la latitud de la fila [r].
  double metersPerPixel(int r) {
    final (_, lat) = toLngLat(0, r + .5);
    return 40075016.686 * math.cos(lat * math.pi / 180) / _worldPx;
  }
}
