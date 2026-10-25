import 'dart:math' as math;

/// Una lectura del GPS ya aceptada en el recorrido.
class TrackPoint {
  const TrackPoint({
    required this.time,
    required this.lng,
    required this.lat,
    this.altitude,
    this.accuracy = 0,
    this.speed,
    this.segment = 0,
  });

  /// Formato compacto de una línea: `[ms, lng, lat, alt, precisión, velocidad, segmento]`.
  factory TrackPoint.fromJson(List j) => TrackPoint(
    time: DateTime.fromMillisecondsSinceEpoch(j[0] as int),
    lng: (j[1] as num).toDouble(),
    lat: (j[2] as num).toDouble(),
    altitude: (j[3] as num?)?.toDouble(),
    accuracy: (j[4] as num?)?.toDouble() ?? 0,
    speed: (j[5] as num?)?.toDouble(),
    segment: j.length > 6 ? j[6] as int : 0,
  );

  final DateTime time;
  final double lng;
  final double lat;
  final double? altitude;

  /// Radio de error del GPS en metros.
  final double accuracy;

  /// m/s según el GPS (puede faltar).
  final double? speed;

  /// Cambia al reanudar después de una pausa: el mapa no une los tramos.
  final int segment;

  List<Object?> toJson() => [
    time.millisecondsSinceEpoch,
    double.parse(lng.toStringAsFixed(6)),
    double.parse(lat.toStringAsFixed(6)),
    altitude == null ? null : double.parse(altitude!.toStringAsFixed(1)),
    double.parse(accuracy.toStringAsFixed(1)),
    speed == null ? null : double.parse(speed!.toStringAsFixed(2)),
    segment,
  ];
}

enum TrackStatus { recording, paused, finished }

/// Datos de un recorrido grabado (los puntos se guardan aparte).
class Track {
  Track({
    required this.id,
    required this.expeditionId,
    required this.name,
    required this.startedAt,
    this.endedAt,
    this.status = TrackStatus.recording,
    TrackSummary? summary,
  }) : summary = summary ?? const TrackSummary();

  factory Track.fromJson(Map<String, dynamic> j) => Track(
    id: j['id'] as String,
    expeditionId: j['expeditionId'] as String,
    name: j['name'] as String,
    startedAt: DateTime.parse(j['startedAt'] as String),
    endedAt: DateTime.tryParse('${j['endedAt']}'),
    status: TrackStatus.values.byName(j['status'] as String),
    summary: TrackSummary.fromJson(
      j['summary'] as Map<String, dynamic>? ?? const {},
    ),
  );

  final String id;
  final String expeditionId;
  String name;
  final DateTime startedAt;
  DateTime? endedAt;
  TrackStatus status;
  TrackSummary summary;

  Map<String, dynamic> toJson() => {
    'id': id,
    'expeditionId': expeditionId,
    'name': name,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    'status': status.name,
    'summary': summary.toJson(),
  };
}

/// Cifras finales de un recorrido, para listarlo sin leer todos sus puntos.
class TrackSummary {
  const TrackSummary({
    this.meters = 0,
    this.gain = 0,
    this.loss = 0,
    this.maxAltitude,
    this.moving = Duration.zero,
    this.elapsed = Duration.zero,
    this.points = 0,
  });

  factory TrackSummary.fromJson(Map<String, dynamic> j) => TrackSummary(
    meters: (j['meters'] as num?)?.toDouble() ?? 0,
    gain: (j['gain'] as num?)?.toDouble() ?? 0,
    loss: (j['loss'] as num?)?.toDouble() ?? 0,
    maxAltitude: (j['maxAltitude'] as num?)?.toDouble(),
    moving: Duration(seconds: j['movingS'] as int? ?? 0),
    elapsed: Duration(seconds: j['elapsedS'] as int? ?? 0),
    points: j['points'] as int? ?? 0,
  );

  final double meters;
  final double gain;
  final double loss;
  final double? maxAltitude;
  final Duration moving;
  final Duration elapsed;
  final int points;

  Map<String, dynamic> toJson() => {
    'meters': meters.round(),
    'gain': gain.round(),
    'loss': loss.round(),
    'maxAltitude': maxAltitude?.round(),
    'movingS': moving.inSeconds,
    'elapsedS': elapsed.inSeconds,
    'points': points,
  };
}

/// Distancia en metros entre dos puntos (fórmula del haversine).
double haversine(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final p1 = lat1 * math.pi / 180, p2 = lat2 * math.pi / 180;
  final dp = p2 - p1, dl = (lng2 - lng1) * math.pi / 180;
  final a =
      math.sin(dp / 2) * math.sin(dp / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(a)));
}
