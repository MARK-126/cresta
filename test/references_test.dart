import 'dart:io';
import 'dart:typed_data';

import 'package:cresta/src/references/references.dart';
import 'package:cresta/src/storage/json_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late ReferenceStore store;
  setUp(() async {
    dir = Directory.systemTemp.createTempSync('cresta_refs');
    store = ReferenceStore(
      JsonStore(File('${dir.path}/references.json')),
      Directory('${dir.path}/references'),
    );
    await store.load();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('un archivo se copia a la app y sobrevive al original', () async {
    final r = await store.addFile(
      'e',
      title: 'Permiso del parque',
      fileName: 'Permiso.PDF',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    expect(r.isPdf, isTrue);
    expect(r.isImage, isFalse);
    final f = store.fileOf('e', r);
    expect(await f.readAsBytes(), [1, 2, 3]);

    final again = ReferenceStore(store.file, store.dir);
    await again.load();
    expect(again.forExpedition('e').single.title, 'Permiso del parque');
    expect(
      again.fileOf('e', again.forExpedition('e').single).existsSync(),
      isTrue,
    );

    await again.remove('e', r);
    expect(again.forExpedition('e'), isEmpty);
    expect(f.existsSync(), isFalse);
  });

  test('enlaces sin esquema reciben https; teléfonos y nombres', () async {
    final l = await store.addLink(
      'e',
      'Ruta en Wikiloc',
      'es.wikiloc.com/rutas/123',
    );
    expect(l.value, 'https://es.wikiloc.com/rutas/123');
    final keep = await store.addLink('e', 'Parque', 'http://parque.gob.mx');
    expect(keep.value, 'http://parque.gob.mx');
    final p = await store.addPhone('e', 'Refugio', '+54 261 123 4567');
    await store.rename('e', p, 'Refugio Plantamura');
    expect(store.forExpedition('e').map((r) => r.title), [
      'Ruta en Wikiloc',
      'Parque',
      'Refugio Plantamura',
    ]);
    expect(store.forExpedition('e').last.kind, ReferenceKind.phone);
  });

  test('borrar la expedición borra referencias y archivos', () async {
    await store.addFile(
      'a',
      title: 'Croquis',
      fileName: 'c.jpg',
      bytes: Uint8List(4),
    );
    await store.addLink('b', 'x', 'example.com');
    await store.deleteExpedition('a');
    expect(store.forExpedition('a'), isEmpty);
    expect(Directory('${store.dir.path}/a').existsSync(), isFalse);
    expect(store.forExpedition('b'), isNotEmpty);
  });
}
