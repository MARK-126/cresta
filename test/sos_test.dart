import 'dart:io';

import 'package:cresta/src/profile/emergency_profile.dart';
import 'package:cresta/src/profile/sos.dart';
import 'package:cresta/src/storage/json_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('grados, minutos y segundos', () {
    expect(formatDms(19.178425, -98.640031), '19°10\'42.3" N  98°38\'24.1" O');
    expect(formatDms(-33.04, -69.41), startsWith('33°02\'24.0" S'));
    // 59.99" no se escribe como 60.0"
    expect(formatDms(1.0 - 0.000001, 0), startsWith('1°00\'00.0" N'));
  });

  group('UTM', () {
    test('en el ecuador y el meridiano central', () {
      final u = toUtm(0, -99);
      expect(u.zone, 14);
      expect(u.easting, closeTo(500000, 0.01));
      expect(u.northing, closeTo(0, 0.01));
    });

    test('a 45° sobre el meridiano central (valor de referencia)', () {
      final u = toUtm(45, 3);
      expect(u.zone, 31);
      expect(u.band, 'T');
      expect(u.easting, closeTo(500000, 0.01));
      expect(u.northing, closeTo(4982950.4, 1));
    });

    test('hemisferio sur y oeste: Vallecitos, Mendoza', () {
      final u = toUtm(-33.04, -69.41);
      expect(u.zone, 19);
      expect(u.band, 'H');
      // Al oeste del meridiano central (−69°): este menor a 500 km
      expect(u.easting, inInclusiveRange(450000, 500000));
      expect(u.northing, inInclusiveRange(6340000, 6350000));
      expect(u.toString(), matches(RegExp(r'^19H \d{6} \d{7}$')));
    });

    test('Iztaccíhuatl, México', () {
      final u = toUtm(19.178425, -98.640031);
      expect('${u.zone}${u.band}', '14Q');
      expect(u.easting, inInclusiveRange(530000, 540000));
      expect(u.northing, inInclusiveRange(2115000, 2125000));
    });
  });

  test('mensaje SOS con lo esencial y corto', () {
    final m = sosMessage(
      lat: 19.178425,
      lng: -98.640031,
      altitude: 4987.4,
      accuracy: 6,
      at: DateTime(2026, 11, 15, 9, 5),
      profile: const EmergencyProfile(
        name: 'Marcos',
        bloodType: 'O+',
        allergies: 'penicilina',
      ),
      expedition: 'Izta',
    );
    expect(m, startsWith('SOS. Marcos necesita ayuda.'));
    expect(m, contains('19.17843, -98.64003'));
    expect(m, contains('4987 m (±6 m) a las 09:05'));
    expect(m, contains('maps.google.com/?q=19.17843,-98.64003'));
    expect(m, contains('Sangre O positivo'));
    expect(m, isNot(contains('+')));
    expect(m, contains('Alergias: penicilina'));

    final bare = sosMessage(lat: 1, lng: 2);
    expect(bare, startsWith('SOS. Necesito ayuda.'));
    expect(bare.length, lessThan(120));
  });

  test('el tipo de sangre se dice con palabras', () {
    expect(spokenBloodType('O+'), 'O positivo');
    expect(spokenBloodType('AB-'), 'AB negativo');
    expect(spokenBloodType('A−'), 'A negativo');
    expect(spokenBloodType(''), '');
  });

  test('el perfil se guarda y se vuelve a leer', () async {
    final dir = Directory.systemTemp.createTempSync('cresta_profile');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = JsonStore(File('${dir.path}/profile.json'));
    final store = ProfileStore(file);
    await store.load();
    expect(store.profile.isEmpty, isTrue);
    expect(store.profile.emergencyNumber, '911');
    await store.save(
      store.profile.copyWith(
        name: 'Marcos',
        bloodType: 'A-',
        emergencyNumber: '112',
        contacts: const [
          EmergencyContact(
            name: 'Ana',
            phone: '+52 55 1234 5678',
            relation: 'hermana',
          ),
        ],
      ),
    );
    final again = ProfileStore(file);
    await again.load();
    expect(again.profile.name, 'Marcos');
    expect(again.profile.emergencyNumber, '112');
    expect(again.profile.contacts.single.relation, 'hermana');
  });
}
