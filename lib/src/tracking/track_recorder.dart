import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/trail_route.dart';
import 'route_progress.dart';
import 'track.dart';
import 'track_stats.dart';
import 'track_store.dart';

/// Una lectura del GPS, independiente del plugin de ubicación.
class GpsFix {
  const GpsFix({
    required this.time,
    required this.lng,
    required this.lat,
    this.altitude,
    this.accuracy = 0,
    this.speed,
  });
  final DateTime time;
  final double lng;
  final double lat;
  final double? altitude;
  final double accuracy;
  final double? speed;
}

enum RecordingMode {
  normal('Normal', 'Un punto cada 5 m. Más preciso.'),
  saver('Ahorro de batería', 'Un punto cada 20 m. Para jornadas largas.');

  const RecordingMode(this.label, this.description);
  final String label;
  final String description;
}

enum RecorderState { idle, recording, paused }

enum TurnaroundState { none, ok, soon, passed }

/// Graba el recorrido: filtra las lecturas malas del GPS, guarda los puntos en disco
/// a medida que llegan y calcula estadísticas, avance sobre la ruta y hora límite.
class TrackRecorder extends ChangeNotifier {
  TrackRecorder({
    required this.store,
    required this.positions,
    this.terrain,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Altitud del terreno según el relieve descargado. Si existe para ese punto, se usa en lugar
  /// de la del GPS (que salta ±15 m) para que el desnivel sea confiable.
  final Future<double?> Function(double lng, double lat)? terrain;
  Future<void> _queue = Future.value();

  final TrackStore store;

  /// Fuente de lecturas del GPS (en la app, `geolocator`; en pruebas, un stream falso).
  final Stream<GpsFix> Function(RecordingMode mode) positions;
  final DateTime Function() _clock;

  /// Lecturas con un error mayor no se guardan.
  static const maxAccuracy = 50.0;

  RecorderState state = RecorderState.idle;
  RecordingMode mode = RecordingMode.normal;
  Track? track;
  TrailRoute? route;

  /// Hora límite para emprender el regreso (de la expedición).
  DateTime? turnaround;

  final points = <TrackPoint>[];
  TrackStats stats = TrackStats();
  RouteProgress? progress;
  GpsFix? lastFix;

  StreamSubscription<GpsFix>? _sub;
  final _pending = <TrackPoint>[];
  Timer? _flush;
  int _segment = 0;

  bool get isActive => state != RecorderState.idle;

  TurnaroundState get turnaroundState {
    final t = turnaround;
    if (t == null || !isActive) return TurnaroundState.none;
    final left = t.difference(_clock());
    if (left.isNegative) return TurnaroundState.passed;
    if (left <= const Duration(minutes: 30)) return TurnaroundState.soon;
    return TurnaroundState.ok;
  }

  Duration? get turnaroundLeft => turnaround?.difference(_clock());

  /// Si la app se cerró grabando, deja ese recorrido en pausa para que el usuario lo retome o lo termine.
  /// La ruta y la hora límite se vuelven a asignar al abrir el mapa de la expedición.
  Future<void> recover() async {
    final open = store.all
        .where((t) => t.status != TrackStatus.finished)
        .toList();
    if (open.isEmpty) return;
    final t = open.first;
    track = t..status = TrackStatus.paused;
    points
      ..clear()
      ..addAll(await store.readPoints(t.id));
    stats = TrackStats.of(points);
    _segment = points.isEmpty ? 0 : points.last.segment + 1;
    state = RecorderState.paused;
    await store.save();
    notifyListeners();
  }

  Future<Track> start({
    required String expeditionId,
    required String name,
    TrailRoute? route,
    DateTime? turnaround,
    RecordingMode mode = RecordingMode.normal,
  }) async {
    if (isActive) throw StateError('Ya hay un recorrido en curso');
    final now = _clock();
    final t = Track(
      id: '${now.microsecondsSinceEpoch.toRadixString(36)}${math.Random().nextInt(1 << 16).toRadixString(36)}',
      expeditionId: expeditionId,
      name: name,
      startedAt: now,
    );
    await store.add(t);
    track = t;
    this.route = route;
    this.turnaround = turnaround;
    this.mode = mode;
    points.clear();
    stats = TrackStats();
    progress = null;
    lastFix = null;
    _segment = 0;
    _listen();
    return t;
  }

  void pause() {
    if (state != RecorderState.recording) return;
    _sub?.cancel();
    _sub = null;
    state = RecorderState.paused;
    track!.status = TrackStatus.paused;
    _persist();
    notifyListeners();
  }

  void resume({RecordingMode? mode}) {
    if (state != RecorderState.paused) return;
    if (mode != null) this.mode = mode;
    _segment++;
    track!.status = TrackStatus.recording;
    _listen();
  }

  /// Cambia de modo sin cortar el tramo.
  void setMode(RecordingMode m) {
    mode = m;
    if (state == RecorderState.recording) {
      _sub?.cancel();
      _sub = positions(m).listen(_onFix);
    }
    notifyListeners();
  }

  Future<Track> stop() async {
    final t = track!;
    await _sub?.cancel();
    _sub = null;
    t
      ..status = TrackStatus.finished
      ..endedAt = points.isEmpty ? _clock() : points.last.time
      ..summary = stats.summary;
    await _persist();
    _reset();
    return t;
  }

  /// Termina sin guardar.
  Future<void> discard() async {
    final t = track;
    await _sub?.cancel();
    _sub = null;
    _pending.clear();
    if (t != null) await store.delete(t.id);
    _reset();
  }

  void _reset() {
    _flush?.cancel();
    _flush = null;
    state = RecorderState.idle;
    track = null;
    route = null;
    turnaround = null;
    progress = null;
    points.clear();
    stats = TrackStats();
    notifyListeners();
  }

  void _listen() {
    state = RecorderState.recording;
    _sub = positions(mode)
        .listen(_onFix, onError: (Object e) => debugPrint('GPS: $e'));
    // Cada 10 s guarda lo pendiente y refresca la pantalla
    // (la cuenta regresiva de la hora límite avanza aunque no lleguen lecturas)
    _flush ??= Timer.periodic(const Duration(seconds: 10), (_) {
      _persist();
      notifyListeners();
    });
    store.save();
    notifyListeners();
  }

  @visibleForTesting
  void onFix(GpsFix f) => _onFix(f);

  void _onFix(GpsFix f) {
    final terrain = this.terrain;
    if (terrain == null) return _accept(f, f.altitude);
    // Las lecturas se procesan en orden aunque buscar la altitud sea asíncrono
    _queue = _queue.then((_) async {
      final ground = await terrain(f.lng, f.lat);
      if (state == RecorderState.recording) _accept(f, ground ?? f.altitude);
    });
  }

  void _accept(GpsFix f, double? altitude) {
    lastFix = f;
    if (f.accuracy > maxAccuracy) {
      notifyListeners(); // se muestra "buscando señal GPS", pero no se guarda
      return;
    }
    final last = points.isEmpty ? null : points.last;
    // Quieto, el GPS "baila" unos metros: solo se guarda si te moviste o pasó un minuto
    if (last != null && last.segment == _segment) {
      final moved = haversine(last.lat, last.lng, f.lat, f.lng);
      final minMove = math.max(
        mode == RecordingMode.saver ? 15.0 : 4.0,
        f.accuracy * 0.5,
      );
      if (moved < minMove &&
          f.time.difference(last.time) < const Duration(minutes: 1)) {
        notifyListeners();
        return;
      }
    }
    final p = TrackPoint(
      time: f.time,
      lng: f.lng,
      lat: f.lat,
      altitude: altitude,
      accuracy: f.accuracy,
      speed: f.speed,
      segment: _segment,
    );
    points.add(p);
    _pending.add(p);
    stats.add(p);
    if (route != null) progress = RouteProgress.of(route!, f.lng, f.lat);
    notifyListeners();
  }

  Future<void> _persist() async {
    final t = track;
    if (t == null) return;
    final batch = List.of(_pending);
    _pending.clear();
    await store.appendPoints(t.id, batch);
    t.summary = stats.summary;
    await store.save();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _flush?.cancel();
    super.dispose();
  }
}
