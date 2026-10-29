# Estado: qué está hecho

Actualizado: 28 oct 2026 · `main` con SOS probado, aviso al salir del perfil, notificación de hora límite y mapa libre.

## Fases

| Fase | Contenido | Rama | Último commit |
|---|---|---|---|
| 0 | Prototipo: mapa 3D en WebView, ejemplo Izta–Popo, modo protección civil (demostración) | `main` | `69e3203` |
| 1 | Expediciones, descarga de mapas por zona, gestor de mapas, mapa topográfico propio | `feat/expediciones-mapas-offline` | `27668a0` |
| 2 | Grabar recorrido (segundo plano, estadísticas, hora límite, salida de ruta, GPX) | `feat/grabar-recorrido` | `0f9de30` |
| UI | Rediseño "Andes Industrial", pestañas, bitácora, resumen, splash, ícono | `feat/rediseno-ui`, `feat/icono-y-contexto` | `8ed84eb` |
| 3 | Planificador de rutas, detalle de ruta, importar/exportar GPX y KML | `feat/planificador-rutas` | `abe6e0f` |
| SOS | Perfil de emergencia y pantalla SOS | `feat/perfil-sos` | `f54c534` |
| 4 | Clima por altitud, lista de equipo, referencias | `feat/preparacion` | `f2496bf` |
| Fix | Mapas del ejemplo, relieve interpolado (pendientes), umbral de nieve, graphify con Gemini | `fix/ejemplo-pendiente-nieve` | `7b7c2dc` |
| Mejoras | Sangre con palabras en el SMS, aviso al salir del perfil, notificación de hora límite, mapa libre | `fix/sms-sangre`, `fix/perfil-sin-guardar`, `feat/notificacion-hora-limite`, `feat/mapa-libre` | `0bf2400` |
| Rutas A | Rutas como entidades propias (id, expedición opcional), formato 2 con migración y respaldo | `feat/rutas-propias` | `9d690f4` |
| Rutas B | Trazar en el mapa libre y guardar sola o en una expedición; rutas guardadas en el inicio | `feat/rutas-b-mapa-libre` | (ver `git log`) |
| Rutas C | Clima por ruta y descarga de la zona de mapa de la ruta | `feat/rutas-c-clima-mapa` | (ver `git log`) |
| Rutas D | Comparar rutas: cifras, perfiles superpuestos y mapa | `feat/rutas-d-comparar` | `c3f01e7` |
| Seguridad | Tramos sin sendero punteados y con etiqueta, pendientes de más de 40 % marcadas, aviso en el detalle | `feat/tramos-sin-sendero` | `1d26731` |
| Fase 5 · sol | Amanecer, atardecer y hora límite sugerida, sin conexión | `feat/luz-del-dia` | (este commit) |

## Por área

### Mapa y mapas sin conexión
- MapLibre GL JS 4.7.1 en un WebView (`assets/web/map.js`), controlado desde `lib/src/map/map_bridge.dart`.
- Servidor local `lib/src/tiles/tile_server.dart`: zonas descargadas → caché → red.
- Descarga por zona (`lib/src/offline/`), topográfico OpenFreeMap, satélite Sentinel-2 (EOX), relieve
  Terrain Tiles (AWS), curvas de nivel calculadas en el teléfono, buscador (Nominatim).

### Expediciones (`lib/src/expeditions/`, `ui/expedition_screen.dart`)
- Nombre, fecha, notas, zonas de mapas, hora límite de retorno.
- Lista **"Antes de salir"**: mapas, ruta, clima (vigente 48 h), equipo empacado, hora límite.
- Borrar una expedición borra su ruta, clima, equipo, referencias, recorridos y mapas propios.

### Grabación (`lib/src/tracking/`, `ui/recording_panel.dart`)
- Segundo plano (Android: servicio en primer plano; iOS: indicador azul), puntos cada 10 s, recuperación
  en pausa si la app se cierra.
- Reloj de tiempo activo (sin pausas) que corre desde que se toca Grabar; aviso "Esperando una señal GPS
  precisa" si la precisión es peor que ±50 m.
- Permiso de notificaciones (Android 13+) por canal propio `cresta/permissions` (`MainActivity.kt`).
- Estadísticas, desnivel con relieve, hora límite, aviso de salida de ruta, exportar GPX.

### Rutas (`lib/src/routes/`, `ui/planner_panel.dart`, `ui/route_screen.dart`)
- Cada ruta tiene su `id` y puede estar ligada a una expedición o existir sola (`RouteStore`: `all`, `byId`,
  `of`, `save`, `delete`, `deleteOf`, `replaceOf`). Las pantallas siguen manejando una por expedición
  (`forExpedition`). `routes.json` es `{"version": 2, "routes": [...]}`.
- Planificar tocando el mapa; ajuste a senderos visibles
  (`snapLeg` en `map.js`), deshacer, invertir, puntos de interés (agua, campamento, refugio, cumbre,
  punto de no retorno, peligro).
- Detalle "Route Details": cifras, perfil, bitácora de paradas con hora estimada, renombrar, borrar,
  exportar GPX. Importar GPX/KML desde la expedición.

### SOS (`lib/src/profile/`, `ui/sos_screen.dart`, `ui/profile_screen.dart`)
- Perfil de emergencia local (`profile.json`): datos médicos, contactos, número de emergencias.
- Pantalla SOS (inicio y mapa): coordenadas decimal, GMS y UTM, altitud, precisión; llamar, SMS a
  contactos, compartir, copiar. Pantalla encendida mientras está abierta.

### Preparación (Fase 4)
- **Clima** (`lib/src/weather/`, `ui/weather_widgets.dart`): Open-Meteo, 16 días, por altitud de salida y
  punto más alto; guardado en `weather.json`; nieve calculada a la altitud del punto.
- **Equipo** (`lib/src/gear/`, `ui/gear_screen.dart`): `gear.json`, plantillas, peso, empacado.
- **Referencias** (`lib/src/references/`, `ui/references_section.dart`): fotos y PDF copiados a la app,
  enlaces y teléfonos.

### Correcciones (28 oct 2026)
- La zona incluida del ejemplo ya no se puede borrar ("Incluida en la app"); si una instalación vieja la
  perdió, se reinstala al abrir la app (`installSampleOnce` en `sample_data.dart`).
- Altitud del relieve con **interpolación bilineal** (`terrain_elevation.dart`): pendientes y desnivel
  sin escalones de píxel.
- "Nieve probable" solo si en las horas frías del día caen ≥ 1 mm (`snowMinMm` en `forecast.dart`).

### Hora límite: notificación (`lib/src/tracking/turnaround_alerts.dart`)
- Con un recorrido en curso (grabando o en pausa) y hora límite fijada, avisa **30 min antes** y **a la hora**.
- Temporizadores en Dart (la app sigue viva por el servicio en primer plano de la grabación) y canal nativo
  `cresta/notify` en `MainActivity.kt` (canal `cresta_alerts`, importancia alta). Se retiran al terminar o
  descartar el recorrido. Solo Android: en iOS las llamadas no hacen nada.
- Lo que ya pasó al empezar no se avisa (el panel de grabación ya lo muestra).

### Mapa libre (`ui/map_screen.dart`, `ui/expeditions_screen.dart`)
- Tarjeta "Explorar mapa" en el inicio: abre `MapScreen` sin `expeditionId`. Capas, vistas 2D/3D, mi
  ubicación y SOS funcionan; encuadra la última zona descargada.
- Se pueden trazar rutas y guardarlas (ver abajo); grabar un recorrido pide crear una expedición
  (`startNewExpedition`, que reemplaza el mapa).

### Rutas sueltas, preparar sin conexión y comparar (fases B–D)
- **Guardar:** en el mapa libre, "Guardar ruta" pregunta el nombre (por defecto con fecha y hora) y el destino
  (`route_destination.dart`): solo la ruta, una expedición existente o una nueva. Las sueltas salen en el
  inicio en "Rutas guardadas"; el detalle de ruta (`RouteScreen(routeId)`) permite cambiarla de expedición.
  Una expedición muestra todas sus rutas; importar un GPX/KML agrega una más.
- **Preparar sin conexión** (detalle de ruta): clima de la ruta (`weather.json`, clave `route:<id>`) y mapa. La
  zona es la caja de la ruta más 0.02° (≈ 2 km) (`offline/route_zone.dart`): si una zona completa la cubre dice
  "Mapa descargado"; si no, estima mosaicos y MB y descarga con "Descargar mapa de esta ruta" (detallado si cabe
  en 40,000 mosaicos; si no, básico; si no, avisa). "Consultar clima y descargar mapa" hace las dos cosas.
- **Comparar** (`ui/compare_screen.dart`, `routes/route_compare.dart`): de 2 a 3 rutas; tabla con lo mejor de
  cada fila en cian (menor es mejor: distancia, subida, bajada, pendiente máx., tiempo; las de relieve solo
  entre rutas con relieve), perfiles superpuestos y "Ver en el mapa" (capa `compare` de `map.js`). Se abre
  desde el inicio, el detalle de ruta o la expedición.

### Avisos de seguridad de la ruta
- **Sin sendero:** cada tramo guarda si siguió un sendero (`snapped`). Los que no, van punteados con la etiqueta
  "sin sendero" en el mapa (capa `route-straight` de `map.js`; `MapScreen._mapJson` manda los tramos) y suman
  `PlannedRoute.straightMeters`. La ruta de ejemplo y las importadas cuentan como con sendero.
- **Muy empinado:** `steepStretches` (`routes/route_profile.dart`) junta los tramos de `steepThresholdPct` = 40 %
  o más (ventanas de 100 m, subiendo o bajando); el perfil los dibuja en terracota y el detalle de ruta avisa
  ("Revisa antes de salir"). El relieve de ~30 m suaviza, así que la realidad puede ser peor.
- "Comparar" suma las filas "Muy empinado" y "Sin sendero" (menor es mejor).

### Luz del día (`lib/src/sun/sun_times.dart`, `ui/sun_card.dart`)
- `sunTimes(date, lat, lng)`: amanecer, atardecer y crepúsculo civil (sol a −6°) con la ecuación de salida del
  sol (error de un par de minutos), sin conexión ni datos. Devuelve horas locales **del teléfono**; no cuenta la
  altitud ni las sombras de montañas. Día/noche polar sin horas.
- Tarjeta "Luz del día" en la expedición (día de la salida, o hoy sin fecha; lugar = salida de la primera ruta o
  centro de las zonas): amanecer, atardecer y horas de luz. Sugiere la hora límite más tarde que deja 2 h de luz
  (`descentMargin`; atardecer menos 2 h, bajado a múltiplo de 5 min), con botón "Usar HH:MM como hora límite", y
  avisa si la hora límite fijada deja menos.

### Interfaz
- Pestañas: Expediciones · Bitácora · Resumen · Mapas (`ui/home_shell.dart`).
- Splash de Android 12+ y splash cinematográfico de Flutter (mín. 2 s, "BY FRUTAL"); ícono propio.

## Estructura

```
lib/main.dart                  arranque, idioma, tema, splash → HomeShell
lib/src/app_services.dart      crea todos los servicios y almacenes
lib/src/expeditions/           expediciones
lib/src/offline/               zonas, mosaicos, fuentes, descargas, paquete de ejemplo
lib/src/tiles/tile_server.dart servidor local para el WebView
lib/src/tracking/              grabador, estadísticas, resumen, altitud del terreno, GPX, avisos de hora límite
lib/src/routes/                rutas: modelo, perfil, planificador, importar/exportar, bitácora
lib/src/profile/               perfil de emergencia, UTM, mensaje SOS
lib/src/weather/               pronóstico (Open-Meteo)
lib/src/gear/                  lista de equipo
lib/src/references/            referencias
lib/src/map/                   MapBridge y capas
lib/src/ui/                    pantallas; theme.dart = paleta y componentes del diseño
assets/web/                    map.js, MapLibre, maplibre-contour, tipografías del mapa
assets/fonts/inter/            tipografía de la app · assets/images/ textura del splash
tool/                          scripts de datos (Python) e ícono; tool/dev/ herramientas de prueba
test/                          124 pruebas
```
