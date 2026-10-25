import 'trail_route.dart';

/// Datos de protección civil. Hoy vienen de `assets/data/civil_demo.json` (ilustrativos);
/// en producción vendrían de una fuente oficial o del backend.
class CivilData {
  CivilData({required this.volcanoName, required this.alertLabel, required this.shelters, required this.reports});

  factory CivilData.fromJson(Map<String, dynamic> json) => CivilData(
        volcanoName: (json['volcano'] as Map)['name'] as String,
        alertLabel: (json['alert'] as Map)['label'] as String,
        shelters: [for (final s in json['shelters'] as List) Shelter.fromJson(s as Map<String, dynamic>)],
        reports: [for (final r in json['reports'] as List) CitizenReport.fromJson(r as Map<String, dynamic>)],
      );

  final String volcanoName;
  final String alertLabel;
  final List<Shelter> shelters;
  final List<CitizenReport> reports;

  int get freeSpots => shelters.fold(0, (sum, s) => sum + s.free);
}

class Shelter {
  Shelter({required this.id, required this.name, required this.place, required this.capacity, required this.occupied, required this.at});

  factory Shelter.fromJson(Map<String, dynamic> json) => Shelter(
        id: json['id'] as String,
        name: json['name'] as String,
        place: json['place'] as String,
        capacity: json['capacity'] as int,
        occupied: json['occupied'] as int,
        at: LngLat.fromJson(json['at'] as List),
      );

  final String id;
  final String name;
  final String place;
  final int capacity;
  final int occupied;
  final LngLat at;

  int get free => capacity - occupied;
  double get occupancy => occupied / capacity;
}

class CitizenReport {
  CitizenReport({required this.id, required this.type, required this.colorHex, required this.at, required this.minutesAgo, required this.by});

  factory CitizenReport.fromJson(Map<String, dynamic> json) => CitizenReport(
        id: json['id'] as String,
        type: json['type'] as String,
        colorHex: json['color'] as String,
        at: LngLat.fromJson(json['at'] as List),
        minutesAgo: json['minutesAgo'] as int,
        by: json['by'] as String,
      );

  final String id;
  final String type;
  final String colorHex;
  final LngLat at;
  final int minutesAgo;
  final String by;
}

/// Una cumbre, refugio o inicio de ruta.
class Peak {
  Peak({required this.name, required this.at, required this.kind, this.elevation});

  factory Peak.fromJson(Map<String, dynamic> json) => Peak(
        name: json['name'] as String,
        at: LngLat((json['lon'] as num).toDouble(), (json['lat'] as num).toDouble()),
        kind: json['kind'] as String? ?? 'peak',
        elevation: int.tryParse('${json['ele']}'),
      );

  final String name;
  final LngLat at;
  final String kind;
  final int? elevation;

  bool get climbingForbidden => name == 'Popocatépetl';
}
