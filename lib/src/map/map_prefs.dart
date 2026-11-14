import '../storage/json_store.dart';
import 'map_layers.dart';

/// Recuerda el mapa base elegido (en `map.json`). De inicio, Noche: el usuario lo prefirió al
/// claro (14 nov 2026).
class MapBaseStore {
  MapBaseStore(this._file);
  final JsonStore _file;
  MapBase _value = MapBase.night;

  MapBase get value => _value;

  Future<void> load() async {
    final saved = await _file.read();
    if (saved is Map<String, dynamic>) {
      _value = MapBase.values.asNameMap()[saved['base']] ?? _value;
    }
  }

  Future<void> save(MapBase b) async {
    if (b == _value) return;
    _value = b;
    await _file.write({'base': b.name});
  }
}
