import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/trail_route.dart';
import 'format.dart';

/// Perfil de elevación que se puede recorrer con el dedo.
class ElevationProfile extends StatelessWidget {
  const ElevationProfile({
    super.key,
    required this.route,
    this.cursorMeters,
    this.onScrub,
    this.onScrubEnd,
    this.height = 130,
  });

  final TrailRoute route;
  final double? cursorMeters;
  final ValueChanged<double>? onScrub;
  final VoidCallback? onScrubEnd;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        final painter = _ProfilePainter(
          route: route,
          cursor: cursorMeters,
          line: scheme.primary,
          grid: scheme.outlineVariant,
          text: scheme.onSurfaceVariant,
          dot: scheme.surface,
        );
        void scrub(Offset local) =>
            onScrub?.call(painter.metersAt(local.dx, box.maxWidth));
        return Semantics(
          label:
              'Perfil de elevación: ${fmtKm(route.totalMeters)} km, de ${fmtInt(route.minElevation)} a ${fmtInt(route.maxElevation)} m',
          child: GestureDetector(
            onHorizontalDragStart: (d) => scrub(d.localPosition),
            onHorizontalDragUpdate: (d) => scrub(d.localPosition),
            onHorizontalDragEnd: (_) => onScrubEnd?.call(),
            onTapDown: (d) => scrub(d.localPosition),
            child: CustomPaint(
              size: Size(box.maxWidth, height),
              painter: painter,
            ),
          ),
        );
      },
    );
  }
}

class _ProfilePainter extends CustomPainter {
  _ProfilePainter({
    required this.route,
    required this.cursor,
    required this.line,
    required this.grid,
    required this.text,
    required this.dot,
  });

  final TrailRoute route;
  final double? cursor;
  final Color line, grid, text, dot;

  static const _left = 38.0, _right = 6.0, _top = 8.0, _bottom = 18.0;

  double get _lo => (route.minElevation / 500).floor() * 500.0;
  double get _hi => (route.maxElevation / 500).ceil() * 500.0;

  double metersAt(double x, double width) =>
      ((x - _left) / (width - _left - _right)).clamp(0.0, 1.0) *
      route.totalMeters;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - _left - _right;
    final h = size.height - _top - _bottom;
    double sx(double m) => _left + m / route.totalMeters * w;
    double sy(double e) => _top + h - (e - _lo) / (_hi - _lo) * h;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    void label(String s, Offset at, {TextAlign align = TextAlign.right}) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            color: text,
            fontSize: 10,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = align == TextAlign.right
          ? at.dx - tp.width
          : at.dx - tp.width / 2;
      tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
    }

    for (var e = _lo; e <= _hi; e += 500) {
      canvas.drawLine(
        Offset(_left, sy(e)),
        Offset(size.width - _right, sy(e)),
        gridPaint,
      );
      label(fmtInt(e), Offset(_left - 4, sy(e)));
    }
    final kmStep = route.totalMeters > 8000 ? 2 : 1;
    for (var k = 0; k * 1000 <= route.totalMeters; k += kmStep) {
      label(
        '$k km',
        Offset(sx(k * 1000.0), size.height - 6),
        align: TextAlign.center,
      );
    }

    final path = Path();
    final step = math.max(1, route.distances.length ~/ 300);
    for (var i = 0; i < route.distances.length; i += step) {
      final p = Offset(sx(route.distances[i]), sy(route.elevations[i]));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.lineTo(sx(route.totalMeters), sy(route.endElevation));
    final area = Path.from(path)
      ..lineTo(sx(route.totalMeters), sy(_lo))
      ..lineTo(sx(0), sy(_lo))
      ..close();
    canvas.drawPath(area, Paint()..color = line.withValues(alpha: 0.16));
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    if (cursor != null) {
      final p = route.along(cursor!);
      final x = sx(p.meters);
      final dash = Paint()
        ..color = text
        ..strokeWidth = 1;
      for (var y = _top; y < size.height - _bottom; y += 6) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, math.min(y + 3, size.height - _bottom)),
          dash,
        );
      }
      canvas.drawCircle(Offset(x, sy(p.elevation)), 5, Paint()..color = dot);
      canvas.drawCircle(Offset(x, sy(p.elevation)), 3.5, Paint()..color = line);
    }
  }

  @override
  bool shouldRepaint(_ProfilePainter old) =>
      old.cursor != cursor || old.route != route || old.line != line;
}
