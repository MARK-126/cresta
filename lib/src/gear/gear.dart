import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../storage/json_store.dart';

enum GearCategory {
  clothing('Ropa'),
  technical('Equipo técnico'),
  camp('Campamento'),
  navigation('Navegación y comunicación'),
  safety('Botiquín y seguridad'),
  food('Comida y agua'),
  other('Otros');

  const GearCategory(this.label);
  final String label;
}

/// Un objeto de la lista de equipo de una expedición.
class GearItem {
  GearItem({
    String? id,
    required this.name,
    required this.category,
    this.grams,
    this.packed = false,
  }) : id =
           id ??
           '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${math.Random().nextInt(1 << 16).toRadixString(36)}';

  factory GearItem.fromJson(Map<String, dynamic> j) => GearItem(
    id: j['id'] as String,
    name: j['name'] as String,
    category:
        GearCategory.values.asNameMap()[j['category']] ?? GearCategory.other,
    grams: j['grams'] as int?,
    packed: j['packed'] as bool? ?? false,
  );

  final String id;
  final String name;
  final GearCategory category;

  /// Peso en gramos (opcional): sirve para saber cuánto cargas.
  final int? grams;
  final bool packed;

  GearItem copyWith({
    String? name,
    GearCategory? category,
    int? grams,
    bool clearGrams = false,
    bool? packed,
  }) => GearItem(
    id: id,
    name: name ?? this.name,
    category: category ?? this.category,
    grams: clearGrams ? null : (grams ?? this.grams),
    packed: packed ?? this.packed,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'grams': grams,
    'packed': packed,
  };
}

/// Plantillas para no empezar la lista en blanco. Pesos aproximados de equipo común.
enum GearTemplate {
  dayHike('Senderismo de un día'),
  alpineDay('Alta montaña, un día'),
  alpineCamp('Alta montaña con campamento');

  const GearTemplate(this.label);
  final String label;

  List<GearItem> items() {
    GearItem i(String name, GearCategory c, [int? g]) =>
        GearItem(name: name, category: c, grams: g);
    const clo = GearCategory.clothing,
        tec = GearCategory.technical,
        cmp = GearCategory.camp,
        nav = GearCategory.navigation,
        saf = GearCategory.safety,
        fod = GearCategory.food;
    final base = [
      i('Mochila', GearCategory.other, 1100),
      i('Chamarra impermeable', clo, 350),
      i('Capa térmica (polar o pluma)', clo, 400),
      i('Gorro y guantes', clo, 150),
      i('Lentes de sol', clo, 30),
      i('Bloqueador y protector labial', saf, 80),
      i('Botiquín', saf, 250),
      i('Lámpara frontal y pilas', nav, 90),
      i('Teléfono con mapas descargados', nav, 220),
      i('Batería externa', nav, 200),
      i('Agua (2 L)', fod, 2000),
      i('Comida y botanas', fod, 500),
    ];
    final alpine = [
      i('Botas de alta montaña', clo, 2000),
      i('Primera capa térmica', clo, 250),
      i('Chamarra de pluma', clo, 450),
      i('Guantes gruesos', clo, 200),
      i('Polainas', clo, 250),
      i('Crampones', tec, 900),
      i('Piolet', tec, 450),
      i('Casco', tec, 350),
      i('Arnés', tec, 400),
      i('Bastones', tec, 500),
      i('Termo con bebida caliente', fod, 600),
      i('Manta térmica', saf, 60),
    ];
    final camp = [
      i('Tienda', cmp, 2200),
      i('Bolsa de dormir', cmp, 1400),
      i('Aislante', cmp, 450),
      i('Estufa y gas', cmp, 450),
      i('Olla y cubiertos', cmp, 300),
      i('Comida del campamento', fod, 1200),
    ];
    return switch (this) {
      GearTemplate.dayHike => base,
      GearTemplate.alpineDay => [...base, ...alpine],
      GearTemplate.alpineCamp => [...base, ...alpine, ...camp],
    };
  }
}

/// Listas de equipo por expedición (`gear.json`).
class GearStore extends ChangeNotifier {
  GearStore(this.file);

  final JsonStore file;
  final _lists = <String, List<GearItem>>{};

  List<GearItem> forExpedition(String id) =>
      List.unmodifiable(_lists[id] ?? const []);

  Future<void> load() async {
    final v = await file.read();
    if (v is Map) {
      for (final e in v.entries) {
        _lists[e.key as String] = [
          for (final i in e.value as List)
            GearItem.fromJson(i as Map<String, dynamic>),
        ];
      }
    }
    notifyListeners();
  }

  Future<void> _set(String id, List<GearItem> items) async {
    _lists[id] = items;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() => file.write({
    for (final e in _lists.entries)
      e.key: [for (final i in e.value) i.toJson()],
  });

  Future<void> add(String expeditionId, GearItem item) =>
      _set(expeditionId, [...forExpedition(expeditionId), item]);

  /// Agrega lo de la plantilla que todavía no esté en la lista (por nombre).
  Future<int> addTemplate(String expeditionId, GearTemplate t) async {
    final current = forExpedition(expeditionId);
    final names = current.map((i) => i.name.toLowerCase()).toSet();
    final fresh = t
        .items()
        .where((i) => names.add(i.name.toLowerCase()))
        .toList();
    await _set(expeditionId, [...current, ...fresh]);
    return fresh.length;
  }

  Future<void> update(String expeditionId, GearItem item) => _set(
    expeditionId,
    [for (final i in forExpedition(expeditionId)) i.id == item.id ? item : i],
  );

  Future<void> remove(String expeditionId, String itemId) =>
      _set(expeditionId, [
        for (final i in forExpedition(expeditionId))
          if (i.id != itemId) i,
      ]);

  /// Para reutilizar la lista en otra salida.
  Future<void> unpackAll(String expeditionId) => _set(expeditionId, [
    for (final i in forExpedition(expeditionId)) i.copyWith(packed: false),
  ]);

  Future<void> deleteExpedition(String expeditionId) async {
    if (_lists.remove(expeditionId) == null) return;
    notifyListeners();
    await _persist();
  }
}

/// Peso total en gramos de los objetos con peso.
int totalGrams(Iterable<GearItem> items) =>
    items.fold(0, (s, i) => s + (i.grams ?? 0));
