import 'dart:io';

import 'package:cresta/src/storage/json_store.dart';
import 'package:cresta/src/tips/tips.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('las indicaciones se ven una vez y se pueden volver a ver', () async {
    final tmp = Directory.systemTemp.createTempSync('cresta_tips');
    addTearDown(() => tmp.deleteSync(recursive: true));
    TipStore open() => TipStore(JsonStore(File('${tmp.path}/tips.json')));

    final tips = open();
    await tips.load();
    expect(tips.seen(Tips.map), isFalse);
    await tips.markSeen(Tips.map);

    // Al reabrir la app se recuerda
    final again = open();
    await again.load();
    expect(again.seen(Tips.map), isTrue);
    expect(again.seen(Tips.plan), isFalse);

    await again.reset();
    final reset = open();
    await reset.load();
    expect(reset.seen(Tips.map), isFalse);
  });

  test('cada indicación es breve', () {
    for (final t in [Tips.map, Tips.plan, Tips.record]) {
      expect(t.points.length, inInclusiveRange(2, 4));
      for (final (_, text) in t.points) {
        expect(text.length, lessThan(160), reason: text);
      }
    }
  });
}
