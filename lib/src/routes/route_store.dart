import 'package:flutter/foundation.dart';

import '../storage/json_store.dart';
import 'planned_route.dart';

/// Rutas planeadas o importadas, una por expedición, guardadas en el teléfono.
class RouteStore extends ChangeNotifier {
  RouteStore(this._file);

  final JsonStore _file;
  final _routes = <String, PlannedRoute>{};

  PlannedRoute? forExpedition(String expeditionId) => _routes[expeditionId];

  Future<void> load() async {
    final saved = await _file.read();
    if (saved is Map) {
      _routes.clear();
      for (final e in saved.entries) {
        try {
          _routes[e.key as String] = PlannedRoute.fromJson(
            e.value as Map<String, dynamic>,
          );
        } catch (err) {
          // Una ruta dañada no debe impedir abrir la app ni borrar las demás
          debugPrint('RouteStore: ruta ilegible de ${e.key}: $err');
        }
      }
    }
    notifyListeners();
  }

  Future<void> save(String expeditionId, PlannedRoute route) async {
    _routes[expeditionId] = route;
    notifyListeners();
    await _persist();
  }

  Future<void> delete(String expeditionId) async {
    if (_routes.remove(expeditionId) == null) return;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() =>
      _file.write({for (final e in _routes.entries) e.key: e.value.toJson()});
}
