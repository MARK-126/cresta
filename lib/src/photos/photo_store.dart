import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../storage/json_store.dart';

/// Una foto tomada durante un recorrido, con dónde y cuándo se tomó.
class TrackPhoto {
  const TrackPhoto({
    required this.id,
    required this.trackId,
    required this.file,
    required this.time,
    this.lat,
    this.lng,
    this.altitude,
  });

  factory TrackPhoto.fromJson(Map<String, dynamic> j) => TrackPhoto(
    id: j['id'] as String,
    trackId: j['trackId'] as String,
    file: j['file'] as String,
    time: DateTime.parse(j['time'] as String),
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
    altitude: (j['altitude'] as num?)?.toDouble(),
  );

  final String id;
  final String trackId;

  /// Nombre del archivo dentro de la carpeta de fotos.
  final String file;
  final DateTime time;

  /// Posición al tomarla; null si el GPS aún no tenía lectura.
  final double? lat;
  final double? lng;
  final double? altitude;

  bool get located => lat != null && lng != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'trackId': trackId,
    'file': file,
    'time': time.toIso8601String(),
    'lat': lat,
    'lng': lng,
    'altitude': altitude?.roundToDouble(),
  };
}

/// Fotos de los recorridos. Los archivos van en [dir]; el índice, en `photos.json`. Se
/// borran con su recorrido.
class PhotoStore extends ChangeNotifier {
  PhotoStore(this.dir) : _index = JsonStore(File('${dir.path}/photos.json'));

  final Directory dir;
  final JsonStore _index;
  final _photos = <TrackPhoto>[];

  Future<void> load() async {
    final saved = await _index.read();
    if (saved is List) {
      _photos
        ..clear()
        ..addAll([
          for (final p in saved) TrackPhoto.fromJson(p as Map<String, dynamic>),
        ]);
    }
    notifyListeners();
  }

  /// Las fotos de un recorrido, en el orden en que se tomaron.
  List<TrackPhoto> forTrack(String trackId) =>
      _photos.where((p) => p.trackId == trackId).toList()
        ..sort((a, b) => a.time.compareTo(b.time));

  TrackPhoto? byId(String id) => _photos.where((p) => p.id == id).firstOrNull;

  File fileOf(TrackPhoto p) => File('${dir.path}/${p.file}');

  /// Copia [source] (la foto de la cámara) a la carpeta de la app y la agrega al recorrido.
  Future<TrackPhoto> add({
    required String trackId,
    required File source,
    required DateTime time,
    double? lat,
    double? lng,
    double? altitude,
  }) async {
    await dir.create(recursive: true);
    final id =
        '${time.microsecondsSinceEpoch.toRadixString(36)}${math.Random().nextInt(1 << 16).toRadixString(36)}';
    final ext = source.path.contains('.')
        ? source.path.substring(source.path.lastIndexOf('.')).toLowerCase()
        : '.jpg';
    final name = '$id$ext';
    await source.copy('${dir.path}/$name');
    final p = TrackPhoto(
      id: id,
      trackId: trackId,
      file: name,
      time: time,
      lat: lat,
      lng: lng,
      altitude: altitude,
    );
    _photos.add(p);
    await _save();
    return p;
  }

  Future<void> delete(TrackPhoto p) async {
    _photos.removeWhere((x) => x.id == p.id);
    final f = fileOf(p);
    if (await f.exists()) await f.delete();
    await _save();
  }

  Future<void> deleteForTrack(String trackId) async {
    final gone = forTrack(trackId);
    if (gone.isEmpty) return;
    _photos.removeWhere((p) => p.trackId == trackId);
    for (final p in gone) {
      final f = fileOf(p);
      if (await f.exists()) await f.delete();
    }
    await _save();
  }

  Future<void> _save() async {
    await _index.write([for (final p in _photos) p.toJson()]);
    notifyListeners();
  }
}
