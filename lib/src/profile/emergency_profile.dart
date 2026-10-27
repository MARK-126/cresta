import 'package:flutter/foundation.dart';

import '../storage/json_store.dart';

/// Una persona a quien avisar en una emergencia.
class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.phone,
    this.relation = '',
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> j) => EmergencyContact(
    name: j['name'] as String? ?? '',
    phone: j['phone'] as String? ?? '',
    relation: j['relation'] as String? ?? '',
  );

  final String name;
  final String phone;
  final String relation;

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'relation': relation,
  };
}

/// Datos para rescatistas y servicios médicos. Se guardan solo en el teléfono.
class EmergencyProfile {
  const EmergencyProfile({
    this.name = '',
    this.bloodType = '',
    this.allergies = '',
    this.conditions = '',
    this.insurance = '',
    this.emergencyNumber = '911',
    this.contacts = const [],
  });

  factory EmergencyProfile.fromJson(Map<String, dynamic> j) => EmergencyProfile(
    name: j['name'] as String? ?? '',
    bloodType: j['bloodType'] as String? ?? '',
    allergies: j['allergies'] as String? ?? '',
    conditions: j['conditions'] as String? ?? '',
    insurance: j['insurance'] as String? ?? '',
    emergencyNumber: j['emergencyNumber'] as String? ?? '911',
    contacts: [
      for (final c in j['contacts'] as List? ?? const [])
        EmergencyContact.fromJson(c as Map<String, dynamic>),
    ],
  );

  final String name;

  /// "O+", "A−"… vacío si no se sabe.
  final String bloodType;
  final String allergies;

  /// Condiciones médicas y medicamentos.
  final String conditions;
  final String insurance;

  /// 911 en México y Argentina; 112 en Europa y Chile (también responde el 911 en muchos países).
  final String emergencyNumber;
  final List<EmergencyContact> contacts;

  bool get isEmpty =>
      name.isEmpty &&
      bloodType.isEmpty &&
      allergies.isEmpty &&
      conditions.isEmpty &&
      contacts.isEmpty;

  EmergencyProfile copyWith({
    String? name,
    String? bloodType,
    String? allergies,
    String? conditions,
    String? insurance,
    String? emergencyNumber,
    List<EmergencyContact>? contacts,
  }) => EmergencyProfile(
    name: name ?? this.name,
    bloodType: bloodType ?? this.bloodType,
    allergies: allergies ?? this.allergies,
    conditions: conditions ?? this.conditions,
    insurance: insurance ?? this.insurance,
    emergencyNumber: emergencyNumber ?? this.emergencyNumber,
    contacts: contacts ?? this.contacts,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'bloodType': bloodType,
    'allergies': allergies,
    'conditions': conditions,
    'insurance': insurance,
    'emergencyNumber': emergencyNumber,
    'contacts': [for (final c in contacts) c.toJson()],
  };
}

/// Guarda el perfil de emergencia en `profile.json`.
class ProfileStore extends ChangeNotifier {
  ProfileStore(this._file);

  final JsonStore _file;
  EmergencyProfile profile = const EmergencyProfile();

  Future<void> load() async {
    final saved = await _file.read();
    if (saved is Map<String, dynamic>) {
      profile = EmergencyProfile.fromJson(saved);
    }
    notifyListeners();
  }

  Future<void> save(EmergencyProfile p) async {
    profile = p;
    notifyListeners();
    await _file.write(p.toJson());
  }
}
