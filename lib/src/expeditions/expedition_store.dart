import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../offline/offline_maps.dart';
import '../storage/json_store.dart';
import 'expedition.dart';

/// Lista de expediciones, guardada en el teléfono.
class ExpeditionStore extends ChangeNotifier {
  ExpeditionStore(this._file, this.maps) {
    maps.addListener(
      notifyListeners,
    ); // el estado de cada expedición depende de sus descargas
  }

  final JsonStore _file;
  final OfflineMaps maps;
  final _items = <Expedition>[];

  /// Próximas primero; las que no tienen fecha, al final.
  List<Expedition> get all => [..._items]
    ..sort((a, b) {
      if (a.date == null && b.date == null) {
        return b.createdAt.compareTo(a.createdAt);
      }
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return a.date!.compareTo(b.date!);
    });

  Expedition? byId(String id) => _items.where((e) => e.id == id).firstOrNull;

  ExpeditionStatus statusOf(Expedition e) =>
      ExpeditionStatus([for (final id in e.regionIds) ?maps.byId(id)]);

  /// Expediciones que usan una zona (para avisar antes de borrarla).
  List<Expedition> usingRegion(String regionId) =>
      _items.where((e) => e.regionIds.contains(regionId)).toList();

  Future<void> load() async {
    final saved = await _file.read();
    if (saved is List) {
      _items
        ..clear()
        ..addAll([
          for (final e in saved) Expedition.fromJson(e as Map<String, dynamic>),
        ]);
    }
    notifyListeners();
  }

  Future<Expedition> create({
    required String name,
    DateTime? date,
    String notes = '',
  }) async {
    final e = Expedition(
      id: '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${math.Random().nextInt(1 << 20).toRadixString(36)}',
      name: name,
      date: date,
      notes: notes,
    );
    _items.add(e);
    await _save();
    return e;
  }

  Future<void> addExisting(Expedition e) async {
    if (byId(e.id) != null) return;
    _items.add(e);
    await _save();
  }

  Future<void> update(
    Expedition e, {
    String? name,
    DateTime? date,
    bool clearDate = false,
    String? notes,
  }) async {
    if (name != null) e.name = name;
    if (date != null || clearDate) e.date = date;
    if (notes != null) e.notes = notes;
    await _save();
  }

  Future<void> attachRegion(Expedition e, String regionId) async {
    if (!e.regionIds.contains(regionId)) e.regionIds.add(regionId);
    await _save();
  }

  /// Quita la zona de la expedición; si ninguna otra la usa, también borra sus mapas.
  Future<void> detachRegion(Expedition e, String regionId) async {
    e.regionIds.remove(regionId);
    await _save();
    if (usingRegion(regionId).isEmpty) await maps.remove(regionId);
  }

  /// Borra la expedición y, si [deleteMaps], las zonas que solo ella usaba.
  Future<void> delete(Expedition e, {required bool deleteMaps}) async {
    _items.remove(e);
    await _save();
    if (deleteMaps) {
      for (final id in e.regionIds) {
        if (usingRegion(id).isEmpty) await maps.remove(id);
      }
    }
  }

  Future<void> _save() async {
    await _file.write([for (final e in _items) e.toJson()]);
    notifyListeners();
  }

  @override
  void dispose() {
    maps.removeListener(notifyListeners);
    super.dispose();
  }
}
