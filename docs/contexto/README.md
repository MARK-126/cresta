# Contexto del proyecto Cresta

Memoria del proyecto para retomar el trabajo en otra sesión o computadora **sin repetir lo ya hecho**:
qué se construyó, qué se probó y con qué resultado, qué se decidió y por qué, y qué falta.

## Cómo usar esta carpeta

**Al empezar una sesión**, leer en este orden:

1. Este archivo (qué quiere el usuario).
2. [`estado.md`](estado.md): qué existe hoy.
3. [`pendientes.md`](pendientes.md): qué sigue y qué falta probar.
4. [`pruebas.md`](pruebas.md) antes de probar algo: puede que ya esté probado, o que ya se sepa por qué falla.
5. [`entorno.md`](entorno.md) antes de compilar o conectar el teléfono.
6. [`decisiones.md`](decisiones.md) antes de cambiar algo de arquitectura o diseño.
7. [`funcionalidades.md`](funcionalidades.md): lista de lo que ya funciona, lo que queremos implementar
   y lo deseable a futuro.

**Al terminar una tarea** (antes del commit final de la rama):

- `estado.md`: agregar lo construido (fase, archivos clave, rama y commit).
- `pruebas.md`: una entrada por prueba hecha, **también las que fallaron**: fecha, qué, cómo, resultado, corrección.
- `decisiones.md`: decisiones nuevas y errores resueltos (síntoma → causa → solución).
- `pendientes.md`: quitar lo resuelto y agregar lo nuevo.
- `funcionalidades.md`: pasar lo terminado de "Por implementar" a "Ya funcionan".

Se escribe en español, breve y concreto, con fechas absolutas (no "ayer").

## Qué quiere el usuario

Una app **personal y gratuita** de montaña (senderismo, montañismo) que:

1. Muestre mapas en **2D y 3D**.
2. **Grabe el recorrido** con GPS, sin señal.
3. Permita **armar rutas**.
4. Antes de salir, **consultar el clima** y **guardar referencias**.
5. **Funcione sin conexión**: con Wi-Fi en casa se descargan los mapas de la zona elegida, en cualquier
   lugar del mundo (México, Andes…).

Teléfonos: iPhone y Android; el de pruebas es un **Samsung Galaxy S23 Ultra** (Android 16).
Diseño visual: sistema **"Andes Industrial"** de su proyecto de Google Stitch (ver `decisiones.md`).

Descartado por ahora: el backend para compartir la ubicación del grupo (en la montaña no hay señal). Si se
retoma: offline-first (cola local y sincronizar al haber señal) y, sin señal, radios LoRa con Meshtastic.

## Forma de trabajo acordada

- Una rama por fase (`feat/...`, `docs/...`). Antes de cada commit: `dart format lib test`,
  `flutter analyze` sin problemas y `flutter test` en verde.
- Probar en el teléfono antes de dar algo por terminado, con capturas.
- Merge a `main` por avance directo (fast-forward), **solo cuando el usuario lo aprueba**.
- No usar los datos reales del usuario (su expedición "Vallecitos", su perfil) para probar: usar la
  expedición de ejemplo y dejar todo como estaba.
