import 'package:cresta/src/tracking/track.dart';
import 'package:cresta/src/tracking/track_totals.dart';
import 'package:flutter_test/flutter_test.dart';

Track _track(
  String id,
  DateTime start, {
  double meters = 0,
  double gain = 0,
  double? maxAltitude,
  TrackStatus status = TrackStatus.finished,
}) => Track(
  id: id,
  expeditionId: 'e',
  name: id,
  startedAt: start,
  status: status,
  summary: TrackSummary(
    meters: meters,
    gain: gain,
    maxAltitude: maxAltitude,
    moving: const Duration(hours: 1),
  ),
);

void main() {
  // Miércoles 25 de noviembre de 2026: la semana empezó el lunes 23
  final now = DateTime(2026, 11, 25, 18);

  test('suma semana, mes e histórico solo con recorridos terminados', () {
    final s = ActivitySummary([
      _track('hoy', DateTime(2026, 11, 25, 7), meters: 8000, gain: 900),
      _track('lunes', DateTime(2026, 11, 23, 6), meters: 5000, gain: 400),
      _track('domingo', DateTime(2026, 11, 22, 6), meters: 12000, gain: 1500),
      _track('octubre', DateTime(2026, 10, 3, 6), meters: 20000, gain: 2000),
      _track(
        'en curso',
        DateTime(2026, 11, 25, 16),
        meters: 3000,
        gain: 300,
        status: TrackStatus.recording,
      ),
    ], now: now);

    expect(s.weekStart, DateTime(2026, 11, 23));
    expect(s.week.count, 2);
    expect(s.week.gain, 1300);
    expect(s.week.meters, 13000);
    expect(s.month.count, 3);
    expect(s.month.gain, 2800);
    expect(s.all.count, 4);
    expect(s.all.moving, const Duration(hours: 4));
    expect(s.recent.map((t) => t.id), ['hoy', 'lunes', 'domingo']);
  });

  test('altitud máxima y en qué recorrido se alcanzó', () {
    final s = ActivitySummary([
      _track('a', DateTime(2026, 11, 1), maxAltitude: 4200),
      _track('b', DateTime(2026, 11, 8), maxAltitude: 5230),
      _track('c', DateTime(2026, 11, 15)),
    ], now: now);
    expect(s.all.maxAltitude, 5230);
    expect(s.all.highest!.id, 'b');
  });

  test('desnivel por semana, de la más antigua a la actual', () {
    final s = ActivitySummary([
      _track('esta', DateTime(2026, 11, 24), gain: 700),
      _track('pasada', DateTime(2026, 11, 17), gain: 300),
      _track('pasada 2', DateTime(2026, 11, 22, 23), gain: 200),
      _track('hace 7', DateTime(2026, 10, 5), gain: 100),
      _track('muy vieja', DateTime(2026, 9, 1), gain: 999),
    ], now: now);
    expect(s.weeklyGain.length, ActivitySummary.weeks);
    expect(s.weeklyGain.last, 700);
    expect(s.weeklyGain[ActivitySummary.weeks - 2], 500);
    expect(s.weeklyGain.first, 100);
    expect(s.weeklyGain.reduce((a, b) => a + b), 1300);
  });

  test('sin recorridos todo queda en cero', () {
    final s = ActivitySummary(const [], now: now);
    expect(s.all.count, 0);
    expect(s.all.maxAltitude, isNull);
    expect(s.recent, isEmpty);
    expect(s.weeklyGain.every((g) => g == 0), isTrue);
  });
}
