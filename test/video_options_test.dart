import 'dart:io';

import 'package:cresta/src/map/map_layers.dart';
import 'package:cresta/src/map/video_options.dart';
import 'package:cresta/src/storage/json_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('de inicio: Noche, calles y edificios sí; senderos y curvas no', () {
    const o = VideoOptions();
    expect(o.streets, isTrue);
    expect(o.buildings, isTrue);
    expect(o.trails, isFalse);
    expect(o.contours, isFalse);
    expect(o.caption, isTrue);
    expect(o.fast, isFalse);
    expect(o.base, MapBase.night);
  });

  test('ida y vuelta a JSON', () {
    const o = VideoOptions(
      base: MapBase.night,
      streets: false,
      trails: true,
      contours: true,
      buildings: false,
      caption: false,
      fast: true,
    );
    final back = VideoOptions.fromJson(o.toJson());
    expect(back.toJson(), o.toJson());
    expect(o.toJson()['base'], 'night');
  });

  test('JSON viejo o dañado: valores de inicio', () {
    final o = VideoOptions.fromJson({'base': 'marte', 'fast': 'sí'});
    expect(o.base, MapBase.night);
    expect(o.fast, isFalse);
    expect(o.streets, isTrue);
  });

  test('se recuerda la última elección', () async {
    final dir = await Directory.systemTemp.createTemp('video');
    addTearDown(() => dir.delete(recursive: true));
    final file = JsonStore(File('${dir.path}/video.json'));
    await VideoOptionsStore(file).save(const VideoOptions(fast: true));
    final again = VideoOptionsStore(file);
    await again.load();
    expect(again.value.fast, isTrue);
  });
}
