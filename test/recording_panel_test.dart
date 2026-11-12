import 'dart:io';

import 'package:cresta/src/tracking/track.dart';
import 'package:cresta/src/tracking/track_recorder.dart';
import 'package:cresta/src/tracking/track_store.dart';
import 'package:cresta/src/ui/recording_panel.dart';
import 'package:cresta/src/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('el panel ofrece volver por la traza y guía al inicio', (
    tester,
  ) async {
    // Estado de una grabación con 500 m hacia el norte (sin arrancar el GPS: el panel
    // solo lee el estado, y la grabación real deja temporizadores que la prueba no cierra)
    final t0 = DateTime(2026, 11, 12, 9);
    final rec = TrackRecorder(
      store: TrackStore(Directory.systemTemp),
      positions: (_) => const Stream.empty(),
      clock: () => t0,
    )..state = RecorderState.recording;
    for (var i = 0; i < 21; i++) {
      rec.points.add(
        TrackPoint(
          time: t0.add(Duration(seconds: 30 * i)),
          lng: -98.65,
          lat: 19.10 + i * 25 / 110570,
          altitude: 3700 + i * 5.0,
          accuracy: 5,
        ),
      );
    }
    rec.lastFix = GpsFix(
      time: t0.add(const Duration(minutes: 10)),
      lng: -98.65,
      lat: 19.10 + 500 / 110570,
      accuracy: 5,
    );
    var toggles = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: crestaTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ListenableBuilder(
              listenable: rec,
              builder: (_, _) => RecordingPanel(
                recorder: rec,
                onPause: () {},
                onResume: () {},
                onStop: () {},
                onBacktrack: () {
                  toggles++;
                  rec.backtracking ? rec.stopBacktrack() : rec.startBacktrack();
                },
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('GRABANDO'), findsOneWidget);
    await tester.tap(find.text('Volver al inicio por mi traza'));
    await tester.pump();
    expect(toggles, 1);
    expect(find.text('REGRESANDO'), findsOneWidget);
    expect(find.textContaining('por tu traza hasta el inicio'), findsOneWidget);
    // ~503 m: la prueba avanza 25 m con otra constante de grados de latitud
    expect(
      find.textContaining(
        RegExp(r'^El inicio está a 50\d m en línea recta, rumbo 180° \(S\)\.$'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Dejar de guiar el regreso'));
    await tester.pump();
    expect(find.text('GRABANDO'), findsOneWidget);
    expect(find.text('Volver al inicio por mi traza'), findsOneWidget);
  });
}
