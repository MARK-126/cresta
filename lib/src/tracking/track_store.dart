import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../storage/json_store.dart';
import 'track.dart';

/// Recorridos guardados en el teléfono.
///
/// Los datos de cada recorrido van en `tracks.json`; sus puntos, en `points/<id>.jsonl`,
/// una línea por punto agregada al final. Así, si la app se cierra o se queda sin batería
/// a mitad de la grabación, se conserva todo lo grabado hasta ese momento.
class TrackStore extends ChangeNotifier {
  TrackStore(this.dir) : _index = JsonStore(File('${dir.path}/tracks.json'));

  final Directory dir;
  final JsonStore _index;
  final _tracks = <Track>[];

  List<Track> get all => List.unmodifiable(_tracks);

  List<Track> forExpedition(String expeditionId) =>
      _tracks.where((t) => t.expeditionId == expeditionId).toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  Track? byId(String id) => _tracks.where((t) => t.id == id).firstOrNull;

  File _pointsFile(String id) => File('${dir.path}/points/$id.jsonl');

  Future<void> load() async {
    final saved = await _index.read();
    if (saved is List) {
      _tracks
        ..clear()
        ..addAll([
          for (final t in saved) Track.fromJson(t as Map<String, dynamic>),
        ]);
    }
    notifyListeners();
  }

  Future<void> add(Track t) async {
    _tracks.add(t);
    await save();
  }

  /// Guarda los cambios hechos a un recorrido (nombre, estado, resumen).
  Future<void> save() async {
    await _index.write([for (final t in _tracks) t.toJson()]);
    notifyListeners();
  }

  Future<void> appendPoints(String id, List<TrackPoint> points) async {
    if (points.isEmpty) return;
    final f = _pointsFile(id);
    await f.parent.create(recursive: true);
    await f.writeAsString(
      points.map((p) => '${jsonEncode(p.toJson())}\n').join(),
      mode: FileMode.append,
      flush: true,
    );
  }

  Future<List<TrackPoint>> readPoints(String id) async {
    final f = _pointsFile(id);
    if (!await f.exists()) return [];
    final out = <TrackPoint>[];
    for (final line in await f.readAsLines()) {
      if (line.trim().isEmpty) continue;
      try {
        out.add(TrackPoint.fromJson(jsonDecode(line) as List));
      } on FormatException {
        // Última línea a medias si la app se cerró escribiendo: se descarta
      }
    }
    return out;
  }

  Future<void> delete(String id) async {
    _tracks.removeWhere((t) => t.id == id);
    final f = _pointsFile(id);
    if (await f.exists()) await f.delete();
    await save();
  }

  Future<void> deleteForExpedition(String expeditionId) async {
    for (final t in forExpedition(expeditionId)) {
      await delete(t.id);
    }
  }
}
