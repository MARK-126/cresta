import '../storage/json_store.dart';

/// Una indicación que se muestra la primera vez que se usa una parte de la app.
class Tip {
  const Tip(this.id, this.title, this.points);
  final String id;
  final String title;

  /// Cada punto: (ícono por nombre, texto). El ícono lo resuelve la interfaz.
  final List<(String, String)> points;
}

/// Las indicaciones de la primera vez. Breves: lo que no es obvio al ver la pantalla.
abstract final class Tips {
  static const map = Tip('map', 'Explorar el mapa', [
    (
      'location',
      'Tu posición se ve en vivo. El botón de ubicación te centra y te sigue '
          'mientras caminas; al mover el mapa con el dedo deja de seguirte.',
    ),
    (
      'search',
      'La lupa busca cumbres, refugios, agua y pueblos en tus mapas '
          'descargados, sin señal.',
    ),
    (
      'layers',
      'Capas (abajo a la izquierda): satélite o topográfico, relieve, '
          'pendiente del terreno, zonas planas y tus mapas descargados.',
    ),
    (
      'record',
      'El botón rojo de abajo graba tu recorrido; "Ruta" traza una. Puedes '
          'bloquear la pantalla: sigue grabando.',
    ),
  ]);

  static const plan = Tip('plan', 'Trazar una ruta', [
    (
      'touch',
      'Toca el mapa para marcar el inicio, las paradas y el final. Cada tramo '
          'se ajusta a los senderos y calles de tus mapas.',
    ),
    (
      'search',
      'O escríbelo en el buscador de arriba: salida, paradas y destino, en '
          'orden. Busca en tus mapas y, con conexión, en todo el mundo.',
    ),
    (
      'terrain',
      'Donde no hay sendero, la ruta va a campo traviesa por la pendiente más '
          'suave, punteada: revísala en el terreno.',
    ),
    (
      'undo',
      'Deshacer quita el último punto. Al terminar, guarda la ruta para '
          'seguirla al grabar.',
    ),
  ]);

  static const record = Tip('record', 'Grabar tu recorrido', [
    (
      'lock',
      'Puedes bloquear la pantalla: la grabación sigue y verás una '
          'notificación fija de Cresta.',
    ),
    (
      'gps',
      'El GPS funciona sin señal, en modo avión también. Bajo techo o entre '
          'edificios tarda más en encontrar tu posición.',
    ),
    (
      'battery',
      'Si Android pregunta por la batería, toca Permitir: así no corta la '
          'grabación con la pantalla apagada.',
    ),
    (
      'back',
      'Arriba ves altitud, velocidad y distancia. Toca la tira de abajo para '
          'ver todo y "Volver al inicio por mi traza".',
    ),
  ]);
}

/// Recuerda qué indicaciones ya vio el usuario (en `tips.json`).
class TipStore {
  TipStore(this._file);
  final JsonStore _file;
  final _seen = <String>{};

  Future<void> load() async {
    final saved = await _file.read();
    if (saved is List) _seen.addAll(saved.whereType<String>());
  }

  bool seen(Tip t) => _seen.contains(t.id);

  Future<void> markSeen(Tip t) async {
    if (_seen.add(t.id)) await _file.write(_seen.toList());
  }

  /// Para volver a mostrarlas todas (desde el perfil).
  Future<void> reset() async {
    _seen.clear();
    await _file.write(const <String>[]);
  }
}
