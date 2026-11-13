import 'package:cresta/src/data/trail_route.dart';
import 'package:cresta/src/profile/emergency_profile.dart';
import 'package:cresta/src/routes/planned_route.dart';
import 'package:cresta/src/ui/trip_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 8 km con 800 m de subida: Naismith = 2 h + 2 h = 4 h; con descansos (×1.3) 5 h 12
  final a = LngLat(-69.43, -32.95), b = LngLat(-69.40, -32.90);
  final route = PlannedRoute(
    name: 'Cerro Arenales',
    waypoints: [a, b],
    legs: [
      [a, b],
    ],
    snapped: [true],
    pois: const [],
    profile: TrailRoute(
      id: 'r',
      name: 'Cerro Arenales',
      summary: '',
      coordinates: [a, b],
      distances: const [0, 8000],
      elevations: const [2900, 3700],
      gain: 800,
      source: '',
    ),
  );
  const profile = EmergencyProfile(
    name: 'Marcos',
    bloodType: 'O+',
    emergencyNumber: '911',
  );

  test('horarios sugeridos: salida a las 7 del día, regreso con la ruta y alarma 2 h después', () {
    final t = suggestTripTimes(
      now: DateTime(2026, 11, 13, 20),
      day: DateTime(2026, 11, 15),
      route: route,
    );
    expect(t.start, DateTime(2026, 11, 15, 7));
    expect(
      t.back,
      DateTime(2026, 11, 15, 12, 15),
    ); // 7:00 + 5 h 12, al cuarto de hora
    expect(t.alarm, DateTime(2026, 11, 15, 14, 15));
  });

  test('sin fecha o si es hoy: en media hora; sin ruta, 6 h', () {
    final t = suggestTripTimes(now: DateTime(2026, 11, 13, 8, 10));
    expect(t.start, DateTime(2026, 11, 13, 8, 45));
    expect(t.back, DateTime(2026, 11, 13, 14, 45));
  });

  test('el mensaje dice a dónde, por dónde, cuándo y qué hacer', () {
    final msg = tripPlanMessage(
      profile: profile,
      place: 'Vallecitos',
      times: TripTimes(
        DateTime(2026, 11, 15, 7),
        DateTime(2026, 11, 15, 15, 30),
        DateTime(2026, 11, 15, 17, 30),
      ),
      route: route,
      turnaround: DateTime(2026, 11, 15, 11),
    );
    expect(msg, startsWith('Plan de salida de Marcos (Cresta)'));
    expect(msg, contains('Voy a: Vallecitos, dom 15 nov 2026.'));
    expect(msg, contains('Salgo a las 07:00 y pienso volver a las 15:30.'));
    expect(
      msg,
      contains('Ruta: Cerro Arenales, 8.0 km, +800 m, unas 4 h 00 de marcha.'),
    );
    expect(msg, contains('https://maps.google.com/?q=-32.95000,-69.43000'));
    expect(msg, contains('Hora límite para darme la vuelta: 11:00'));
    expect(msg, contains('no te preocupes antes de las 17:30'));
    expect(msg, contains('llama al 911'));
    expect(msg, contains('sangre O positivo'));
  });

  test('si el regreso es otro día, lo dice', () {
    final msg = tripPlanMessage(
      profile: const EmergencyProfile(),
      place: 'Aconcagua',
      times: TripTimes(
        DateTime(2026, 11, 15, 7),
        DateTime(2026, 11, 17, 18),
        DateTime(2026, 11, 17, 20),
      ),
    );
    expect(msg, startsWith('Plan de salida a la montaña (Cresta)'));
    expect(msg, contains('volver a las 18:00 del mar 17 nov 2026.'));
    expect(msg, isNot(contains('Ruta:')));
  });
}
