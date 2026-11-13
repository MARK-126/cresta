import 'dart:io';

import 'package:cresta/src/photos/photo_store.dart';
import 'package:cresta/src/tracking/track.dart';
import 'package:cresta/src/tracking/track_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  late File camera;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('cresta_fotos');
    camera = File('${tmp.path}/IMG_0001.jpg')..writeAsBytesSync([1, 2, 3]);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('guarda la foto con su ubicación y la recuerda al reabrir', () async {
    final store = PhotoStore(Directory('${tmp.path}/photos'));
    await store.load();
    final t0 = DateTime(2026, 11, 13, 10);
    await store.add(
      trackId: 't1',
      source: camera,
      time: t0.add(const Duration(minutes: 5)),
      lat: -32.95,
      lng: -69.43,
      altitude: 3460,
    );
    await store.add(trackId: 't1', source: camera, time: t0); // sin GPS
    await store.add(trackId: 't2', source: camera, time: t0);

    final again = PhotoStore(store.dir);
    await again.load();
    final photos = again.forTrack('t1');
    expect(photos, hasLength(2));
    // En el orden en que se tomaron
    expect(photos.first.located, isFalse);
    expect(photos.last.altitude, 3460);
    expect(photos.last.lat, -32.95);
    expect(again.fileOf(photos.last).readAsBytesSync(), [1, 2, 3]);
    expect(again.fileOf(photos.last).path, endsWith('.jpg'));
  });

  test('borrar una foto, y todas al borrar su recorrido', () async {
    final photos = PhotoStore(Directory('${tmp.path}/photos'));
    await photos.load();
    final tracks = TrackStore(
      Directory('${tmp.path}/tracks'),
      onDeleted: photos.deleteForTrack,
    );
    await tracks.load();
    await tracks.add(Track(id: 't1', name: 'x', startedAt: DateTime(2026)));
    final a = await photos.add(
      trackId: 't1',
      source: camera,
      time: DateTime(2026),
    );
    final b = await photos.add(
      trackId: 't1',
      source: camera,
      time: DateTime(2026, 1, 2),
    );
    final other = await photos.add(
      trackId: 't2',
      source: camera,
      time: DateTime(2026),
    );

    await photos.delete(a);
    expect(photos.forTrack('t1').map((p) => p.id), [b.id]);
    expect(photos.fileOf(a).existsSync(), isFalse);

    await tracks.delete('t1');
    expect(photos.forTrack('t1'), isEmpty);
    expect(photos.fileOf(b).existsSync(), isFalse);
    // Las de otros recorridos no se tocan
    expect(photos.fileOf(other).existsSync(), isTrue);
  });
}
