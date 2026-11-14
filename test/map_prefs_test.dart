import 'dart:io';

import 'package:cresta/src/map/map_layers.dart';
import 'package:cresta/src/map/map_prefs.dart';
import 'package:cresta/src/storage/json_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('mapa'));
  tearDown(() => dir.delete(recursive: true));

  test('de inicio, Noche; el claro se puede elegir y se recuerda', () async {
    final file = JsonStore(File('${dir.path}/map.json'));
    final store = MapBaseStore(file);
    await store.load();
    expect(store.value, MapBase.night);
    expect(MapBase.values.first, MapBase.night);
    expect(MapBase.topo.label, 'Claro');

    await store.save(MapBase.topo);
    final again = MapBaseStore(file);
    await again.load();
    expect(again.value, MapBase.topo);
  });

  test('archivo dañado o base desconocida: Noche', () async {
    final f = File('${dir.path}/map.json');
    await f.writeAsString('{"base": "marte"}');
    final store = MapBaseStore(JsonStore(f));
    await store.load();
    expect(store.value, MapBase.night);
  });
}
