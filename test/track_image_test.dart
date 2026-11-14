import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cresta/src/share/track_image.dart';
import 'package:cresta/src/tracking/track.dart';
import 'package:flutter_test/flutter_test.dart';

final _points = [
  for (var i = 0; i < 30; i++)
    TrackPoint(
      time: DateTime(2026, 11, 14, 10).add(Duration(minutes: i)),
      lng: -68.85 + i * 0.0004,
      lat: -32.9 + (i % 7) * 0.0003,
      altitude: 800.0 + i * 3,
    ),
];

TrackImageData _data() => TrackImageData(
  date: 'vie 13 nov 2026',
  figures: const [('Distancia', '6.81 km'), ('Desnivel', '+80 m')],
  points: _points,
);

void main() {
  test('los tamaños son de 1,080 px de ancho', () {
    expect(ImageAspect.story.pixels, const ui.Size(1080, 1920));
    expect(ImageAspect.square.pixels, const ui.Size(1080, 1080));
    expect(ImageAspect.post.pixels, const ui.Size(1080, 1350));
  });

  test('la fecha no es cifra', () {
    expect(ImageStat.date.isFigure, isFalse);
    expect(ImageStat.distance.isFigure, isTrue);
  });

  for (final bg in ImageBackground.values) {
    test('se dibuja con fondo ${bg.label}', () async {
      final image = await renderTrackImage(
        TrackImagePainter(
          data: _data(),
          background: bg,
          showDate: true,
          showProfile: true,
        ),
        ImageAspect.post.pixels,
      );
      expect(image.width, 1080);
      expect(image.height, 1350);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(png!.lengthInBytes, greaterThan(1000));
    });
  }

  test('sin fondo, las esquinas quedan transparentes', () async {
    final image = await renderTrackImage(
      TrackImagePainter(
        data: _data(),
        background: ImageBackground.transparent,
        showDate: false,
        showProfile: false,
      ),
      ImageAspect.square.pixels,
    );
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(raw!.getUint8(3), 0); // alfa del píxel (0, 0)
  });

  Offset turn(Offset o, double t) => Offset(
    o.dx * math.cos(t) - o.dy * math.sin(t),
    o.dx * math.sin(t) + o.dy * math.cos(t),
  );

  test('una traza hacia el este queda vertical: inicio abajo, fin arriba', () {
    final xy = [for (var i = 0; i <= 10; i++) Offset(i * 100.0, i * 5.0)];
    final t = verticalRotation(xy);
    final a = turn(xy.first, t), b = turn(xy.last, t);
    expect(b.dy, greaterThan(a.dy)); // y al norte: el fin más arriba
    expect((b.dx - a.dx).abs(), lessThan(1));
  });

  test('una traza hacia el sur también: el inicio abajo', () {
    final xy = [for (var i = 0; i <= 10; i++) Offset(0, -i * 100.0)];
    final t = verticalRotation(xy);
    expect(turn(xy.last, t).dy, greaterThan(turn(xy.first, t).dy));
  });

  test('una vuelta alargada: su eje largo queda vertical', () {
    // Elipse de 2 km de este a oeste y 200 m de norte a sur
    final xy = [
      for (var i = 0; i <= 40; i++)
        Offset(
          1000 * math.cos(i / 40 * 2 * math.pi),
          100 * math.sin(i / 40 * 2 * math.pi),
        ),
    ];
    final t = verticalRotation(xy);
    final r = [for (final o in xy) turn(o, t)];
    final w =
        r.map((o) => o.dx).reduce(math.max) -
        r.map((o) => o.dx).reduce(math.min);
    final h =
        r.map((o) => o.dy).reduce(math.max) -
        r.map((o) => o.dy).reduce(math.min);
    expect(h, greaterThan(w * 5));
  });
}
