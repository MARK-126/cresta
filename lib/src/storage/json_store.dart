import 'dart:convert';
import 'dart:io';

/// Guarda un valor JSON en un archivo. Escribe a un temporal y renombra,
/// para no corromper los datos si la app se cierra a mitad de una escritura.
class JsonStore {
  JsonStore(this.file);

  final File file;

  Future<Object?> read() async {
    if (!await file.exists()) return null;
    try {
      return jsonDecode(await file.readAsString());
    } on FormatException {
      return null;
    }
  }

  Future<void> _last = Future.value();

  /// Las escrituras se hacen una tras otra: dos a la vez se pisarían el archivo temporal.
  Future<void> write(Object? value) {
    final encoded = const JsonEncoder.withIndent(' ').convert(value);
    return _last = _last.catchError((_) {}).then((_) => _write(encoded));
  }

  Future<void> _write(String encoded) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(encoded, flush: true);
    await tmp.rename(file.path);
  }
}
