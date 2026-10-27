# Cresta: instrucciones para Claude

App Flutter (iOS y Android) de mapas 3D para montañismo, **offline-first**: el usuario prepara la expedición
con Wi-Fi y en la montaña todo funciona sin señal. Uso personal y gratuito.

**`docs/contexto/` es la memoria del proyecto.** Antes de trabajar, lee `docs/contexto/README.md` y sigue
su orden de lectura (estado, pendientes, pruebas, entorno, decisiones). Antes de probar algo, revisa
`pruebas.md`: puede que ya esté probado o que ya se sepa por qué falla.

**Al terminar cada tarea, actualiza la carpeta** en la misma rama, antes del commit final:
`estado.md` (lo construido), `pruebas.md` (cada prueba, también las fallidas, con resultado y corrección),
`decisiones.md` (decisiones y errores resueltos), `pendientes.md` y `funcionalidades.md` (mover lo
terminado a "Ya funcionan").

## Idioma y estilo

- Todo en **español** (México): textos de la app, comentarios, mensajes de commit y respuestas al usuario.
- Números con formato México: `5,207 m`, `12.1 km` (ver `lib/src/ui/format.dart`).
- Código formateado con `dart format` (ancho 80, el predeterminado). Sin advertencias en `flutter analyze`.
- Comentarios breves que explican el *porqué*, en español, como en el resto del código.

## Comandos

```bash
flutter pub get
flutter analyze
flutter test
flutter build ios --simulator --debug   # solo en Mac
flutter build apk --debug               # requiere SDK de Android
```

Antes de cada commit: `dart format lib test`, `flutter analyze` sin problemas y `flutter test` en verde.

## Reglas del proyecto

- **No usar Esri ni otras fuentes que prohíban guardar mosaicos.** Las fuentes están en
  `lib/src/offline/map_sources.dart` (OpenFreeMap, Sentinel-2 de EOX, Terrain Tiles de AWS).
- El **User-Agent debe ser ASCII** (`userAgent` en `map_sources.dart`); con acentos fallan todas las descargas.
- El mapa es **MapLibre GL JS dentro de un WebView** (`assets/web/map.js`), no el plugin nativo: MapLibre
  Native aún no tiene terreno 3D. Toda comunicación pasa por `lib/src/map/map_bridge.dart`.
- Assets de Flutter **no son recursivos**: cada carpeta nueva bajo `assets/` debe declararse en `pubspec.yaml`.
- Escrituras de JSON con `JsonStore` (se serializan para no pisarse).
- Datos de protección civil, grupo y semáforo son **de demostración**; nunca presentarlos como oficiales.
- Ramas por fase (`feat/...`); commits con la línea `Co-Authored-By` que indique el entorno.
- **UI "Andes Industrial", solo tema oscuro:** colores de `Andes` y componentes de `lib/src/ui/theme.dart`
  (`TonalCard`, `Figure`, `GlowButton`, `Glass`). Nada de bordes de 1 px, sombras ni colores sueltos.
  Detalles en `docs/contexto/decisiones.md`.
