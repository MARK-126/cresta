import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../tracking/track.dart';

/// Fondo de la imagen del recorrido.
enum ImageBackground {
  map('Mapa'),
  photo('Foto'),
  color('Color'),

  /// Solo la línea y las cifras: para pegarla como sticker en una historia.
  transparent('Transparente');

  const ImageBackground(this.label);
  final String label;
}

enum ImageAspect {
  story('Historia', 9 / 16),
  square('Cuadrado', 1),
  post('Publicación', 4 / 5);

  const ImageAspect(this.label, this.ratio);
  final String label;

  /// Ancho / alto.
  final double ratio;

  /// Tamaño del archivo: 1,080 px de ancho, como piden Instagram y WhatsApp.
  Size get pixels => Size(1080, (1080 / ratio).roundToDouble());
}

enum ImageStat {
  distance('Distancia'),
  gain('Desnivel'),
  time('Tiempo'),
  maxAltitude('Altitud máx.'),
  date('Fecha');

  const ImageStat(this.label);
  final String label;

  /// Las que van abajo como cifra (la fecha va en el costado).
  bool get isFigure => this != date;
}

enum ImageFormat { png, jpg }

/// Colores de fondo liso, con el color de las letras que se lee encima.
class ImageSwatch {
  const ImageSwatch(this.name, this.color, {this.darkText = false});
  final String name;
  final Color color;
  final bool darkText;
}

const pizarraSwatch = ImageSwatch('Pizarra', Color(0xFF0E1416));

const imageSwatches = [
  pizarraSwatch,
  ImageSwatch('Bosque', Color(0xFF1F3B2D)),
  ImageSwatch('Terracota', Color(0xFFB4543C)),
  ImageSwatch('Arena', Color(0xFFEDE6D6), darkText: true),
];

/// Lo que se dibuja: título, fecha, cifras, la traza (ya recortada) y su perfil.
class TrackImageData {
  const TrackImageData({
    required this.date,
    required this.figures,
    required this.points,
    this.from,
    this.to,
  });

  /// Lugar o calle junto al inicio y al fin de lo que se ve ("desde dónde hasta dónde").
  final String? from;
  final String? to;
  final String date;

  /// (etiqueta, valor) de cada cifra elegida, en orden.
  final List<(String, String)> figures;
  final List<TrackPoint> points;
}

/// Dibuja la imagen del recorrido en cualquier tamaño (las medidas son relativas a
/// 1,080 px de ancho): la misma pintura sirve para la vista previa y para el archivo.
class TrackImagePainter extends CustomPainter {
  const TrackImagePainter({
    required this.data,
    required this.background,
    required this.showDate,
    required this.showProfile,
    this.swatch = pizarraSwatch,
    this.backgroundImage,
    this.paintBackground = true,
    this.dim = 0,
  });

  final TrackImageData data;
  final ImageBackground background;
  final bool showDate;
  final bool showProfile;
  final ImageSwatch swatch;

  /// La foto o la captura del mapa.
  final ui.Image? backgroundImage;

  /// En la vista previa con mapa, el mapa vivo está debajo: no se pinta fondo ni traza.
  final bool paintBackground;

  /// Cuánto se oscurece la foto de fondo (0–1), para que la traza y las cifras resalten.
  final double dim;

  static const coral = Color(0xFFFFA089);
  static const cyan = Color(0xFF46EAE5);

  bool get _darkText => background == ImageBackground.color && swatch.darkText;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, u = w / 1080;
    final pad = 72 * u;
    final text = _darkText ? const Color(0xFF14201F) : const Color(0xFFFFFFFF);
    final muted = text.withValues(alpha: .72);

    // Fondo
    if (paintBackground) {
      switch (background) {
        case ImageBackground.color:
          canvas.drawRect(Offset.zero & size, Paint()..color = swatch.color);
        case ImageBackground.photo || ImageBackground.map:
          final img = backgroundImage;
          if (img != null) _cover(canvas, img, size);
          if (background == ImageBackground.photo && dim > 0) {
            canvas.drawRect(
              Offset.zero & size,
              Paint()..color = const Color(0xFF080F11).withValues(alpha: dim),
            );
          }
        case ImageBackground.transparent:
          break;
      }
    }
    // Sombra arriba y abajo para que las letras se lean sobre una foto o el mapa
    if (background == ImageBackground.photo ||
        background == ImageBackground.map) {
      _scrim(canvas, Rect.fromLTWH(0, 0, w, h * .26), top: true);
      _scrim(canvas, Rect.fromLTWH(0, h * .52, w, h * .48), top: false);
    }

    // Sin título arriba (al usuario no le gustó "Recorrido 3 · vie 13 nov 2026"): la traza
    // empieza casi desde el borde y la fecha va vertical en el costado izquierdo
    final routeTop = pad + 8 * u;
    final dated = showDate && data.date.isNotEmpty;

    // Abajo: marca, cifras y perfil (de abajo hacia arriba)
    var bottom = h - pad;
    _text(
      canvas,
      'CRESTA',
      Offset(w - pad - 200 * u, bottom - 30 * u),
      200 * u,
      size: 26 * u,
      color: cyan,
      weight: FontWeight.w800,
      spacing: 6 * u,
      align: TextAlign.right,
    );
    if (background == ImageBackground.map) {
      _text(
        canvas,
        '© OpenStreetMap · OpenMapTiles',
        Offset(pad, bottom - 24 * u),
        600 * u,
        size: 18 * u,
        color: muted,
      );
    }
    bottom -= 30 * u + 36 * u;
    final figures = data.figures;
    if (figures.isNotEmpty) {
      final colW = (w - 2 * pad) / figures.length;
      final valueSize = (figures.length > 3 ? 50 : 58) * u;
      final top = bottom - valueSize * 1.2 - 34 * u;
      for (var i = 0; i < figures.length; i++) {
        final x = pad + i * colW;
        _text(
          canvas,
          figures[i].$1.toUpperCase(),
          Offset(x, top),
          colW - 12 * u,
          size: 22 * u,
          color: muted,
          weight: FontWeight.w700,
          spacing: 2.5 * u,
        );
        _text(
          canvas,
          figures[i].$2,
          Offset(x, top + 34 * u),
          colW - 8 * u,
          size: valueSize,
          color: text,
          weight: FontWeight.w800,
        );
      }
      bottom = top - 40 * u;
    }
    final alts = [
      for (final p in data.points)
        if (p.altitude != null) p.altitude!,
    ];
    if (showProfile && alts.length > 1) {
      final r = Rect.fromLTRB(pad, bottom - 130 * u, w - pad, bottom);
      _profile(canvas, r, alts, u);
      bottom = r.top - 40 * u;
    }

    // La traza en lo que queda (con el mapa de fondo ya viene dibujada en el mapa)
    if (background != ImageBackground.map && data.points.length > 1) {
      _route(
        canvas,
        Rect.fromLTRB(
          pad + (dated ? 56 * u : 0),
          routeTop,
          w - pad,
          math.max(routeTop + 1, bottom),
        ),
        u,
      );
    }
    if (dated) {
      // Girada 90°, se lee de abajo hacia arriba, centrada en el alto de la traza
      final cy = (routeTop + bottom) / 2;
      canvas
        ..save()
        ..translate(pad + 14 * u, cy)
        ..rotate(-math.pi / 2);
      final width = math.max(1.0, bottom - routeTop);
      _text(
        canvas,
        data.date.toUpperCase(),
        Offset(-width / 2, -16 * u),
        width,
        size: 26 * u,
        color: muted,
        weight: FontWeight.w700,
        spacing: 8 * u,
        align: TextAlign.center,
      );
      canvas.restore();
    }
  }

  void _cover(Canvas canvas, ui.Image img, Size size) {
    final src = Size(img.width.toDouble(), img.height.toDouble());
    final fit = applyBoxFit(BoxFit.cover, src, size);
    final from = Alignment.center.inscribe(fit.source, Offset.zero & src);
    canvas.drawImageRect(
      img,
      from,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  void _scrim(Canvas canvas, Rect r, {required bool top}) {
    final dark = const Color(0xFF080F11);
    canvas.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.linear(
          top ? r.topCenter : r.bottomCenter,
          top ? r.bottomCenter : r.topCenter,
          [dark.withValues(alpha: top ? .55 : .82), dark.withValues(alpha: 0)],
        ),
    );
  }

  /// Escribe [s] y devuelve el alto que ocupó.
  double _text(
    Canvas canvas,
    String s,
    Offset at,
    double width, {
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w500,
    double spacing = 0,
    int maxLines = 1,
    TextAlign align = TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: size,
          color: color,
          fontWeight: weight,
          letterSpacing: spacing,
          height: 1.15,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: math.max(1, width));
    final dx = switch (align) {
      TextAlign.right => width - tp.width,
      TextAlign.center => (width - tp.width) / 2,
      _ => 0.0,
    };
    tp.paint(canvas, at + Offset(dx, 0));
    return tp.height;
  }

  void _profile(Canvas canvas, Rect r, List<double> alts, double u) {
    var lo = alts.reduce(math.min), hi = alts.reduce(math.max);
    // Un recorrido plano no debe verse como una montaña: al menos 50 m de escala
    if (hi - lo < 50) {
      final mid = (hi + lo) / 2;
      lo = mid - 25;
      hi = mid + 25;
    }
    Offset at(int i) => Offset(
      r.left + r.width * i / (alts.length - 1),
      r.bottom - r.height * (alts[i] - lo) / (hi - lo),
    );
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < alts.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final area = Path.from(line)
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.left, r.bottom)
      ..close();
    canvas.drawPath(area, Paint()..color = coral.withValues(alpha: .28));
    canvas.drawPath(
      line,
      Paint()
        ..color = coral
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * u
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// La traza ajustada al rectángulo, con la misma escala en los dos ejes y girada para
  /// ocupar todo el alto (pedido del usuario: siempre en vertical): el inicio abajo y el fin
  /// arriba; si es una vuelta (empieza y termina casi en el mismo lugar), a lo largo de su
  /// eje más largo, con el inicio abajo. Junto a cada extremo, el lugar de referencia.
  void _route(Canvas canvas, Rect r, double u) {
    final pts = data.points;
    final k = math.cos(pts.first.lat * math.pi / 180);
    // En metros (x al este, y al norte)
    final xy = [
      for (final p in pts) Offset(p.lng * k * 111320, p.lat * 111320),
    ];
    final theta = verticalRotation(xy);
    final c = math.cos(theta), sn = math.sin(theta);
    final rot = [
      for (final o in xy) Offset(o.dx * c - o.dy * sn, o.dx * sn + o.dy * c),
    ];
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final o in rot) {
      minX = math.min(minX, o.dx);
      maxX = math.max(maxX, o.dx);
      minY = math.min(minY, o.dy);
      maxY = math.max(maxY, o.dy);
    }
    // Margen para los nombres de los extremos (arriba y abajo)
    final labels = data.from != null || data.to != null;
    final inner = Rect.fromLTRB(
      r.left + 24 * u,
      r.top + (labels ? 100 : 24) * u,
      r.right - 24 * u,
      math.max(
        r.top + (labels ? 101 : 25) * u,
        r.bottom - (labels ? 100 : 24) * u,
      ),
    );
    final spanX = math.max(maxX - minX, 1e-6);
    final spanY = math.max(maxY - minY, 1e-6);
    final s = math.min(inner.width / spanX, inner.height / spanY);
    final ox = inner.center.dx - (minX + maxX) / 2 * s;
    final oy = inner.center.dy + (minY + maxY) / 2 * s;
    Offset at(int i) => Offset(ox + rot[i].dx * s, oy - rot[i].dy * s);

    final path = Path();
    int? seg;
    for (var i = 0; i < pts.length; i++) {
      final o = at(i);
      if (pts[i].segment != seg) {
        path.moveTo(o.dx, o.dy);
        seg = pts[i].segment;
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    Paint stroke(Color c, double width) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (background != ImageBackground.transparent) {
      canvas.drawPath(path, stroke(const Color(0xB3080F11), 18 * u));
    }
    canvas.drawPath(path, stroke(coral, 9 * u));
    void dot(Offset o, Color c) {
      canvas.drawCircle(o, 13 * u, Paint()..color = c);
      canvas.drawCircle(o, 13 * u, stroke(const Color(0xFFFFFFFF), 4 * u));
    }

    final start = at(0), end = at(pts.length - 1);
    dot(end, const Color(0xFFD64545));
    dot(start, const Color(0xFF2F9E5F));
    _endLabel(canvas, r, end, 'HASTA', data.to, above: true, u: u);
    _endLabel(canvas, r, start, 'DESDE', data.from, above: false, u: u);
  }

  /// "DESDE" / "HASTA" y el lugar, arriba del fin y abajo del inicio, sin salirse.
  void _endLabel(
    Canvas canvas,
    Rect r,
    Offset at,
    String caption,
    String? name, {
    required bool above,
    required double u,
  }) {
    if (name == null || name.isEmpty) return;
    final text = _darkText ? const Color(0xFF14201F) : const Color(0xFFFFFFFF);
    final width = 520 * u;
    final left = (at.dx - width / 2).clamp(r.left, r.right - width);
    final top = above ? at.dy - 30 * u - 70 * u : at.dy + 28 * u;
    final h = _text(
      canvas,
      caption,
      Offset(left, top),
      width,
      size: 20 * u,
      color: text.withValues(alpha: .7),
      weight: FontWeight.w700,
      spacing: 3 * u,
      align: TextAlign.center,
    );
    _text(
      canvas,
      name,
      Offset(left, top + h + 2 * u),
      width,
      size: 32 * u,
      color: text,
      weight: FontWeight.w800,
      align: TextAlign.center,
    );
  }

  @override
  bool shouldRepaint(TrackImagePainter old) =>
      old.data != data ||
      old.background != background ||
      old.showDate != showDate ||
      old.showProfile != showProfile ||
      old.swatch != swatch ||
      old.backgroundImage != backgroundImage ||
      old.paintBackground != paintBackground ||
      old.dim != dim;
}

/// Giro (radianes) que deja la traza vertical: el inicio abajo y el fin arriba; en una
/// vuelta, su eje más largo vertical y el inicio abajo. [xy] en metros (y al norte).
double verticalRotation(List<Offset> xy) {
  if (xy.length < 2) return 0;
  final a = xy.first, b = xy.last;
  var minX = double.infinity, maxX = -double.infinity;
  var minY = double.infinity, maxY = -double.infinity;
  var cx = 0.0, cy = 0.0;
  for (final o in xy) {
    minX = math.min(minX, o.dx);
    maxX = math.max(maxX, o.dx);
    minY = math.min(minY, o.dy);
    maxY = math.max(maxY, o.dy);
    cx += o.dx;
    cy += o.dy;
  }
  cx /= xy.length;
  cy /= xy.length;
  final diag = math.sqrt(math.pow(maxX - minX, 2) + math.pow(maxY - minY, 2));
  final chord = b - a;
  double axis;
  if (chord.distance > diag * .3) {
    axis = math.atan2(chord.dy, chord.dx);
  } else {
    // Eje principal (componentes principales) de los puntos
    var sxx = 0.0, syy = 0.0, sxy = 0.0;
    for (final o in xy) {
      final dx = o.dx - cx, dy = o.dy - cy;
      sxx += dx * dx;
      syy += dy * dy;
      sxy += dx * dy;
    }
    axis = .5 * math.atan2(2 * sxy, sxx - syy);
  }
  var theta = math.pi / 2 - axis;
  // Que el inicio quede abajo (de su centro) y el fin arriba
  double yAfter(Offset o, double t) =>
      (o.dx - cx) * math.sin(t) + (o.dy - cy) * math.cos(t);
  final startLow = chord.distance > diag * .3
      ? yAfter(a, theta) < yAfter(b, theta)
      : yAfter(a, theta) <= 0;
  if (!startLow) theta += math.pi;
  return theta;
}

/// Pinta la imagen completa a su tamaño final y la codifica (PNG o JPG).
Future<ui.Image> renderTrackImage(TrackImagePainter painter, Size size) {
  final rec = ui.PictureRecorder();
  painter.paint(Canvas(rec), size);
  return rec.endRecording().toImage(size.width.round(), size.height.round());
}
