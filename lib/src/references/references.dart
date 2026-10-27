import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../storage/json_store.dart';

enum ReferenceKind { file, link, phone }

/// Algo útil guardado con la expedición: un archivo (foto, PDF), un enlace o un teléfono.
class Reference {
  Reference({
    String? id,
    required this.kind,
    required this.title,
    required this.value,
    DateTime? addedAt,
  }) : id =
           id ??
           '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${math.Random().nextInt(1 << 16).toRadixString(36)}',
       addedAt = addedAt ?? DateTime.now();

  factory Reference.fromJson(Map<String, dynamic> j) => Reference(
    id: j['id'] as String,
    kind: ReferenceKind.values.asNameMap()[j['kind']] ?? ReferenceKind.link,
    title: j['title'] as String,
    value: j['value'] as String,
    addedAt: DateTime.tryParse('${j['addedAt']}'),
  );

  final String id;
  final ReferenceKind kind;
  final String title;

  /// Archivo: nombre del archivo dentro de la carpeta de la expedición.
  /// Enlace: la URL. Teléfono: el número.
  final String value;
  final DateTime addedAt;

  String get extension {
    final dot = value.lastIndexOf('.');
    return dot < 0 ? '' : value.substring(dot + 1).toLowerCase();
  }

  bool get isImage =>
      kind == ReferenceKind.file &&
      const {'jpg', 'jpeg', 'png', 'webp', 'heic', 'gif'}.contains(extension);
  bool get isPdf => kind == ReferenceKind.file && extension == 'pdf';

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'value': value,
    'addedAt': addedAt.toIso8601String(),
  };
}

/// Referencias por expedición (`references.json`) y sus archivos en `references/<expedición>/`.
class ReferenceStore extends ChangeNotifier {
  ReferenceStore(this.file, this.dir);

  final JsonStore file;

  /// Carpeta donde se copian los archivos: siguen disponibles aunque se borre el original.
  final Directory dir;
  final _refs = <String, List<Reference>>{};

  List<Reference> forExpedition(String id) =>
      List.unmodifiable(_refs[id] ?? const []);

  File fileOf(String expeditionId, Reference r) =>
      File('${dir.path}/$expeditionId/${r.value}');

  Future<void> load() async {
    final v = await file.read();
    if (v is Map) {
      for (final e in v.entries) {
        _refs[e.key as String] = [
          for (final r in e.value as List)
            Reference.fromJson(r as Map<String, dynamic>),
        ];
      }
    }
    notifyListeners();
  }

  Future<void> _persist() => file.write({
    for (final e in _refs.entries) e.key: [for (final r in e.value) r.toJson()],
  });

  Future<void> _add(String expeditionId, Reference r) async {
    _refs[expeditionId] = [...forExpedition(expeditionId), r];
    notifyListeners();
    await _persist();
  }

  /// Copia un archivo a la carpeta de la expedición y lo agrega.
  Future<Reference> addFile(
    String expeditionId, {
    required String title,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final dot = fileName.lastIndexOf('.');
    final ext = dot < 0 ? '' : fileName.substring(dot).toLowerCase();
    final r = Reference(kind: ReferenceKind.file, title: title, value: '');
    final stored = Reference(
      id: r.id,
      kind: ReferenceKind.file,
      title: title,
      value: '${r.id}$ext',
      addedAt: r.addedAt,
    );
    final f = fileOf(expeditionId, stored);
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes, flush: true);
    await _add(expeditionId, stored);
    return stored;
  }

  Future<Reference> addLink(
    String expeditionId,
    String title,
    String url,
  ) async {
    final fixed = url.contains('://') ? url : 'https://$url';
    final r = Reference(kind: ReferenceKind.link, title: title, value: fixed);
    await _add(expeditionId, r);
    return r;
  }

  Future<Reference> addPhone(
    String expeditionId,
    String title,
    String phone,
  ) async {
    final r = Reference(kind: ReferenceKind.phone, title: title, value: phone);
    await _add(expeditionId, r);
    return r;
  }

  Future<void> rename(String expeditionId, Reference r, String title) async {
    _refs[expeditionId] = [
      for (final x in forExpedition(expeditionId))
        x.id == r.id
            ? Reference(
                id: x.id,
                kind: x.kind,
                title: title,
                value: x.value,
                addedAt: x.addedAt,
              )
            : x,
    ];
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String expeditionId, Reference r) async {
    _refs[expeditionId] = [
      for (final x in forExpedition(expeditionId))
        if (x.id != r.id) x,
    ];
    notifyListeners();
    await _persist();
    if (r.kind == ReferenceKind.file) {
      final f = fileOf(expeditionId, r);
      if (await f.exists()) await f.delete();
    }
  }

  /// Borra todas las referencias de una expedición, archivos incluidos.
  Future<void> deleteExpedition(String expeditionId) async {
    _refs.remove(expeditionId);
    notifyListeners();
    await _persist();
    final folder = Directory('${dir.path}/$expeditionId');
    if (await folder.exists()) await folder.delete(recursive: true);
  }
}
