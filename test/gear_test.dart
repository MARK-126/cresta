import 'dart:io';

import 'package:cresta/src/gear/gear.dart';
import 'package:cresta/src/storage/json_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late JsonStore file;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('cresta_gear');
    file = JsonStore(File('${dir.path}/gear.json'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('las plantillas se suman sin repetir objetos', () async {
    final s = GearStore(file);
    await s.load();
    final day = await s.addTemplate('e', GearTemplate.dayHike);
    expect(day, GearTemplate.dayHike.items().length);
    // La de alta montaña incluye la de un día: solo agrega lo que falta
    final extra = await s.addTemplate('e', GearTemplate.alpineDay);
    expect(extra, GearTemplate.alpineDay.items().length - day);
    final names = s.forExpedition('e').map((i) => i.name.toLowerCase());
    expect(names.toSet().length, names.length);
    expect(s.forExpedition('e').any((i) => i.name == 'Crampones'), isTrue);
  });

  test('empacar, peso total, guardar y desmarcar todo', () async {
    final s = GearStore(file);
    await s.load();
    await s.add(
      'e',
      GearItem(name: 'Piolet', category: GearCategory.technical, grams: 450),
    );
    await s.add(
      'e',
      GearItem(name: 'Carta topográfica', category: GearCategory.navigation),
    );
    final piolet = s.forExpedition('e').first;
    await s.update('e', piolet.copyWith(packed: true));
    expect(totalGrams(s.forExpedition('e')), 450);

    final again = GearStore(file);
    await again.load();
    expect(
      again.forExpedition('e').where((i) => i.packed).single.name,
      'Piolet',
    );
    expect(again.forExpedition('e').last.grams, isNull);

    await again.unpackAll('e');
    expect(again.forExpedition('e').any((i) => i.packed), isFalse);
    await again.remove('e', piolet.id);
    expect(again.forExpedition('e').single.name, 'Carta topográfica');
  });

  test('borrar la expedición borra su lista y no deja rastro', () async {
    final s = GearStore(file);
    await s.load();
    await s.addTemplate('a', GearTemplate.dayHike);
    await s.addTemplate('b', GearTemplate.dayHike);
    await s.deleteExpedition('a');
    final again = GearStore(file);
    await again.load();
    expect(again.forExpedition('a'), isEmpty);
    expect(again.forExpedition('b'), isNotEmpty);
    expect(await file.read(), isNot(contains('a')));
  });
}
