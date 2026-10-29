import 'dart:io';

import 'package:flutter/foundation.dart';

import '../storage/json_store.dart';
import 'planned_route.dart';

/// Rutas planeadas o importadas, guardadas en el teléfono. Cada una tiene su propio id y puede
/// estar ligada a una expedición o existir sola.
///
/// Formato del archivo: `{"version": 2, "routes": [...]}`. El formato anterior era un mapa
/// `expedición → ruta` (una por expedición); se migra al abrir y queda un respaldo
/// `routes.json.v1.bak`.
class RouteStore extends ChangeNotifier {
  RouteStore(this._file);

  static const _version = 2;

  final JsonStore _file;

  /// Por id, en el orden en que se guardaron.
  final _routes = <String, PlannedRoute>{};

  List<PlannedRoute> get all => List.unmodifiable(_routes.values);

  PlannedRoute? byId(String id) => _routes[id];

  /// Las rutas ligadas a una expedición.
  List<PlannedRoute> of(String expeditionId) => [
    for (final r in _routes.values)
      if (r.expeditionId == expeditionId) r,
  ];

  /// La ruta de la expedición (las pantallas actuales manejan una por expedición): la más antigua.
  PlannedRoute? forExpedition(String expeditionId) =>
      of(expeditionId).firstOrNull;

  Future<void> load() async {
    final saved = await _file.read();
    _routes.clear();
    var legacy = false;
    if (saved is Map && saved['version'] == _version) {
      for (final e in saved['routes'] as List? ?? const []) {
        _add(() => PlannedRoute.fromJson(e as Map<String, dynamic>), '$e');
      }
    } else if (saved is Map) {
      legacy = true;
      for (final e in saved.entries) {
        _add(
          () => PlannedRoute.fromJson(
            e.value as Map<String, dynamic>,
            legacyExpeditionId: e.key as String,
          ),
          '${e.key}',
        );
      }
    }
    notifyListeners();
    if (legacy) await _migrate();
  }

  void _add(PlannedRoute Function() read, String what) {
    try {
      final r = read();
      _routes[r.id] = r;
    } catch (err) {
      // Una ruta dañada no debe impedir abrir la app ni borrar las demás
      debugPrint('RouteStore: ruta ilegible ($what): $err');
    }
  }

  /// Reescribe en el formato nuevo, pero solo si antes quedó el respaldo del archivo anterior
  /// (las rutas ilegibles no pasan a la versión nueva y así no se pierden del todo).
  Future<void> _migrate() async {
    try {
      final backup = File('${_file.file.path}.v1.bak');
      if (!await backup.exists()) await _file.file.copy(backup.path);
    } catch (err) {
      debugPrint('RouteStore: sin respaldo, no se migra: $err');
      return;
    }
    await _persist();
  }

  /// Guarda la ruta; si ya existe una con ese id, la reemplaza.
  Future<void> save(PlannedRoute route) async {
    _routes[route.id] = route;
    notifyListeners();
    await _persist();
  }

  Future<void> delete(String id) async {
    if (_routes.remove(id) == null) return;
    notifyListeners();
    await _persist();
  }

  /// Borra todas las rutas de una expedición.
  Future<void> deleteOf(String expeditionId) async {
    final before = _routes.length;
    _routes.removeWhere((_, r) => r.expeditionId == expeditionId);
    if (_routes.length == before) return;
    notifyListeners();
    await _persist();
  }

  /// Deja [route] como la ruta de la expedición, quitando las que tenía.
  Future<void> replaceOf(String expeditionId, PlannedRoute route) async {
    _routes.removeWhere((_, r) => r.expeditionId == expeditionId);
    final linked = route.linkedTo(expeditionId);
    _routes[linked.id] = linked;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() => _file.write({
    'version': _version,
    'routes': [for (final r in _routes.values) r.toJson()],
  });
}
