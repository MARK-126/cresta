# Cresta

App móvil de mapas 3D para **montañismo y senderismo**, pensada para funcionar **sin señal**:
preparas la expedición en casa con Wi-Fi, descargas los mapas de la zona y en la montaña todo sigue
funcionando sin conexión.

## Qué hace hoy

### Fase 1: expediciones y mapas sin conexión

- **Expediciones:** nombre, fecha de salida, notas y una lista "Antes de salir" que dice si ya está lista para
  usarse sin conexión.
- **Descargar mapas por zona:** buscas el lugar (o mueves el mapa), encuadras la zona y eliges el detalle.
  La app muestra antes de bajar el tamaño aproximado y el área en km. Las descargas:
  - se reanudan donde quedaron si se corta la red o se cierra la app,
  - pueden limitarse a Wi-Fi (opción por defecto),
  - comparten mosaicos entre zonas que se traslapan, y al borrar una zona solo se libera lo que nadie más usa.
- **Mapas descargados:** espacio usado por zona, a qué expediciones pertenece y caché de navegación aparte.
- **Mapa 2D/3D** de cualquier zona con tres bases: topográfico (senderos, brechas, cumbres con altitud, ríos,
  bosque), satélite y relieve. Las **curvas de nivel se calculan en el teléfono** a partir del relieve,
  así que funcionan en cualquier zona descargada sin bajar nada extra.
- **Ejemplo incluido:** Iztaccíhuatl por La Arista del Sol, con sus mapas dentro de la app, la ruta real de
  OpenStreetMap, perfil de elevación, vuelo 3D y el modo de protección civil de demostración.

### Fase 2: grabar el recorrido

- **Grabar sin señal y con la pantalla apagada:** botón rojo en el mapa. En iOS usa la ubicación en segundo plano
  (indicador azul); en Android, un servicio en primer plano con notificación fija. Modo normal (un punto cada
  ~5 m) o ahorro de batería (~20 m).
- **En vivo:** distancia, tiempo en movimiento, altitud, subida y bajada, velocidad vertical (m/h), precisión del
  GPS y, si la expedición tiene ruta, cuánto falta (km y metros de subida) y aviso si te sales más de 80 m.
- **Hora límite de retorno** por expedición: aviso 30 min antes y alerta roja cuando pasa.
- **Altitud confiable:** se toma del relieve descargado (el mismo del 3D) en lugar de la del GPS, que salta
  ±15 m; si no hay relieve de esa zona, se usa la del GPS. El desnivel ignora variaciones menores a 5 m.
- **A prueba de cierres:** los puntos se guardan en disco cada 10 s; si la app se cierra o se acaba la batería,
  el recorrido se recupera en pausa al volver a abrirla.
- **Pausar y reanudar:** cada reanudación empieza un tramo nuevo (no se une el hueco con una línea recta).
- **Recorridos guardados:** lista por expedición, detalle con cifras y perfil de elevación, ver en el mapa 3D
  y **exportar GPX** (Wikiloc, Strava, Garmin, Google Earth).

## Fuentes de mapas (libres, uso personal)

| Capa | Fuente | Licencia | Zoom máx. |
|---|---|---|---|
| Topográfico y senderos | OpenFreeMap (vectorial, datos OpenStreetMap) | ODbL / OpenMapTiles | 14 |
| Satélite | Sentinel-2 cloudless 2024 de EOX | CC BY-NC-SA 4.0 (**no comercial**) | 14 |
| Relieve 3D y curvas | Mapzen Terrain Tiles (AWS Open Data) | Abierta | 12 |
| Búsqueda de lugares | Nominatim (OpenStreetMap) | Política de uso: 1 búsqueda/s | — |

Si la app se vuelve comercial hay que cambiar el satélite (por ejemplo MapTiler con licencia offline).
Las URLs y zooms están en `lib/src/offline/map_sources.dart`.

## Arquitectura

```
Flutter (pantallas, expediciones, descargas, GPS)
   │  MapBridge: llamadas JS ⇄ eventos por el canal "CrestaBridge"
   ▼
WebView ── MapLibre GL JS 4.7.1 + maplibre-contour (assets/web)  ← terreno 3D y curvas
   │  http://127.0.0.1:<puerto>
   ▼
TileServer (Dart, solo loopback)
   1. zonas descargadas   (Application Support/tiles/<fuente>/<z>/<x>/<y>)
   2. caché de navegación (Caches/tiles; se puede borrar)
   3. red, si hay         (y lo guarda en la caché)
```

**¿Por qué un WebView y no el plugin nativo `maplibre_gl`?** MapLibre Native (iOS/Android) todavía no tiene
terreno 3D. MapLibre GL JS sí. Toda la comunicación con el mapa pasa por `lib/src/map/map_bridge.dart`, así que
cuando el SDK nativo lo soporte se puede cambiar el motor sin tocar las pantallas.

| Carpeta | Contenido |
|---|---|
| `lib/src/expeditions/` | Modelo de expedición, su estado sin conexión y su almacenamiento |
| `lib/src/offline/` | Zonas, cálculo de mosaicos, motor de descargas, almacén en disco, fuentes y paquete de ejemplo |
| `lib/src/tiles/` | Servidor local que alimenta al mapa |
| `lib/src/search/` | Búsqueda de lugares (Nominatim) |
| `lib/src/map/` | `MapBridge` y definición de capas |
| `lib/src/ui/` | Pantallas: expediciones, detalle, elegir zona, mapas descargados, mapa |
| `lib/src/tracking/` | Grabador, estadísticas, avance sobre la ruta, altitud del terreno, almacenamiento y GPX |
| `lib/src/data/`, `group/`, `location/` | Ruta de ejemplo, datos de protección civil, grupo simulado y GPS |
| `assets/web/` | Página del mapa, MapLibre, maplibre-contour y tipografías del mapa |
| `assets/packs/izta_popo.zip` | Mapas del ejemplo (relieve, satélite y topográfico) |
| `tool/` | Scripts con los que se generaron la ruta y el paquete de ejemplo |

Todo se guarda en el teléfono como JSON (`expeditions.json`, `regions.json`, `settings.json`); no hay
cuenta ni servidor propio.

## Correr la app

Requisitos: Flutter 3.47 o superior, Xcode (iOS) y/o Android Studio (Android).

```bash
flutter pub get
```

```bash
flutter run
```

Pruebas y análisis:

```bash
flutter test
```

```bash
flutter analyze
```

## Limitaciones conocidas

- Las descargas avanzan con la app abierta (la pantalla se mantiene encendida mientras descarga). Si se cierra,
  la zona queda en pausa y se reanuda al volver.
- Límite de 40,000 mosaicos por zona (unos 100 × 100 km en detalle) para no abusar de los servicios gratuitos.
- Probado en el simulador de iPhone (con caminatas simuladas por la ruta). La grabación con la pantalla bloqueada
  y la altitud real del GPS solo se pueden comprobar en un teléfono físico. Android compila desde el mismo código,
  pero falta probarlo en un equipo.

## Siguientes fases

3. Planificador de rutas: dibujar sobre el mapa, ajustar a senderos, importar GPX/KML.
4. Clima por altitud guardado con la expedición, referencias (fotos, PDFs, contactos) y lista de equipo.

## Créditos

Mapa © OpenMapTiles, © colaboradores de OpenStreetMap (ODbL), servido por OpenFreeMap.
Satélite: Sentinel-2 cloudless 2024 de EOX IT Services GmbH (contiene datos Copernicus Sentinel modificados).
Relieve: Mapzen Terrain Tiles (AWS Open Data). MapLibre GL JS y maplibre-contour (licencia BSD-3, `assets/web/vendor`).
Tipografía del mapa: Noto Sans (SIL Open Font License).
