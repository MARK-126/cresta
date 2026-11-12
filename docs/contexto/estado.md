# Estado: qué está hecho

Actualizado: 12 nov 2026 · avisos al acercarse a los puntos de interés de la ruta y "Próximo" en el panel.

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
| Rutas B | Trazar en el mapa libre y guardar sola o en una expedición; rutas guardadas en el inicio | `feat/rutas-b-mapa-libre` | `12beba6` |
| Rutas C | Clima por ruta y descarga de la zona de mapa de la ruta | `feat/rutas-c-clima-mapa` | `e59b06f` |
| Rutas D | Comparar rutas: cifras, perfiles superpuestos y mapa | `feat/rutas-d-comparar` | `c3f01e7` |
| Seguridad | Tramos sin sendero punteados y con etiqueta, pendientes de más de 40 % marcadas, aviso en el detalle | `feat/tramos-sin-sendero` | `1d26731` |
| Fase 5 · sol | Amanecer, atardecer y hora límite sugerida, sin conexión | `feat/luz-del-dia` | `323ebff` |
| Fase 5 · hora límite | Botón para quitarla (con Deshacer) y selector solo de reloj | `feat/quitar-hora-limite` | `18a5a46` |
| Experimento | Leer senderos de los mosaicos en Dart (base de la fase E) | `spike/senderos-dart` | `7c099ba` |
| Fix mapa libre | Centrar en cada toque, nombres de calles/colonias/estados, tope de 3,000 mosaicos del topo, "Abrir ajustes" | `fix/mapa-libre` | `eefee29` |
| Inicio | Inicio con cuatro acciones (grabar, explorar, trazar ruta, planear) y recorridos libres sin expedición | `feat/inicio` | `1ee1c41` |
| Pendientes | Capas "Pendiente del terreno" y "Zonas planas" calculadas del relieve en el teléfono | `feat/pendientes` | `73fa366` |
| Fase E (1) | Ruta A → B por senderos y calles con los mosaicos guardados (`TrailRouter`) | `feat/ruta-senderos` | `0cb231b` |
| Fase E (2) | Ruta a campo traviesa sobre el relieve y senderos por tiempo (Tobler) | `feat/ruta-terreno` | `1fd44ab` |
| Diseño | Botones tonales sin borde, "Descargar una zona" en Mapas, ícono de ruta unificado | `fix/diseno-revision` | `e69aaff` |
| Actualizar mapas | Aviso con Wi-Fi para zonas de más de 3 meses y botón por zona; vuelve a bajar solo el topográfico | `feat/actualizar-mapas` | `45ca74a` |
| Volver por mi traza | Guía de regreso por lo grabado: avance, lo que falta, aviso al salirse, rumbo al inicio | `feat/volver-traza` | `c00e63c` |
| Llegada en vivo | Hora de llegada a tu ritmo (Naismith calibrado), aviso de hora límite y de atardecer al regresar | `feat/llegada-en-vivo` | `82cca40` |
| Batería | Exención de la optimización de batería al grabar (canal nativo) y consejo de modo avión | `feat/bateria` | `b08010d` |
| Avisos de puntos | Notificación al acercarse a agua, no retorno, peligro…; próximo punto en el panel | `feat/aviso-puntos` | (ver `git log`) |

## Por área

### Mapa y mapas sin conexión
- MapLibre GL JS 4.7.1 en un WebView (`assets/web/map.js`), controlado desde `lib/src/map/map_bridge.dart`.
- Servidor local `lib/src/tiles/tile_server.dart`: zonas descargadas → caché → red.
- Descarga por zona (`lib/src/offline/`), topográfico OpenFreeMap, satélite Sentinel-2 (EOX), relieve
  Terrain Tiles (AWS), curvas de nivel calculadas en el teléfono, buscador (Nominatim).
- **Nombres** (capa "Nombres" de `map.js`): cumbres, ríos y pueblos; desde el 12 nov 2026 también calles, caminos y
  senderos (`road-names`: grandes desde z12, el resto desde z14), colonias y parajes (`places-minor`, z12+), estados y
  países en español (`places-region`, hasta z10) y límites (`boundaries`). Sin red, solo lo de las zonas (z8–14).
- **Tope por fuente:** `MapSource.maxTilesPerDownload` (topo: 3,000, términos de OpenFreeMap). `RegionEstimate.overSource`
  dice cuál se pasa; el selector de zona lo avisa y no deja descargar.
- **Mi ubicación** (`_locateMe` en `map_screen.dart`): centra en cada toque (última lectura, o la última conocida del
  teléfono mientras llega una nueva) sin cambiar la inclinación. El margen inferior sigue la altura del panel
  (`_onSheet` → `setPadding`). En el mapa libre el panel abre al 26 % (en expediciones, 38 %).
- **Actualizar mapas** (`OfflineRegion.topoAt`, `refreshAfter`, `canRefresh`, `isStale`; `OfflineMaps.refresh`,
  `stale`, `refreshStale`): una zona guarda cuándo terminó su topográfico (las viejas usan `updatedAt`). Al actualizar,
  `startRefresh()` fija un corte (2 s antes de ahora) y el descargador vuelve a pedir solo los mosaicos topo con fecha
  de archivo anterior (reanudable); relieve y satélite no se tocan. Mientras, la zona sigue `isComplete` (los mosaicos
  viejos sirven) y conserva su tamaño. Solo zonas con topo dentro del tope de 3,000. A los 90 días (`staleAfter`),
  `StaleMapsBanner` (inicio y Mapas, solo con Wi-Fi; "Ahora no" por sesión) ofrece actualizar todas; cada zona en
  Mapas dice "Senderos y calles del …" y tiene su botón ⟳.
- **Pendiente y zonas planas** (`map.js`, protocolo `slope://<modo>/z/x/y`): lee el mosaico de relieve del servidor
  local, calcula los grados de cada píxel (diferencias centrales, metros por píxel a la latitud del mosaico) y lo
  colorea (`SLOPE_CLASSES`): pendiente < 10° verde, 10–20 amarillo, 20–30 naranja, 30–40 rojo, > 40 morado; planas
  < 5° cian fuerte y 5–10° cian suave. Fuentes raster z8–12; si falta el z12 (zona Básica) usa el ancestro ampliado.
  Caché de 64 mosaicos. Capas `slope` y `flat` en `map_layers.dart`, apagadas al entrar, con leyenda (`MapLayer.legend`).
  `window.cresta.slopeAt(lng, lat, z)` da los grados en un punto (pruebas).
- `window.cresta.cameraInfo()` (para `cdp.py`): centro, zoom, inclinación, margen y dónde se dibuja tu posición.

### Expediciones (`lib/src/expeditions/`, `ui/expedition_screen.dart`)
- Nombre, fecha, notas, zonas de mapas, hora límite de retorno.
- Lista **"Antes de salir"**: mapas, ruta, clima (vigente 48 h), equipo empacado, hora límite.
- Borrar una expedición borra su ruta, clima, equipo, referencias, recorridos y mapas propios.

### Grabación (`lib/src/tracking/`, `ui/recording_panel.dart`)
- **Recorridos libres:** `Track.expeditionId` es opcional. Desde el mapa libre (o "Grabar · Desde aquí", que abre
  `MapScreen(record: true)`) se graba sin expedición: sin ruta ni hora límite. Salen en la Bitácora como "Recorrido
  libre", cuentan en el Resumen y no se borran con ninguna expedición. `ExpeditionStore.byId` acepta null.
  Desde su detalle (menú: "Pasar a una expedición" / "Cambiar de expedición") se pasan a una expedición existente,
  a una nueva (formulario lleno con el nombre y el día del recorrido) o de vuelta a libre: `TrackStore.moveTo`
  (`expeditionId` ya no es `final`). El selector es `askExpeditionDestination` en `ui/route_destination.dart`, el
  mismo que usan las rutas (`askRouteDestination`/`askTrackDestination`). La cabecera dice "RECORRIDO LIBRE" o
  "RECORRIDO · NOMBRE".
- Segundo plano (Android: servicio en primer plano; iOS: indicador azul), puntos cada 10 s, recuperación
  en pausa si la app se cierra.
- Reloj de tiempo activo (sin pausas) que corre desde que se toca Grabar; aviso "Esperando una señal GPS
  precisa" si la precisión es peor que ±50 m.
- Permiso de notificaciones (Android 13+) por canal propio `cresta/permissions` (`MainActivity.kt`).
- Batería: el mismo canal tiene `batteryUnrestricted` (`PowerManager.isIgnoringBatteryOptimizations`) y
  `requestBatteryUnrestricted` (diálogo del sistema `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, permiso
  `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`). Al empezar a grabar, si la app no está exenta, se explica y ofrece
  ("Permitir" / "Ahora no"); la grabación sigue igual si no. El diálogo de modo aconseja modo avión y poco brillo.
- Estadísticas, desnivel con relieve, hora límite, aviso de salida de ruta, exportar GPX.
- **Puntos de interés al grabar** (`tracking/poi_alerts.dart`): `recorder.pois` (los de la ruta guardada, también al
  recuperar). `PoiAlerts` (en `AppServices`, como `TurnaroundAlerts`) notifica una vez por punto y recorrido al estar a
  ≤ 150 m (no retorno y peligro: ≤ 300 m), ids 7200+i, canal `cresta_alerts` (renombrado "Avisos del recorrido"). El
  panel muestra el aviso mientras estás cerca y "Próximo: Arroyo en 400 m (≈ 6 min)" (`nextPoiAhead`: proyectado sobre
  la ruta, ignora los que quedan a > 300 m de ella).
- **Llegada en vivo** (`tracking/live_eta.dart`): con ruta (o regresando), `liveEta` = Naismith de lo que falta
  (`naismith()` en `trail_route.dart`, la misma regla de la bitácora) × tu ritmo (`paceFactor`: tiempo en movimiento
  entre Naismith de lo recorrido, desde 15 min y 500 m, acotado 0.5–2.5). El panel dice "Llegas al final ≈ HH:MM (en
  …), a tu ritmo / según la regla de Naismith, sin contar paradas"; avisa si llegarías después de la hora límite y, de
  regreso, si llegarías al inicio después del atardecer (`sunTimes` en tu posición).
- **Volver por mi traza** (`tracking/backtrack.dart`, `TrackRecorder.startBacktrack`/`stopBacktrack`): el recorrido al
  revés (sin puntos a < 5 m del anterior, termina justo en la salida) pasa a ser `recorder.route`, así que sirven el
  avance, "faltan X km y Y m de subida por tu traza" y el aviso al salirse (80 m). La ruta planeada se guarda y vuelve al
  dejar de guiar. El panel dice "REGRESANDO" y "El inicio está a 2.3 km en línea recta, rumbo 215° (SO)" (`bearingDeg`,
  `cardinal`; sin brújula). Botón "Volver al inicio por mi traza" con al menos 2 puntos. No sobrevive a cerrar la app.

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

### Ruta por senderos (fase E, parte 1: `lib/src/routing/trail_router.dart`)
- `TrailRouter.route(a, b)`: lee los mosaicos topo de zoom 14 de la caja de a–b más un margen (½ de la distancia,
  mín. 1.5 km; tope 600 mosaicos) de las zonas y la caché (`fromStores([offline, cache])`); si falta un z14 usa su z13.
  En otro isolate (`findTrailPath`): recorta cada línea a su mosaico, une nodos a ~1 m, une los extremos sueltos a la
  línea más cercana a ≤ 15 m, pega a y b a la línea más cercana a ≤ 150 m y busca con A*. Clases caminables de
  OpenMapTiles; carreteras grandes cuestan el doble. Devuelve [a, …, b] o null.
- El planificador (`MapScreen._snapLeg`) lo usa primero y, si da null, el ajuste a lo visible de `map.js`; si tampoco,
  línea recta con aviso.
- Medido: Paso de Cortés → cumbre del Izta 11.78 km en 125 ms (incluye el isolate); un tramo de la ruta real 4.56 km
  contra 4.55.

### Ruta a campo traviesa y desnivel (fase E, parte 2: `lib/src/routing/`)
- `DemGrid` (`dem_grid.dart`): altitudes de una ventana de píxeles de zoom 12, sin Flutter (va a otro isolate);
  `TerrainElevation.grid(box)` la arma (si falta z12, usa z11 ampliado; tope 300 mil píxeles). `toblerKmh(grade)`.
- `TerrainRouter` (`terrain_router.dart`): A* de 8 vecinos sobre los píxeles; costo = segundos a pie con Tobler × 0.6
  (fuera de sendero); más de 45° (pendiente 1.0) no se camina; simplifica el zigzag (Douglas–Peucker, ~10 m). Caja de
  a–b más 40 % de la distancia (mín. 800 m), o 20 % si no cabe.
- `TrailRouter` con `dem`: las aristas cuestan tiempo de Tobler en cada sentido (subir cuesta más que bajar) en vez de
  metros; enlaces y conectores, a velocidad de llano. A* con la velocidad máxima de Tobler.
- Planificador: sendero (Dart) → sendero visible (`map.js`) → **terreno** (tramo `snapped: false`, punteado "sin
  sendero", con aviso) → línea recta.
- Medido: Izta por senderos con relieve 11.80 km (sin relieve 11.78: misma ruta, los dos senderos suben parecido);
  campo traviesa de 2 km en 17 ms.

### Senderos en Dart (base de la fase E)
- `lib/src/tiles/mvt.dart`: decodificador mínimo de mosaicos vectoriales (Mapbox Vector Tile, sin comprimir: así los
  guarda `TileStore`) y `tilePointToLngLat`. `lib/src/tiles/tile_clip.dart`: recorta cada línea al cuadro del mosaico.
- `tool/dev/spike_senderos.dart`, `spike_ruta.dart` y `spike_zona.dart` reproducen las mediciones (ver `pruebas.md`).
  Se corren con `dart tool/dev/spike_ruta.dart CARPETA_CON_topo/ assets/data/arista_del_sol.json`; variables:
  `Z` (zoom), `CLIP`, `MODE` (`ends`, `border`), `TAU`, `LINK`, `DUMP`.

### Buscar sin señal (`lib/src/places/`, `ui/place_search_sheet.dart`)
- `placesInTile` lee de cada mosaico topográfico (solo las capas `mountain_peak`, `place`, `poi`, `water_name`,
  `waterway`, `transportation_name`, `park`; `decodeMvt(keep:)` no decodifica las demás) los lugares con nombre:
  cumbre/volcán/collado (con `ele`), refugio (`alpine_hut`, `shelter`, `wilderness_hut`), agua (`drinking_water`,
  `spring`), laguna, campamento, mirador, pueblo, paraje, sendero (`path`/`track` con nombre), río o arroyo, parque,
  policía, salud, estacionamiento. De una línea, su punto de en medio; lo que cae fuera del mosaico se ignora.
  `mergePlaces`: mismo nombre y tipo a < 300 m (2 km si es línea) es uno solo.
- `PlaceIndex` (en `AppServices.places`): con las zonas completas, mosaicos del zoom más alto de cada una, en un
  isolate; se guarda en `places.json` con una clave (versión, id, zoom y `topoDate` de cada zona) y se rehace solo si
  cambia. Vallecitos (210 mosaicos z14): 100 lugares en ~45 ms en la PC.
- `searchPlaces`: sin acentos ni mayúsculas, todas las palabras en el nombre; orden: empieza así, alguna palabra
  empieza así, contiene, coincide por tipo ("agua", "cumbre"); luego distancia (sin posición, el tipo). Sin texto:
  lo más cercano de cumbres, refugios, agua y campamentos. De ríos y senderos, solo el tramo más cercano.
- Mapa: botón de lupa arriba a la derecha → hoja "Buscar en tus mapas" (distancia y dirección desde tu posición o el
  centro del mapa) → vuela al lugar (zoom 14), lo marca (`setFound` en `map.js`, capas `found-*`) y muestra una tarjeta
  con nombre, tipo, altura y distancia; la ✕ lo quita.

### Interfaz
- Botones secundarios (`OutlinedButton`, 23 en la app): tonales `surfaceHighest` sin borde, desde el tema.
- Pestaña Mapas: "Descargar una zona" abre `AreaPickerScreen()` sin expedición (zona suelta, centrada en la última
  descargada); la lista escucha también a `maps`.
- Pestañas: Expediciones · Bitácora · Resumen · Mapas (`ui/home_shell.dart`).
- Inicio (`ui/expeditions_screen.dart`): "¿Qué quieres hacer?" con cuatro tarjetas (`_Actions`, `_ActionTile`):
  Grabar · Desde aquí (terracota), Explorar · Mapa libre (cian), Trazar ruta · De A a B (oro, abre el mapa libre en
  modo planear) y Planear · Expedición. Con un recorrido en curso, Grabar y Trazar se apagan y el aviso de arriba
  lleva al recorrido. Debajo, "Tus expediciones" con su cuenta y las rutas guardadas.
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
test/                          135 pruebas
```
