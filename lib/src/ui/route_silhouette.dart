import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../share/track_image.dart' show verticalRotation;
import '../tracking/track.dart';
import 'format.dart';

/// Nombre del recorrido para mostrar: sin la fecha que el nombre automático ya trae
/// ("Recorrido 3 · vie 13 nov 2026" → "Recorrido 3"), porque la fecha sale aparte.
String trackTitle(Track t) {
  final suffix = ' · ${fmtDate(t.startedAt)}';
  return t.name.endsWith(suffix)
      ? t.name.substring(0, t.name.length - suffix.length)
      : t.name;
}

/// La forma del recorrido, sin mapa, vertical (inicio abajo, fin arriba): el "producto" al
/// centro de la pantalla, como en las referencias del usuario. Coordenadas como (lng, lat).
class RouteSilhouette extends StatelessWidget {
  const RouteSilhouette({
    super.key,
    required this.points,
    this.color = const Color(0xFFFFA089),
    this.strokeWidth = 3,
    this.segments,
  });

  final List<(double, double)> points;

  /// Tramo de cada punto (no se unen los saltos de una pausa); null = un solo tramo.
  final List<int>? segments;
  final Color color;
  final double strokeWidth;

  factory RouteSilhouette.ofTrack(
    List<TrackPoint> pts, {
    Key? key,
    double strokeWidth = 3,
  }) => RouteSilhouette(
    key: key,
    points: [for (final p in pts) (p.lng, p.lat)],
    segments: [for (final p in pts) p.segment],
    strokeWidth: strokeWidth,
  );

  @override
  Widget build(BuildContext context) => points.length < 2
      ? const SizedBox.shrink()
      : CustomPaint(
          painter: _SilhouettePainter(points, segments, color, strokeWidth),
        );
}

class _SilhouettePainter extends CustomPainter {
  _SilhouettePainter(this.points, this.segments, this.color, this.width);
  final List<(double, double)> points;
  final List<int>? segments;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final k = math.cos(points.first.$2 * math.pi / 180);
    final xy = [
      for (final p in points) Offset(p.$1 * k * 111320, p.$2 * 111320),
    ];
    final t = verticalRotation(xy);
    final c = math.cos(t), s = math.sin(t);
    final rot = [
      for (final o in xy) Offset(o.dx * c - o.dy * s, o.dx * s + o.dy * c),
    ];
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final o in rot) {
      minX = math.min(minX, o.dx);
      maxX = math.max(maxX, o.dx);
      minY = math.min(minY, o.dy);
      maxY = math.max(maxY, o.dy);
    }
    final r = (Offset.zero & size).deflate(width * 3);
    final scale = math.min(
      r.width / math.max(maxX - minX, 1e-6),
      r.height / math.max(maxY - minY, 1e-6),
    );
    final ox = r.center.dx - (minX + maxX) / 2 * scale;
    final oy = r.center.dy + (minY + maxY) / 2 * scale;
    Offset at(int i) => Offset(ox + rot[i].dx * scale, oy - rot[i].dy * scale);

    final path = Path();
    for (var i = 0; i < rot.length; i++) {
      final o = at(i);
      final jump =
          i == 0 || (segments != null && segments![i] != segments![i - 1]);
      jump ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(at(rot.length - 1), width * 1.6, Paint()..color = color);
    canvas.drawCircle(
      at(0),
      width * 1.6,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * .8,
    );
  }

  @override
  bool shouldRepaint(_SilhouettePainter old) =>
      old.points != points || old.color != color || old.width != width;
}
