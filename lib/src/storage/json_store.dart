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

  Future<void> write(Object? value) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      const JsonEncoder.withIndent(' ').convert(value),
      flush: true,
    );
    await tmp.rename(file.path);
  }
}
