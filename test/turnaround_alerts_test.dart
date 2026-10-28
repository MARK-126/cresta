import 'dart:async';
import 'dart:io';

import 'package:cresta/src/tracking/track_recorder.dart';
import 'package:cresta/src/tracking/track_store.dart';
import 'package:cresta/src/tracking/turnaround_alerts.dart';
import 'package:flutter_test/flutter_test.dart';

class _Sink implements AlertSink {
  final shown = <int>[];
  final cancelled = <int>[];

  @override
  Future<void> show(int id, String title, String body) async => shown.add(id);

  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  group('TurnaroundAlerts', () {
    late Directory tmp;
    late TrackRecorder rec;
    late _Sink sink;
    late TurnaroundAlerts alerts;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('cresta_alerts');
      final store = TrackStore(Directory('${tmp.path}/tracks'));
      await store.load();
      rec = TrackRecorder(
        store: store,
        positions: (_) => StreamController<GpsFix>().stream,
      );
      sink = _Sink();
      alerts = TurnaroundAlerts(
        recorder: rec,
        sink: sink,
        warnBefore: const Duration(milliseconds: 200),
      )..attach();
    });
    tearDown(() async {
      alerts.dispose();
      rec.dispose();
      await _wait(50);
      tmp.deleteSync(recursive: true);
    });

    test(
      'avisa antes de la hora límite y cuando llega, una vez cada uno',
      () async {
        await rec.start(
          expeditionId: 'e',
          name: 'Subida',
          turnaround: DateTime.now().add(const Duration(milliseconds: 500)),
        );
        await _wait(100);
        expect(sink.shown, isEmpty);
        await _wait(300);
        expect(sink.shown, [TurnaroundAlerts.warnId]);
        await _wait(250);
        expect(sink.shown, [TurnaroundAlerts.warnId, TurnaroundAlerts.dueId]);
        await _wait(300);
        expect(sink.shown.length, 2);
      },
    );

    test('no avisa nada si el recorrido termina antes', () async {
      await rec.start(
        expeditionId: 'e',
        name: 'Subida',
        turnaround: DateTime.now().add(const Duration(milliseconds: 400)),
      );
      await rec.discard();
      sink.cancelled.clear();
      await _wait(600);
      expect(sink.shown, isEmpty);
    });

    test('lo que ya pasó no se avisa', () async {
      await rec.start(
        expeditionId: 'e',
        name: 'Subida',
        turnaround: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      await _wait(100);
      expect(sink.shown, isEmpty);
    });

    test('una hora límite fijada tarde también se avisa', () async {
      await rec.start(expeditionId: 'e', name: 'Subida');
      expect(sink.shown, isEmpty);
      rec.turnaround = DateTime.now().add(const Duration(milliseconds: 300));
      rec.notifyListeners();
      await _wait(450);
      expect(sink.shown, [TurnaroundAlerts.warnId, TurnaroundAlerts.dueId]);
    });
  });
}
