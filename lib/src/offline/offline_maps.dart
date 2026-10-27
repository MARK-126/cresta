import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../storage/json_store.dart';
import 'map_sources.dart';
import 'offline_region.dart';
import 'region_downloader.dart';
import 'tile_math.dart';
import 'tile_store.dart';

enum NetworkKind { none, wifi, mobile }

/// Zonas de mapas descargadas y su cola de descargas (una a la vez).
class OfflineMaps extends ChangeNotifier {
  OfflineMaps({
    required this.store,
    required this.downloader,
    required this._regionsFile,
    required this._settingsFile,
    Stream<NetworkKind>? networkChanges,
    this.network = NetworkKind.wifi,
    this.onDownloadingChanged,
  }) {
    _netSub = networkChanges?.listen(_onNetwork);
  }

  final TileStore store;
  final RegionDownloader downloader;
  final JsonStore _regionsFile;
  final JsonStore _settingsFile;

  /// Para mantener la pantalla encendida mientras se descarga.
  final void Function(bool downloading)? onDownloadingChanged;

  StreamSubscription<NetworkKind>? _netSub;
  final _regions = <OfflineRegion>[];
  OfflineRegion? _active;

  /// Hay una zona descargándose ahora (mantiene la pantalla encendida).
  bool get isDownloading => _active != null;
  CancelToken? _token;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);

  NetworkKind network;
  bool wifiOnly = true;

  List<OfflineRegion> get regions => List.unmodifiable(_regions);
  OfflineRegion? get active => _active;
  OfflineRegion? byId(String id) =>
      _regions.where((r) => r.id == id).firstOrNull;

  /// Si ahora se puede descargar y, si no, por qué.
  String? get blockedReason => switch (network) {
    NetworkKind.none => 'Sin conexión',
    NetworkKind.mobile when wifiOnly => 'Esperando Wi-Fi',
    _ => null,
  };

  Future<void> load() async {
    final saved = await _regionsFile.read();
    if (saved is List) {
      _regions
        ..clear()
        ..addAll([
          for (final r in saved)
            OfflineRegion.fromJson(r as Map<String, dynamic>),
        ]);
    }
    final settings = await _settingsFile.read();
    if (settings is Map) wifiOnly = settings['wifiOnly'] as bool? ?? true;
    notifyListeners();
  }

  Future<OfflineRegion> add({
    required String name,
    required BBox bbox,
    required DetailLevel detail,
    required Set<MapSource> sources,
  }) async {
    final region = OfflineRegion(
      id: '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${math.Random().nextInt(1 << 20).toRadixString(36)}',
      name: name,
      bbox: bbox,
      detail: detail,
      sources: {...sources, MapSource.dem},
    );
    _regions.add(region);
    await _save();
    notifyListeners();
    unawaited(_pump());
    return region;
  }

  /// Registra una zona que ya está en disco (el paquete de ejemplo).
  Future<void> addExisting(OfflineRegion region) async {
    if (byId(region.id) != null) return;
    _regions.add(region);
    await _save();
    notifyListeners();
  }

  void pause(String id) {
    final r = byId(id);
    if (r == null) return;
    if (_active?.id == id) _token?.cancel();
    r
      ..status = RegionStatus.paused
      ..message = 'En pausa';
    _save();
    notifyListeners();
  }

  void resume(String id) {
    final r = byId(id);
    if (r == null || r.isComplete) return;
    r
      ..status = RegionStatus.queued
      ..message = null;
    _save();
    notifyListeners();
    _pump();
  }

  Future<void> rename(String id, String name) async {
    byId(id)?.name = name;
    await _save();
    notifyListeners();
  }

  /// Borra la zona y los mosaicos que ninguna otra zona usa. Devuelve los bytes liberados.
  Future<int> remove(String id) async {
    if (_active?.id == id) _token?.cancel();
    _regions.removeWhere((r) => r.id == id);
    await _save();
    notifyListeners();
    return prune();
  }

  Future<void> setWifiOnly(bool value) async {
    wifiOnly = value;
    await _settingsFile.write({'wifiOnly': value});
    notifyListeners();
    unawaited(_pump());
  }

  /// Elimina del disco los mosaicos que no pertenecen a ninguna zona.
  Future<int> prune() async {
    var freed = 0;
    for (final source in MapSource.values) {
      final dir = Directory('${store.root.path}/${source.name}');
      if (!await dir.exists()) continue;
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        if (e is! File) continue;
        final parts = e.path.substring(dir.path.length + 1).split('/');
        if (parts.length != 3) continue;
        final z = int.tryParse(parts[0]),
            x = int.tryParse(parts[1]),
            y = int.tryParse(parts[2]);
        if (z == null || x == null || y == null) {
          continue; // p. ej. un .part a medias
        }
        if (_regions.any((r) => r.covers(source, z, x, y))) continue;
        freed += await e.length();
        await e.delete();
      }
    }
    return freed;
  }

  void _onNetwork(NetworkKind kind) {
    network = kind;
    final reason = blockedReason;
    if (reason != null && _active != null) {
      _token?.cancel();
      _active!
        ..status = RegionStatus.queued
        ..message = reason;
    }
    notifyListeners();
    if (reason == null) unawaited(_pump());
  }

  Future<void> _pump() async {
    if (_active != null) return;
    final next = _regions
        .where((r) => r.status == RegionStatus.queued)
        .firstOrNull;
    if (next == null) return;
    final reason = blockedReason;
    if (reason != null) {
      for (final r in _regions.where((r) => r.status == RegionStatus.queued)) {
        r.message = reason;
      }
      notifyListeners();
      return;
    }

    final token = CancelToken();
    _active = next;
    _token = token;
    next
      ..status = RegionStatus.downloading
      ..message = null;
    onDownloadingChanged?.call(true);
    notifyListeners();

    final result = await downloader.run(
      next,
      token: token,
      onProgress: (p) {
        next
          ..doneTiles = p.done
          ..bytes = p.bytes
          ..updatedAt = DateTime.now();
        notifyListeners();
        if (DateTime.now().difference(_lastSave) > const Duration(seconds: 3)) {
          _save();
        }
      },
    );

    if (_regions.contains(next)) {
      switch (result.outcome) {
        case DownloadOutcome.complete:
          next
            ..status = RegionStatus.complete
            ..doneTiles = next.totalTiles
            ..message = null;
        case DownloadOutcome.cancelled:
          if (next.status == RegionStatus.downloading) {
            next.status = RegionStatus.paused;
          }
        case DownloadOutcome.offline:
          next
            ..status = RegionStatus.queued
            ..message = result.message;
        case DownloadOutcome.failed:
          next
            ..status = RegionStatus.failed
            ..message = result.message;
      }
      await _save();
    }
    // Se libera al final, con el resultado ya guardado
    _active = null;
    _token = null;
    onDownloadingChanged?.call(false);
    notifyListeners();
    if (result.outcome == DownloadOutcome.offline) {
      // La red puede volver sin que el sistema avise (p. ej. Wi-Fi inestable): reintenta solo
      _retry?.cancel();
      _retry = Timer(retryOfflineAfter, () => unawaited(_pump()));
    } else {
      unawaited(_pump());
    }
  }

  Timer? _retry;

  @visibleForTesting
  Duration retryOfflineAfter = const Duration(seconds: 30);

  Future<void> _save() async {
    _lastSave = DateTime.now();
    await _regionsFile.write([for (final r in _regions) r.toJson()]);
  }

  @override
  void dispose() {
    _token?.cancel();
    _retry?.cancel();
    _netSub?.cancel();
    super.dispose();
  }
}
